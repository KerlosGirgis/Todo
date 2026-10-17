import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import 'profile_card.dart';

const _accent = Color(0xff3D5AFE);

/// A titled group of settings on one card, in the style of iOS's grouped
/// lists, with hairlines between the rows that start where their text does.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final hairline = Divider(
      height: 0.5,
      thickness: 0.5,
      indent: SettingsTile.textInset,
      color: context.colors.wB.withValues(alpha: 0.1),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              color: context.colors.wB.withValues(alpha: 0.5),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
        ),
        ProfileCard(
          child: Column(
            children: [
              for (final (index, child) in children.indexed) ...[
                if (index > 0) hairline,
                child,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A row of a [SettingsGroup]: a coloured icon, a title with an optional
/// subtitle, and a control or value at the end. A [bottom] control, such as
/// a segmented control, gets the full width of the row under the title.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.trailing,
    this.bottom,
    this.onTap,
  });

  static const _iconSize = 30.0;

  /// Where the row's text starts, which the group's hairlines line up with.
  static const textInset = 16 + _iconSize + 14;

  final IconData icon;
  final Color color;
  final String title;
  final Widget? subtitle;
  final Widget? trailing;
  final Widget? bottom;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      // iOS highlights a pressed row instead of rippling.
      splashFactory: NoSplash.splashFactory,
      highlightColor: context.colors.wB.withValues(alpha: 0.06),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 11, 16, bottom == null ? 11 : 16),
        child: Column(
          children: [
            Row(
              children: [
                _IconBadge(icon: icon, color: color, size: _iconSize),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: context.colors.wB,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: DefaultTextStyle.merge(
                            style: TextStyle(
                              color: context.colors.wB.withValues(alpha: 0.5),
                              fontSize: 13,
                              height: 1.3,
                            ),
                            child: subtitle!,
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 12),
                  trailing!,
                ],
              ],
            ),
            if (bottom != null) ...[
              const SizedBox(height: 14),
              SizedBox(width: double.infinity, child: bottom),
            ],
          ],
        ),
      ),
    );
  }
}

/// A [SettingsTile] with a switch at the end, which the whole row toggles.
class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onToggle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final Widget? subtitle;
  final bool value;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    // Read out as one switch, rather than a row and a switch.
    return MergeSemantics(
      child: SettingsTile(
        icon: icon,
        color: color,
        title: title,
        subtitle: subtitle,
        onTap: onToggle,
        trailing: CupertinoSwitch(
          value: value,
          activeTrackColor: _accent,
          onChanged: (_) => onToggle(),
        ),
      ),
    );
  }
}

/// A row's current value beside a chevron, for rows that open more options.
class DisclosureValue extends StatelessWidget {
  const DisclosureValue(this.value, {super.key});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            color: context.colors.wB.withValues(alpha: 0.45),
            fontSize: 16,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 2),
        Icon(
          Icons.chevron_right_rounded,
          size: 24,
          color: context.colors.wB.withValues(alpha: 0.3),
        ),
      ],
    );
  }
}

/// A setting's icon, white on a rounded square of its own colour, as in
/// iOS's Settings.
class _IconBadge extends StatelessWidget {
  const _IconBadge(
      {required this.icon, required this.color, required this.size});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: const RoundedSuperellipseBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        // A faint sheen from the top, as on app icons.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(color, Colors.white, 0.14)!, color],
        ),
      ),
      child: SizedBox.square(
        dimension: size,
        child: Icon(icon, size: size * 0.6, color: Colors.white),
      ),
    );
  }
}
