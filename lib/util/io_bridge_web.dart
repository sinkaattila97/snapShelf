import 'dart:typed_data';

import 'package:flutter/painting.dart';

bool get isAndroid => false;
bool get isIOS => false;
bool get isWindows => false;
bool get isLinux => false;
bool get isMacOS => false;

bool get isMobileOs => false;
bool get isDesktopOs => false;

bool fileExistsSync(String path) => false;

ImageProvider fileImageProvider(String path) =>
    MemoryImage(Uint8List.fromList(const [0]));

Future<void> writeBytesToFile(String path, Uint8List bytes) async {}

Future<Uint8List?> readBytesFromFile(String path) async => null;

Future<void> deleteFileIfExists(String path) async {}
