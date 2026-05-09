import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import '../../../../../core/extensions/theme_extensions.dart';

class SettingsButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;
  final bool status;
  final double fontSize;
  final double size;
  final IconData icon;

  const SettingsButton({
    super.key,
    required this.onPressed,
    required this.label,
    required this.status,
    required this.fontSize,
    required this.size,
    required this.icon,
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
        backgroundColor:
        status ? const Color(0xff3D5AFE) : context.colors.cardBackground,
        foregroundColor: status ? Colors.white : context.colors.wB,
        side: BorderSide(
          color: status
              ? context.colors.wB.withValues(alpha: 0.3)
              : context.colors.wB.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(5.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Icon(
                icon,
                size: MediaQuery.orientationOf(context) ==
                    Orientation.portrait
                    ? MediaQuery.sizeOf(context).width / 9
                    : MediaQuery.sizeOf(context).height / 9,
                color: status ? Colors.white : const Color(0xff3D5AFE),
              ),
            ),
            Expanded(
              child: AutoSizeText(
                label,
                minFontSize: 8,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: status ? FontWeight.bold : FontWeight.w600,
                  fontSize: fontSize,
                  color: status ? Colors.white : context.colors.wB,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
