import 'package:flutter/material.dart';

import '../../../../../core/extensions/theme_extensions.dart';

/// The rounded surface the profile page's cards sit on. A soft shadow lifts
/// it off light pages; on dark ones a hairline edge does the separating.
class ProfileCard extends StatelessWidget {
  const ProfileCard({super.key, required this.child});

  // Apple's continuous corners, as on the note cards.
  static const _shape = RoundedSuperellipseBorder(
    borderRadius: BorderRadius.all(Radius.circular(26)),
  );

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: _shape,
        shadows: isDarkTheme
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 24,
                  spreadRadius: -6,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: Material(
        // White rather than the card grey, which barely shows on the light
        // page background.
        color: isDarkTheme ? context.colors.cardBackground : Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: _shape.copyWith(
          side: BorderSide(
            width: 0.5,
            color:
                context.colors.wB.withValues(alpha: isDarkTheme ? 0.08 : 0.05),
          ),
        ),
        child: child,
      ),
    );
  }
}
