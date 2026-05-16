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
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Container(
          width: adaptiveSize,
          height: adaptiveSize,
          decoration: BoxDecoration(
            shape: isSquare ? BoxShape.rectangle : BoxShape.circle,
            color: color,
            border: Border.all(
              color: textColor ?? Colors.black,
              width: 2,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          fit: FlexFit.loose,
          child: AutoSizeText(
            text,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: TextStyle(
              fontSize: 18 * (screenWidth / 400).clamp(0.8, 1.3),              fontWeight: FontWeight.w600,
              color: textColor ?? Colors.black,
            ),
          ),
        ),
      ],
    );
  }
}
