import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'app_map_widget.dart';

/// Local GetX host so marker/polyline updates rebuild only the map decorations.
class _MapDecorationHost extends GetxController {
  _MapDecorationHost({
    required Set<Marker> markers,
    required Set<Polyline> polylines,
  })  : markers = Set<Marker>.from(markers),
        polylines = Set<Polyline>.from(polylines);

  Set<Marker> markers;
  Set<Polyline> polylines;

  static const decorationsId = 'decorations';

  void applyMarkers(Set<Marker> next) {
    markers = Set<Marker>.from(next);
    update([decorationsId]);
  }

  void applyPolylines(Set<Polyline> next) {
    polylines = Set<Polyline>.from(next);
    update([decorationsId]);
  }
}

/// Hosts [AppMapWidget] **outside** ride/GPS Obx scopes.
///
/// Marker/polyline Rx updates go through a GetX [GetBuilder] host so
/// [GoogleMap] receives new decorations via [State.didUpdateWidget] without
/// remounting the platform view. Permission UX lives in parent banners —
/// this widget never swaps the map for a shimmer.
class ReactiveAppMap extends StatefulWidget {
  const ReactiveAppMap({
    super.key,
    required this.initialPosition,
    required this.markers,
    required this.polylines,
    this.zoom = 13.5,
    this.zoomControlsEnabled = false,
    this.myLocationEnabled = false,
    this.onMapCreated,
    this.onCameraMoveStarted,
    this.onTap,
    this.showPlatformReadyOverlay = true,
  });

  final LatLng initialPosition;
  final RxSet<Marker> markers;
  final RxSet<Polyline> polylines;
  final double zoom;
  final bool zoomControlsEnabled;
  final bool myLocationEnabled;
  final void Function(GoogleMapController controller)? onMapCreated;
  final VoidCallback? onCameraMoveStarted;
  final ArgumentCallback<LatLng>? onTap;
  final bool showPlatformReadyOverlay;

  @override
  State<ReactiveAppMap> createState() => _ReactiveAppMapState();
}

class _ReactiveAppMapState extends State<ReactiveAppMap> {
  late final String _hostTag;
  late final _MapDecorationHost _host;
  Worker? _markersWorker;
  Worker? _polylinesWorker;

  @override
  void initState() {
    super.initState();
    _hostTag = 'reactive_map_${identityHashCode(this)}';
    _host = Get.put(
      _MapDecorationHost(
        markers: widget.markers.toSet(),
        polylines: widget.polylines.toSet(),
      ),
      tag: _hostTag,
    );
    _markersWorker = ever<Set<Marker>>(widget.markers, (next) {
      if (!Get.isRegistered<_MapDecorationHost>(tag: _hostTag)) return;
      _host.applyMarkers(next);
    });
    _polylinesWorker = ever<Set<Polyline>>(widget.polylines, (next) {
      if (!Get.isRegistered<_MapDecorationHost>(tag: _hostTag)) return;
      _host.applyPolylines(next);
    });
    // Route fetch can finish before the first ever() tick — replay now.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!Get.isRegistered<_MapDecorationHost>(tag: _hostTag)) return;
      _host.applyMarkers(widget.markers.toSet());
      _host.applyPolylines(widget.polylines.toSet());
    });
  }

  @override
  void dispose() {
    _markersWorker?.dispose();
    _polylinesWorker?.dispose();
    if (Get.isRegistered<_MapDecorationHost>(tag: _hostTag)) {
      Get.delete<_MapDecorationHost>(tag: _hostTag, force: true);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<_MapDecorationHost>(
      tag: _hostTag,
      id: _MapDecorationHost.decorationsId,
      builder: (host) {
        return AppMapWidget(
          key: const ValueKey('app_map_surface'),
          initialPosition: widget.initialPosition,
          markers: host.markers,
          polylines: host.polylines,
          zoom: widget.zoom,
          zoomControlsEnabled: widget.zoomControlsEnabled,
          myLocationEnabled: widget.myLocationEnabled,
          onMapCreated: widget.onMapCreated,
          onCameraMoveStarted: widget.onCameraMoveStarted,
          onTap: widget.onTap,
          showPlatformReadyOverlay: widget.showPlatformReadyOverlay,
        );
      },
    );
  }
}
