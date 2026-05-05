import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

class FeedbackToast {
  static void success(String message) {
    _show(message, ToastificationType.success);
  }

  static void error(String message) {
    _show(message, ToastificationType.error);
  }

  static void info(String message) {
    _show(
        message,
        ToastificationType.custom(
            "info", Color(0xff1E1E1E), Icons.info_outline_rounded));
  }

  static void _show(String message, ToastificationType type) {
    toastification.show(
      title: Text(
        message,
        style: TextStyle(fontSize: 17),
      ),
      type: type,
      autoCloseDuration: const Duration(seconds: 3),
      dragToClose: true,
      style: ToastificationStyle.fillColored,
      alignment: AlignmentGeometry.directional(0, 1),
    );
  }
}
