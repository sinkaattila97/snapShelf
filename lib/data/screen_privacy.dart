import 'package:flutter/services.dart';

import '../util/io_bridge.dart' as io;

/// Blocks screenshots / screen recording of the app window when enabled.
/// Android: FLAG_SECURE. iOS/web: best-effort / no-op with honest fallback.
class ScreenPrivacy {
  static const _channel = MethodChannel('snapshelf/privacy');

  static Future<void> setSecure(bool enabled) async {
    if (!io.isAndroid && !io.isIOS) return;
    try {
      await _channel.invokeMethod<void>('setSecure', {'enabled': enabled});
    } catch (_) {
      // Channel missing on hot-reload / desktop — ignore.
    }
  }
}
