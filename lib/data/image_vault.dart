import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// AES key + PIN hash in platform secure storage (Keystore / Keychain).
/// Web uses a weaker browser backend — Chrome is not a vault.
class ImageVault {
  ImageVault({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _keyB64 = 'snapshelf_aes_key_v1';
  static const _pinHash = 'snapshelf_pin_hash_v1';
  static const _pinSalt = 'snapshelf_pin_salt_v1';
  static const _lockEnabled = 'snapshelf_lock_enabled_v1';

  bool get isHardenedPlatform => !kIsWeb;

  Future<enc.Key> _aesKey() async {
    final existing = await _storage.read(key: _keyB64);
    if (existing != null && existing.isNotEmpty) {
      return enc.Key(base64Decode(existing));
    }
    final random = Random.secure();
    final bytes = Uint8List.fromList(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
    await _storage.write(key: _keyB64, value: base64Encode(bytes));
    return enc.Key(bytes);
  }

  /// Encrypts bytes. Format: `SS1` + IV(16) + ciphertext.
  Future<Uint8List> encrypt(Uint8List plain) async {
    final key = await _aesKey();
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encryptBytes(plain, iv: iv);
    final out = BytesBuilder(copy: false)
      ..add(utf8.encode('SS1'))
      ..add(iv.bytes)
      ..add(encrypted.bytes);
    return out.toBytes();
  }

  Future<Uint8List> decrypt(Uint8List data) async {
    if (data.length < 3 + 16 + 1) return data;
    final magic = utf8.decode(data.sublist(0, 3), allowMalformed: true);
    if (magic != 'SS1') {
      // Legacy plaintext (pre-encryption) — return as-is.
      return data;
    }
    final key = await _aesKey();
    final iv = enc.IV(data.sublist(3, 19));
    final cipher = data.sublist(19);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final decrypted = encrypter.decryptBytes(enc.Encrypted(cipher), iv: iv);
    return Uint8List.fromList(decrypted);
  }

  Future<bool> get isLockEnabled async {
    return (await _storage.read(key: _lockEnabled)) == '1';
  }

  Future<void> setLockEnabled(bool enabled) async {
    await _storage.write(key: _lockEnabled, value: enabled ? '1' : '0');
  }

  Future<bool> get hasPin async {
    final hash = await _storage.read(key: _pinHash);
    return hash != null && hash.isNotEmpty;
  }

  Future<void> setPin(String pin) async {
    final saltBytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final salt = base64Encode(saltBytes);
    final hash = sha256.convert(utf8.encode('$salt:$pin')).toString();
    await _storage.write(key: _pinSalt, value: salt);
    await _storage.write(key: _pinHash, value: hash);
    await setLockEnabled(true);
  }

  Future<bool> verifyPin(String pin) async {
    final salt = await _storage.read(key: _pinSalt);
    final hash = await _storage.read(key: _pinHash);
    if (salt == null || hash == null) return false;
    final attempt = sha256.convert(utf8.encode('$salt:$pin')).toString();
    return attempt == hash;
  }

  Future<void> clearPin() async {
    await _storage.delete(key: _pinHash);
    await _storage.delete(key: _pinSalt);
    await setLockEnabled(false);
  }
}
