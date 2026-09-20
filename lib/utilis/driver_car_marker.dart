import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

const String kDriverCarMarkerAsset = 'assets/images/driver_car.webp';
const String kPickupMarkerAsset = 'assets/images/location.webp';
const String kDropoffMarkerAsset = 'assets/images/flag.webp';
const String kStopMarkerAsset = 'assets/images/stop.png';

/// Decodes an asset into a map marker icon with transparent background.
///
/// Source webps ship with an opaque black backdrop; near-black pixels connected
/// to the image edges are cleared so the icon composites cleanly on the map.
Future<BitmapDescriptor> createAssetMarkerIcon(
  String assetPath, {
  double logicalSize = 64,
}) async {
  final pixelRatio = ui.PlatformDispatcher.instance.views.isEmpty
      ? 2.0
      : ui.PlatformDispatcher.instance.views.first.devicePixelRatio;
  final targetSize = (logicalSize * pixelRatio).round().clamp(64, 192);

  final data = await rootBundle.load(assetPath);
  final codec = await ui.instantiateImageCodec(
    data.buffer.asUint8List(),
    targetWidth: targetSize,
  );
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (byteData == null) {
    throw StateError('Failed to read marker pixels: $assetPath');
  }

  final pixels = Uint8List.fromList(byteData.buffer.asUint8List());
  _clearConnectedBlackBackground(pixels, image.width, image.height);

  final transparent = await _encodePng(pixels, image.width, image.height);
  final height = logicalSize * image.height / image.width;

  return BitmapDescriptor.bytes(
    transparent,
    width: logicalSize,
    height: height,
  );
}

/// Driver car marker from [kDriverCarMarkerAsset].
Future<BitmapDescriptor> createDriverCarMarkerIcon({double logicalSize = 46}) {
  return createAssetMarkerIcon(kDriverCarMarkerAsset, logicalSize: logicalSize);
}

/// Pickup pin from [kPickupMarkerAsset].
Future<BitmapDescriptor> createPickupMarkerIcon({double logicalSize = 38}) {
  return createAssetMarkerIcon(kPickupMarkerAsset, logicalSize: logicalSize);
}

/// Destination pin from [kDropoffMarkerAsset].
Future<BitmapDescriptor> createDropoffMarkerIcon({double logicalSize = 38}) {
  return createAssetMarkerIcon(kDropoffMarkerAsset, logicalSize: logicalSize);
}

/// Intermediate stop pin from [kStopMarkerAsset].
Future<BitmapDescriptor> createStopMarkerIcon({double logicalSize = 38}) {
  return createAssetMarkerIcon(kStopMarkerAsset, logicalSize: logicalSize);
}

void _clearConnectedBlackBackground(Uint8List pixels, int width, int height) {
  const threshold = 18;
  final visited = Uint8List(width * height);
  final queue = <int>[];

  void enqueue(int x, int y) {
    if (x < 0 || y < 0 || x >= width || y >= height) return;
    final index = y * width + x;
    if (visited[index] == 1) return;
    final offset = index * 4;
    final r = pixels[offset];
    final g = pixels[offset + 1];
    final b = pixels[offset + 2];
    if (r > threshold || g > threshold || b > threshold) return;
    visited[index] = 1;
    pixels[offset + 3] = 0;
    queue.add(index);
  }

  for (var x = 0; x < width; x++) {
    enqueue(x, 0);
    enqueue(x, height - 1);
  }
  for (var y = 0; y < height; y++) {
    enqueue(0, y);
    enqueue(width - 1, y);
  }

  while (queue.isNotEmpty) {
    final index = queue.removeLast();
    final x = index % width;
    final y = index ~/ width;
    enqueue(x - 1, y);
    enqueue(x + 1, y);
    enqueue(x, y - 1);
    enqueue(x, y + 1);
  }
}

Future<Uint8List> _encodePng(Uint8List pixels, int width, int height) async {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    pixels,
    width,
    height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  final image = await completer.future;
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  if (png == null) {
    throw StateError('Failed to encode marker PNG');
  }
  return png.buffer.asUint8List();
}
