import 'package:flutter/material.dart';

/// Global keys shared across the app.
class AppKeys {
  AppKeys._();

  /// A root-level [ScaffoldMessengerState] to show SnackBars that survive route changes.
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
}


