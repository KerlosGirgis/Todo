import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class FeedbackToast {
  static void success(String message) {
    _show(message, Colors.green);
  }

  static void error(String message) {
    _show(message, Colors.red);
  }

  static void info(String message) {
    _show(message, Color(0xff1E1E1E));
  }

  static void _show(String message, Color color) {
    Fluttertoast.showToast(
        msg: message,
        backgroundColor: color,
        textColor: Colors.white,
        gravity: ToastGravity.BOTTOM,
        toastLength: Toast.LENGTH_SHORT,
        fontSize: 19.0);
  }
}
