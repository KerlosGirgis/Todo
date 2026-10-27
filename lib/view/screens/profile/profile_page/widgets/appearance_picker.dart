import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../view_model/user_view_model.dart';

const _accent = Color(0xff3D5AFE);
const _highlight = Color(0xff40C4FF);

/// Light and dark previews of the app to choose the theme from, as in iOS's
/// Display & Brightness settings.
class AppearancePicker extends StatelessWidget {
  const AppearancePicker({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark =
        context.select<UserViewModel, bool>((user) => user.user.darkTheme);
    void choose(bool dark) {
      if (dark != isDark) context.read<UserViewModel>().changeTheme();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _Option(
            label: "Light",
            dark: false,
            selected: !isDark,
            onTap: () => choose(false),
          ),
          _Option(
            label: "Dark",
            dark: true,
            selected: isDark,
            onTap: () => choose(true),
          ),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.label,
    required this.dark,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool dark;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      inMutuallyExclusiveGroup: true,
      selected: selected,
      label: "$label appearance",
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              padding: const EdgeInsets.all(4),
              decoration: ShapeDecoration(
                shape: RoundedSuperellipseBorder(
                  borderRadius: const BorderRadius.all(Radius.circular(21)),
                  side: BorderSide(
                    width: 2.5,
                    color: selected ? _accent : Colors.transparent,
                  ),
                ),
              ),
              child: _PhoneMock(dark: dark),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                color: context.colors.wB,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),
            _Check(selected: selected),
          ],
        ),
      ),
    );
  }
}

/// A round check box, filled with the accent when [selected].
class _Check extends StatelessWidget {
  const _Check({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? _accent : Colors.transparent,
        border: Border.all(
          width: 1.5,
          color: selected ? _accent : context.colors.wB.withValues(alpha: 0.25),
        ),
      ),
      child: AnimatedScale(
        scale: selected ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
      ),
    );
  }
}

/// A miniature of the to-do page in the light or the dark theme.
class _PhoneMock extends StatelessWidget {
  const _PhoneMock({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    final colors = dark ? AppColors.dark : AppColors.light;
    // A shade further from the page than the real cards, so they read at
    // this size.
    final card = dark ? const Color(0xff2A2A2A) : Colors.white;
    final ink = colors.wB;
    Widget line(double width, double height, double alpha) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: ink.withValues(alpha: alpha),
            borderRadius: BorderRadius.circular(height / 2),
          ),
        );

    return Container(
      width: 76,
      height: 134,
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      decoration: ShapeDecoration(
        color: colors.pageBackground,
        shape: RoundedSuperellipseBorder(
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          side: BorderSide(
            width: 0.5,
            color: dark
                ? Colors.white.withValues(alpha: 0.14)
                : Colors.black.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              line(26, 6, 0.85),
              const Spacer(),
              Container(
                width: 11,
                height: 11,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [_accent, _highlight]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          for (final (index, width) in const [30.0, 22.0, 27.0].indexed)
            Container(
              height: 19,
              margin: const EdgeInsets.only(bottom: 5),
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index == 0 ? _accent : null,
                      border: index == 0
                          ? null
                          : Border.all(
                              width: 1, color: ink.withValues(alpha: 0.3)),
                    ),
                  ),
                  const SizedBox(width: 5),
                  line(width, 3, 0.5),
                ],
              ),
            ),
          const Spacer(),
          Align(
            alignment: Alignment.bottomRight,
            child: Container(
              width: 17,
              height: 17,
              decoration: ShapeDecoration(
                // The to-do page's add button, in the app's blues in either
                // theme.
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_accent, Color.lerp(_accent, _highlight, 0.7)!],
                ),
                shape: const RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.all(Radius.circular(5)),
                ),
              ),
              child: const Icon(
                Icons.add_rounded,
                size: 12,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
