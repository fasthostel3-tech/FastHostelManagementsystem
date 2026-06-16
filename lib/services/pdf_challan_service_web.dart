/// Web stub - this should never be called on web as we handle it in the main service
/// with kIsWeb check. This file exists only for conditional import to compile.
Future<String> uploadChallanFromFile(
    String challanId, String challanText) async {
  throw UnsupportedError(
      'uploadChallanFromFile should not be called on web. Use XFile approach instead.');
}

