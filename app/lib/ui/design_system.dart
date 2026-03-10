import 'package:flutter/material.dart';
import 'package:another_flushbar/flushbar.dart';

enum MessageType { success, error, warning, info }

class AppTheme {
  static const Color primaryColor = Color(0xFF6B21A8); // Purple
  static const Color primaryLight = Color(0xFF9333EA);
  static const Color primaryDark = Color(0xFF581C87);
  static const Color surface = Colors.white;
  static const Color surfaceAlt = Color(0xFFF7F7FA);
  static const Color textPrimary = Colors.black;
  static const Color textSecondary = Colors.black54;

  static const double radiusSmall = 8;
  static const double radiusMedium = 12;
  static const double radiusLarge = 16;

  static const double spacingXS = 8;
  static const double spacingS = 12;
  static const double spacingM = 16;
  static const double spacingL = 20;
  static const double spacingXL = 24;

  static const double controlHeight = 56;
}

class AppWidgets {
  static void showFlushbar(
    BuildContext context,
    String message, {
    MessageType type = MessageType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    Color backgroundColor;
    IconData icon;

    switch (type) {
      case MessageType.success:
        backgroundColor = Colors.green;
        icon = Icons.check_circle;
        break;
      case MessageType.error:
        backgroundColor = Colors.red;
        icon = Icons.error;
        break;
      case MessageType.warning:
        backgroundColor = Colors.orange;
        icon = Icons.warning;
        break;
      case MessageType.info:
        backgroundColor = Colors.blue;
        icon = Icons.info;
        break;
    }

    Flushbar(
      message: message,
      icon: Icon(icon, color: Colors.white),
      backgroundColor: backgroundColor,
      duration: duration,
      margin: const EdgeInsets.all(AppTheme.spacingM),
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      flushbarPosition: FlushbarPosition.TOP,
    ).show(context);
  }
}
