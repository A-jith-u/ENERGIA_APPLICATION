import 'package:flutter/material.dart';

class AppNotifier {
  static void showSuccess(BuildContext context, String message) {
    _show(context, message, Colors.green);
  }

  static void showError(BuildContext context, String message) {
    _show(context, message, Colors.red);
  }

  static void showInfo(BuildContext context, String message) {
    _show(context, message, Colors.blue);
  }

  static void _show(BuildContext context, String message, Color color) {
    final snack = SnackBar(
      content: Row(
        children: [
          Icon(
            color == Colors.red
                ? Icons.error_outline
                : color == Colors.green
                    ? Icons.check_circle_outline
                    : Icons.info_outline,
            color: Colors.white,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      duration: const Duration(seconds: 3),
    );
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(snack);
  }
}
