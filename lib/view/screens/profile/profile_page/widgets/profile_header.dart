import 'package:flutter/material.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import 'user_avatar.dart';
import 'username.dart';

/// The top of the profile page: the user's avatar, a greeting for the time of
/// day, and their name.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key, this.avatarSize = 148});

  final double avatarSize;

  /// About how far the header scrolls before its name is under a bar above
  /// it, so the bar can bring in its own copy of the name.
  static double nameScrolledAway(double avatarSize) => avatarSize + 60;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox.square(dimension: avatarSize, child: const UserAvatar()),
        const SizedBox(height: 18),
        Text(
          _greeting(DateTime.now().hour).toUpperCase(),
          style: TextStyle(
            color: context.colors.moreLess,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        const UserName(),
      ],
    );
  }
}

String _greeting(int hour) => switch (hour) {
      >= 5 && < 12 => "Good morning",
      >= 12 && < 17 => "Good afternoon",
      _ => "Good evening",
    };
