import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';

class Button extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;
  final bool status;
  final double fontSize;
  final double size;

  const Button({
    super.key,
    required this.onPressed,
    required this.label,
    required this.status,
    required this.fontSize,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).orientation == Orientation.portrait
          ? (MediaQuery.of(context).size.height / 22)*size
          : (MediaQuery.of(context).size.height / 10)*size,
      width: MediaQuery.of(context).orientation == Orientation.portrait
          ? (MediaQuery.of(context).size.width / 3.7)*size
          : (MediaQuery.of(context).size.width / 7.7)*size,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 2,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(13)),
            ),
            backgroundColor: status ? const Color(0xff3D5AFE) : Colors.white),
        child: Center(
          child: AutoSizeText(
            label,
            maxLines: 1,
            minFontSize: 4,
            style: TextStyle(
              overflow: TextOverflow.ellipsis,
                color: status ? Colors.white : const Color(0xff3D5AFE),
                fontSize: fontSize),
          ),
        ),
      ),
    );
  }
}
