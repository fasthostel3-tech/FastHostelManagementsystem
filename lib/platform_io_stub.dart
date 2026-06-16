// Stub implementations for types from `dart:io` used in the codebase.
// These stubs exist only so the web build can compile. At runtime on web
// you should not call these methods; they throw UnsupportedError.
import 'dart:typed_data';

class File {
  final String path;
  File(this.path);

  Future<Uint8List> readAsBytes() async {
    throw UnsupportedError(
        'File.readAsBytes is not supported on web. Use XFile or browser file APIs.');
  }

  Future<void> writeAsString(String contents) async {
    throw UnsupportedError(
        'File.writeAsString is not supported on web. Use browser file APIs or upload from memory.');
  }

  Future<bool> exists() async {
    throw UnsupportedError('File.exists is not supported on web.');
  }

  Future<void> delete() async {
    throw UnsupportedError('File.delete is not supported on web.');
  }
}

class Directory {
  final String path;
  Directory(this.path);
  static Directory get systemTemp => Directory('');
}
