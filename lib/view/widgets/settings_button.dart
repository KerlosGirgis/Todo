import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';

class SettingsButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;
  final bool status;
  final double fontSize;
  final double size;

  const SettingsButton({
    super.key,
    required this.onPressed,
    required this.label,
    required this.status,
    required this.fontSize,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
          elevation: 2,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(25)),
          ),
          backgroundColor: status ? const Color(0xff3D5AFE) : Colors.white),
      child: Center(
        child: AutoSizeText(
          minFontSize: 8,
          textAlign: TextAlign.center,
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              color: status ? Colors.white : const Color(0xff3D5AFE),
              fontSize: fontSize),
        ),
      ),
    );
  }
}
