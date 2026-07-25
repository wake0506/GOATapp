// ignore_for_file: avoid_web_libraries_in_flutter

// ignore: deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';

Future<String> deliverJsonFile(String filename, Uint8List bytes) async {
  final blob = html.Blob([bytes], 'application/json;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  try {
    html.document.body?.children.add(anchor);
    anchor.click();
  } finally {
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  }
  return filename;
}
