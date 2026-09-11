import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart';

bool get isAndroid => Platform.isAndroid;
bool get isIOS => Platform.isIOS;
bool get isWindows => Platform.isWindows;
bool get isLinux => Platform.isLinux;
bool get isMacOS => Platform.isMacOS;

bool get isMobileOs => isAndroid || isIOS;
bool get isDesktopOs => isWindows || isLinux || isMacOS;

bool fileExistsSync(String path) => File(path).existsSync();

ImageProvider fileImageProvider(String path) => FileImage(File(path));

Future<void> writeBytesToFile(String path, Uint8List bytes) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
}

Future<Uint8List?> readBytesFromFile(String path) async {
  final file = File(path);
  if (!await file.exists()) return null;
  return file.readAsBytes();
}

Future<void> deleteFileIfExists(String path) async {
  final file = File(path);
  if (await file.exists()) {
    await file.delete();
  }
}
