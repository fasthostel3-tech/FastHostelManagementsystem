import 'env_config.dart';

class CloudinaryConfig {
  // Cloudinary credentials
  static String get cloudName => EnvConfig.cloudinaryCloudName;
  static String get apiKey => EnvConfig.cloudinaryApiKey;
  static String get apiSecret => EnvConfig.cloudinaryApiSecret;

  // Upload settings
  static const String defaultFolder = 'hostel_management';
  static const String profilePicturesFolder =
      'hostel_management/profile_pictures';
  static const String roomImagesFolder = 'hostel_management/room_images';
  static const String cnicImagesFolder = 'hostel_management/cnic_images';
  static const String feeChallanFolder = 'hostel_management/fee_challans';
  static const String messMenuImagesFolder =
      'hostel_management/mess_menu_images';

  // Image transformation presets
  static const Map<String, dynamic> profilePictureTransform = {
    'width': 150,
    'height': 150,
    'crop': 'fill',
    'gravity': 'face',
    'format': 'auto',
    'quality': 'auto',
  };

  static const Map<String, dynamic> messMenuImageTransform = {
    'width': 600,
    'height': 400,
    'crop': 'fill',
    'format': 'auto',
    'quality': 'auto',
  };

  static const Map<String, dynamic> roomImageTransform = {
    'width': 400,
    'height': 300,
    'crop': 'fill',
    'format': 'auto',
    'quality': 'auto',
  };

  static const Map<String, dynamic> cnicImageTransform = {
    'width': 600,
    'height': 400,
    'crop': 'limit',
    'format': 'auto',
    'quality': 'auto',
  };

  static const Map<String, dynamic> thumbnailTransform = {
    'width': 200,
    'height': 200,
    'crop': 'fill',
    'format': 'auto',
    'quality': 'auto',
  };

  // Get optimized URL for different use cases
  static String getOptimizedUrl(
    String publicId, {
    int? width,
    int? height,
    String? crop,
    String? format,
    String? quality,
  }) {
    final baseUrl = 'https://res.cloudinary.com/$cloudName/image/upload';
    final transformations = <String>[];

    if (width != null) transformations.add('w_$width');
    if (height != null) transformations.add('h_$height');
    if (crop != null) transformations.add('c_$crop');
    if (format != null) transformations.add('f_$format');
    if (quality != null) transformations.add('q_$quality');

    final transformString =
        transformations.isNotEmpty ? '${transformations.join(',')}/' : '';

    return '$baseUrl/$transformString$publicId';
  }

  // Get thumbnail URL
  static String getThumbnailUrl(String publicId, {int size = 200}) {
    return getOptimizedUrl(
      publicId,
      width: size,
      height: size,
      crop: 'fill',
      format: 'auto',
      quality: 'auto',
    );
  }

  // Get profile picture URL
  static String getProfilePictureUrl(String publicId) {
    return getOptimizedUrl(
      publicId,
      width: 150,
      height: 150,
      crop: 'fill',
      format: 'auto',
      quality: 'auto',
    );
  }

  // Get room image URL
  static String getRoomImageUrl(String publicId) {
    return getOptimizedUrl(
      publicId,
      width: 400,
      height: 300,
      crop: 'fill',
      format: 'auto',
      quality: 'auto',
    );
  }
}
