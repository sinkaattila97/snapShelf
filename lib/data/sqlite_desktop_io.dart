import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../util/io_bridge.dart' as io;

Future<void> ensureDesktopFactory() async {
  if (io.isDesktopOs) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}
