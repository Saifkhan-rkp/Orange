import 'dart:io';
import 'dart:typed_data';

class FollowManager {
  /// Equivalent to Java walk(String path)
  static Future<List<Map<String, dynamic>>> walk(String path) async {
    final List<Map<String, dynamic>> values = [];

    final dir = Directory(path);

    if (!await dir.exists()) {
      throw Exception("Directory does not exist");
    }

    try {
      // Add parent directory
      values.add({
        "name": "../",
        "isDir": true,
        "path": dir.parent.path,
      });

      final entities = await dir.list(followLinks: false).toList();

      for (final entity in entities) {
        final name = entity.uri.pathSegments.last;

        // if (name.startsWith(".")) continue;

        values.add({
          "name": name,
          "isDir": entity is Directory,
          "path": entity.path,
        });
      }
    } on FileSystemException {
      return [
        {
          "type": "error",
          "error": "Denied",
        }
      ];
    }

    return values;
  }

  static Future<Map<String, dynamic>?> downloadFile(String path) async {
    final file = File(path);

    if (!await file.exists()) {
      return null;
    }

    Uint8List bytes = await file.readAsBytes();

    return {
      "type": "dwd",
      "name": file.uri.pathSegments.last,
      "buffer": bytes,
    };
  }
}