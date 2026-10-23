import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../../view_model/user_view_model.dart';
import '../../../../widgets/ringed_avatar.dart';
import 'avatar_picker_sheet.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final pic = context.select<UserViewModel, String>((user) => user.user.pic);
    return LayoutBuilder(builder: (context, constraints) {
      final screenSize = MediaQuery.sizeOf(context);
      // About the same footprint as before, but never more than the space
      // the page gives it, so short screens don't overflow.
      final size = [
        (MediaQuery.orientationOf(context) == Orientation.portrait
                    ? screenSize.width
                    : screenSize.height) /
                2 +
            16,
        constraints.maxWidth,
        constraints.maxHeight,
      ].reduce(math.min);
      final badgeSize = size * 0.2;
      // Centres the badge on the ring at the bottom right.
      final badgeOffset =
          size * (0.5 + 0.48 * math.cos(math.pi / 4)) - badgeSize / 2;
      return SizedBox.square(
        dimension: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: AvatarHalo(child: RingedAvatar(pic: pic)),
            ),
            Positioned(
              left: badgeOffset,
              top: badgeOffset,
              child: Semantics(
                button: true,
                label: "Change avatar",
                child: Material(
                  color: const Color(0xff3D5AFE),
                  elevation: 2,
                  clipBehavior: Clip.antiAlias,
                  // The page-coloured border cuts the badge out of the ring.
                  shape: CircleBorder(
                    side: BorderSide(
                      color: context.colors.pageBackground,
                      width: 3,
                    ),
                  ),
                  child: InkWell(
                    onTap: () => showAvatarPicker(context),
                    child: SizedBox.square(
                      dimension: badgeSize,
                      child: Icon(
                        Icons.photo_camera_rounded,
                        color: Colors.white,
                        size: badgeSize * 0.48,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
