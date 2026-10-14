import 'package:flutter/material.dart';
import '../../core/extensions/theme_extensions.dart';

class DialogHeader extends StatelessWidget {
  const DialogHeader({super.key, required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: context.colors.dialogIconContainer,
            shape: shape,
          ),
          child: Icon(icon, color: context.colors.dialogIcon, size: 22),
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 28,
              color: context.colors.wB,
            ),
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.close, color: context.colors.dialogExitIcon, size: 22),
          style: IconButton.styleFrom(
            backgroundColor: context.colors.dialogExitContainer,
            fixedSize: const Size(40, 40),
            padding: EdgeInsets.zero,
            shape: shape,
          ),
        ),
      ],
    );
  }
}
