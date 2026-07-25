import 'dart:typed_data';

import 'json_file_delivery_stub.dart'
    if (dart.library.io) 'json_file_delivery_io.dart'
    if (dart.library.html) 'json_file_delivery_web.dart'
    as platform;

Future<String> deliverJsonFile(String filename, Uint8List bytes) =>
    platform.deliverJsonFile(filename, bytes);
