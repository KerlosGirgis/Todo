import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../view_model/user_view_model.dart';

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
    return Consumer<UserViewModel>(
      builder: (context, user, child) {
        final colorManager = user.colorManager;
        return ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
            backgroundColor: colorManager.cardBackground,
            foregroundColor: colorManager.wB,
            side: BorderSide(
              color: colorManager.wB!,
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
                          color: colorManager.wB,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_right_rounded,
                      size: MediaQuery.orientationOf(context) ==
                          Orientation.portrait
                          ? MediaQuery.sizeOf(context).width / 13
                          : MediaQuery.sizeOf(context).height / 13,
                      color: colorManager.wB,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

