import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';

class Indicator extends StatelessWidget {
  const Indicator({
    super.key,
    required this.color,
    required this.text,
    required this.isSquare,
    this.size = 16,
    this.textColor,
  });

  final Color color;
  final String text;
  final bool isSquare;
  final double size;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    final adaptiveSize = size * (screenWidth / 400).clamp(0.8, 1.5);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Container(
          width: adaptiveSize,
          height: adaptiveSize,
          decoration: BoxDecoration(
            shape: isSquare ? BoxShape.rectangle : BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 6), // Increased spacing for better readability
        Expanded(
          child: AutoSizeText(
            text,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            minFontSize: 10,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: textColor ?? Colors.black,
            ),
          ),
        ),
      ],
    );
  }
}
