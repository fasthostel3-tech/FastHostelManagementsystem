import 'package:path/path.dart' as p;
import 'dart:io';
import 'package:cross_file/cross_file.dart';
import 'cloudinary_service.dart';

/// Mobile/desktop implementation for uploading challan from file
Future<String> uploadChallanFromFile(
    String challanId, String challanText) async {
  final tempDir = Directory.systemTemp;
  final tempPath = p.join(tempDir.path, '$challanId.txt');
  final tempFile = File(tempPath);
  try {
    await tempFile.writeAsString(challanText);
    final url = await CloudinaryService.uploadImage(
      file: XFile(tempFile.path),
      resourceType: 'raw',
    );
    if (url == null) throw Exception('Challan upload cancelled or returned null');
    return url;
  } finally {
    try {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    } catch (_) {}
  }
}

