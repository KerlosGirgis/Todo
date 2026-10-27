import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../../models/avatar.dart';
import '../../../../../view_model/user_view_model.dart';
import 'profile_button.dart';

const _accent = Color(0xff3D5AFE);

/// Opens the sheet that picks one of the bundled avatars, or a photo from
/// the gallery.
Future<void> showAvatarPicker(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: context.colors.cardBackground,
    shape: const RoundedSuperellipseBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (context) => const AvatarPickerSheet(),
  );
}

class AvatarPickerSheet extends StatelessWidget {
  const AvatarPickerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final current =
        context.select<UserViewModel, Avatar>((user) => user.user.avatar);
    return SingleChildScrollView(
      // Clear of the gesture bar, which a bottom sheet's safe area leaves in.
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, 20 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Choose Avatar",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.colors.wB,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Pick a character, or use a photo of your own.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.colors.wB.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 22),
          GridView.count(
            crossAxisCount: 5,
            // Not padded for the gesture bar as well; the sheet already is.
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            children: [
              for (final (index, avatar) in BundledAvatar.all.indexed)
                _AvatarOption(
                  avatar: avatar,
                  label: "Avatar ${index + 1}",
                  selected: avatar == current,
                  onTap: () {
                    context.read<UserViewModel>().editPic(avatar);
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
          const SizedBox(height: 24),
          ProfileButton(
            label: "Choose from Gallery",
            icon: Icons.photo_library_rounded,
            tinted: true,
            onPressed: () {
              final user = context.read<UserViewModel>();
              Navigator.pop(context);
              user.pickAndSaveImage();
            },
          ),
        ],
      ),
    );
  }
}

class _AvatarOption extends StatelessWidget {
  const _AvatarOption({
    required this.avatar,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final BundledAvatar avatar;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      inMutuallyExclusiveGroup: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest.shortestSide;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      width: 2.5,
                      color: selected ? _accent : Colors.transparent,
                    ),
                  ),
                  child: ClipOval(
                    // The same backdrop and zoom as the avatar's own ring,
                    // for the avatars drawn on a transparent background.
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xffE8EAF6), Color(0xffC5CAE9)],
                        ),
                      ),
                      child: Transform.scale(
                        scale: 1.05,
                        child: Image.asset(
                          avatar.asset,
                          fit: BoxFit.cover,
                          // Decoded at the size it's shown, not in full.
                          cacheWidth:
                              (size * MediaQuery.devicePixelRatioOf(context))
                                  .round(),
                        ),
                      ),
                    ),
                  ),
                ),
                if (selected)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: _accent,
                        shape: BoxShape.circle,
                        // Cut out of whatever it overlaps by the sheet's
                        // own colour.
                        border: Border.all(
                            color: context.colors.cardBackground, width: 2),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(Icons.check_rounded,
                            size: 14, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
