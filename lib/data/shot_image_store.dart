import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../util/io_bridge.dart' as io;
import 'image_vault.dart';

/// Stores shot image bytes for thumbnails/preview — encrypted at rest.
class ShotImageStore {
  ShotImageStore({ImageVault? vault}) : _vault = vault ?? ImageVault();

  static const _prefix = 'snapshelf_img_';

  final ImageVault _vault;

  Future<void> saveBytes(String shotId, Uint8List bytes) async {
    final sealed = await _vault.encrypt(bytes);
    if (!kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefix$shotId';
    final ok = await prefs.setString(key, base64Encode(sealed));
    if (!ok) {
      throw StateError('Could not store image preview (storage full?).');
    }
  }

  Future<Uint8List?> loadBytes(String shotId, {String? localPath}) async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('$_prefix$shotId');
        if (raw == null || raw.isEmpty) return null;
        return await _vault.decrypt(base64Decode(raw));
      }
      if (localPath != null && io.fileExistsSync(localPath)) {
        final sealed = await io.readBytesFromFile(localPath);
        if (sealed == null) return null;
        return await _vault.decrypt(sealed);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> delete(String shotId) async {
    if (!kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$shotId');
  }
}
