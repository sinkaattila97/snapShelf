import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// Shrink large screenshots so web localStorage can hold them.
Future<Uint8List> shrinkImageBytes(
  Uint8List bytes, {
  int maxSide = 1280,
}) async {
  try {
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: maxSide,
    );
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    frame.image.dispose();
    if (data == null) return bytes;
    final out = data.buffer.asUint8List();
    // If somehow larger, keep original.
    return out.length < bytes.length ? out : bytes;
  } catch (_) {
    return bytes;
  }
}

Future<Uint8List> shrinkForStorage(Uint8List bytes) async {
  if (!kIsWeb) return bytes;
  var current = bytes;
  for (final side in [1280, 960, 720, 480]) {
    current = await shrinkImageBytes(current, maxSide: side);
    // ~1.5MB base64 ceiling keeps most browsers happy.
    if (current.length < 1100000) return current;
  }
  return current;
}
