import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserDataExportService {
  final SupabaseClient client;
  UserDataExportService(this.client);

  Future<File> exportToLocalFile() async {
    final response = await client.functions.invoke('export-user-data', body: const {});
    final data = response.data;
    final bytes = data is String ? utf8.encode(data) : utf8.encode(jsonEncode(data));
    if (bytes.length > 5 * 1024 * 1024) throw StateError('Export is too large');
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}${Platform.pathSeparator}goat-data-${DateTime.now().toIso8601String().substring(0, 10)}.json');
    return file.writeAsBytes(bytes, flush: true);
  }
}
