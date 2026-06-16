// Conditional export: use real dart:io `File` on non-web platforms,
// and provide a small stub implementation for web so code referring
// to `File` compiles.
export 'dart:io' if (dart.library.html) 'platform_io_stub.dart';
