import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../utilis/map_style.dart';

export '../utilis/map_style.dart' show kMapPlatformBackground;

class AppMapWidget extends StatefulWidget {
  final LatLng initialPosition;
  final Set<Marker>? markers;
  final Set<Polyline>? polylines;
  final double zoom;
  final bool zoomControlsEnabled;
  final bool myLocationEnabled;
  final void Function(GoogleMapController controller)? onMapCreated;
  final VoidCallback? onCameraMoveStarted;
  final ArgumentCallback<LatLng>? onTap;

  /// When true (default), shows map-chrome overlay until the platform view is
  /// idle (or a short fallback). Hides hybrid blank/white flash without a spinner.
  final bool showPlatformReadyOverlay;

  const AppMapWidget({
    super.key,
    required this.initialPosition,
    this.markers,
    this.polylines,
    this.zoom = 13.5,
    this.zoomControlsEnabled = false,
    this.myLocationEnabled = false,
    this.onMapCreated,
    this.onCameraMoveStarted,
    this.onTap,
    this.showPlatformReadyOverlay = true,
  });

  @override
  State<AppMapWidget> createState() => _AppMapWidgetState();
}

class _AppMapWidgetState extends State<AppMapWidget> {
  late final LatLng _initialTarget;
  late final double _initialZoom;

  late Set<Marker> _markers;
  late Set<Polyline> _polylines;

  /// Overlay visibility — [ValueNotifier] avoids [State.setState] remount risk.
  final ValueNotifier<bool> _showOverlay = ValueNotifier<bool>(true);
  bool _mapCreated = false;
  Timer? _overlayFallback;

  static const _overlayMaxWait = Duration(milliseconds: 1200);

  @override
  void initState() {
    super.initState();
    // Freeze initial camera so marker/polyline updates never recreate the map.
    _initialTarget = widget.initialPosition;
    _initialZoom = widget.zoom;
    _markers = widget.markers ?? const <Marker>{};
    _polylines = widget.polylines ?? const <Polyline>{};
    if (!widget.showPlatformReadyOverlay) {
      _showOverlay.value = false;
    }
  }

  @override
  void didUpdateWidget(covariant AppMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update decorations in place — do not touch initialCameraPosition.
    _markers = Set<Marker>.from(widget.markers ?? const <Marker>{});
    _polylines = Set<Polyline>.from(widget.polylines ?? const <Polyline>{});
  }

  @override
  void dispose() {
    _overlayFallback?.cancel();
    _showOverlay.dispose();
    super.dispose();
  }

  void _hideOverlay() {
    _overlayFallback?.cancel();
    _overlayFallback = null;
    if (_showOverlay.value) {
      _showOverlay.value = false;
    }
  }

  void _handleMapCreated(GoogleMapController controller) {
    _mapCreated = true;
    if (widget.showPlatformReadyOverlay && _showOverlay.value) {
      _overlayFallback?.cancel();
      _overlayFallback = Timer(_overlayMaxWait, _hideOverlay);
    }
    widget.onMapCreated?.call(controller);
  }

  void _handleCameraIdle() {
    if (_mapCreated) {
      _hideOverlay();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _initialTarget,
            zoom: _initialZoom,
          ),
          style: kDarkMapStyle,
          markers: _markers,
          polylines: _polylines,
          zoomControlsEnabled: widget.zoomControlsEnabled,
          myLocationEnabled: widget.myLocationEnabled,
          myLocationButtonEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: false,
          rotateGesturesEnabled: true,
          scrollGesturesEnabled: true,
          zoomGesturesEnabled: true,
          tiltGesturesEnabled: false,
          onCameraMoveStarted: widget.onCameraMoveStarted,
          onCameraIdle: _handleCameraIdle,
          onTap: widget.onTap,
          onMapCreated: _handleMapCreated,
        ),
        if (widget.showPlatformReadyOverlay)
          ValueListenableBuilder<bool>(
            valueListenable: _showOverlay,
            builder: (context, visible, _) {
              if (!visible) return const SizedBox.shrink();
              return const ColoredBox(color: kMapPlatformBackground);
            },
          ),
      ],
    );
  }
}
