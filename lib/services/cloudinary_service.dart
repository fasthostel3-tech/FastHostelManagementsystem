import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../platform_io.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../config/env_config.dart';

class CloudinaryService {
  /// Upload an image to Cloudinary.
  /// Accepts either a `File` (mobile) or an `XFile`/null (web or picker).
  /// This method is web-safe: when running on web it uses `XFile.readAsBytes()`
  /// and `MultipartFile.fromBytes`, while on mobile it uses `fromPath`.
  static Future<String?> uploadImage({
    Object? file,
    ImageSource source = ImageSource.gallery,
    String resourceType = 'image',
  }) async {
    final picker = ImagePicker();
    XFile? pickedFile;

    // If caller provided a dart:io `File`, convert to XFile by path
    if (file != null) {
      try {
        if (file is XFile) {
          pickedFile = file;
        } else if (file is File) {
          // Convert platform File to XFile by path for unified handling
          pickedFile = XFile(file.path);
        }
      } catch (_) {
        // ignore and fallback to picker
      }
    }

    // If no file provided, pick from device/browser
    pickedFile ??= await picker.pickImage(source: source);

    if (pickedFile == null) return null;

    final cloudName = EnvConfig.cloudinaryCloudName;
    final uploadPreset = EnvConfig.cloudinaryUploadPreset;

    debugPrint('[Cloudinary] Cloud name: $cloudName');
    debugPrint('[Cloudinary] Upload preset: $uploadPreset');
    debugPrint('[Cloudinary] File path: ${pickedFile.path}');

    if (cloudName.isEmpty) {
      throw Exception('CLOUDINARY_CLOUD_NAME is not configured');
    }

    if (uploadPreset.isEmpty) {
      debugPrint('[Cloudinary] Error: CLOUDINARY_UPLOAD_PRESET is not configured in .env or WebConfig');
      throw Exception('Server configuration error: Missing Cloudinary Preset');
    }

    final url = Uri.parse(
      "https://api.cloudinary.com/v1_1/$cloudName/$resourceType/upload",
    );

    debugPrint('[Cloudinary] Uploading to: $url');

    try {
      final request = http.MultipartRequest("POST", url)
        ..fields['upload_preset'] = uploadPreset;

      if (kIsWeb) {
        // On web, use bytes from XFile
        final bytes = await pickedFile.readAsBytes();
        final multipartFile = http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: pickedFile.name,
        );
        request.files.add(multipartFile);
      } else {
        // On mobile, prefer fromPath for efficiency
        request.files
            .add(await http.MultipartFile.fromPath('file', pickedFile.path));
      }

      // Add timeout to prevent infinite loading
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw Exception(
              'Upload timed out after 60 seconds. Check your internet connection.');
        },
      );

      final resBody = await streamedResponse.stream.bytesToString();
      debugPrint('[Cloudinary] Response status: ${streamedResponse.statusCode}');
      // Truncate long bodies for logs but keep enough to see errors
      debugPrint('[Cloudinary] Response body: ${resBody.length > 500 ? '${resBody.substring(0, 500)}...' : resBody}');

      if (streamedResponse.statusCode >= 200 &&
          streamedResponse.statusCode < 300) {
        
        dynamic data;
        try {
          data = jsonDecode(resBody);
        } catch (e) {
          throw Exception('Failed to parse Cloudinary response: $resBody');
        }

        if (data is! Map) {
           throw Exception('Invalid Cloudinary response format: Expected Map, got ${data.runtimeType}');
        }

        final secureUrl = data["secure_url"];
        if (secureUrl != null && secureUrl.toString().isNotEmpty) {
           debugPrint('[Cloudinary] Upload successful: $secureUrl');
           return secureUrl.toString();
        } else {
           throw Exception('Cloudinary response missing secure_url');
        }
      }

      // Parse error message from Cloudinary
      String errorMessage = 'Unknown Cloudinary error';
      try {
        final data = jsonDecode(resBody);
        if (data is Map && data['error'] != null) {
          final errorObj = data['error'];
          if (errorObj is Map && errorObj['message'] != null) {
            errorMessage = errorObj['message'].toString();
          } else {
             errorMessage = errorObj.toString();
          }
        } else {
          errorMessage = resBody;
        }
      } catch (_) {
        errorMessage = resBody; // Fallback to raw body if JSON parse fails
      }
      
      throw Exception('Cloudinary upload failed: $errorMessage');
    } catch (e) {
      debugPrint('[Cloudinary] Upload error details: $e');
      // If it's already our clean exception, rethrow it
      if (e.toString().startsWith('Exception:')) {
        rethrow;
      }
      // Otherwise wrap it
      throw Exception('Image upload failed: $e');
    }
  }
}
