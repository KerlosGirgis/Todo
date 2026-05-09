import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import '../../../../../core/extensions/theme_extensions.dart';

class FontButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;
  final double fontSize;
  final double size;

  const FontButton({
    super.key,
    required this.onPressed,
    required this.label,
    required this.fontSize,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
        backgroundColor: context.colors.cardBackground,
        foregroundColor: context.colors.wB,
        side: BorderSide(
          color: context.colors.wB,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  flex: 2,
                  child: AutoSizeText(
                    label,
                    minFontSize: 8,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight:FontWeight.bold,
                      fontSize: fontSize,
                      color: context.colors.wB,
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_right_rounded,
                  size: MediaQuery.orientationOf(context) ==
                      Orientation.portrait
                      ? MediaQuery.sizeOf(context).width / 13
                      : MediaQuery.sizeOf(context).height / 13,
                  color: context.colors.wB,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

