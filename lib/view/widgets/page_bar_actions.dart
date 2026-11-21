import 'package:material_ui/material_ui.dart';

import 'appbar_avatar.dart';
import 'glass_menu.dart';

/// The end of a page's bar: the menu of the page's less frequent actions,
/// then the avatar.
class PageBarActions extends StatelessWidget {
  const PageBarActions({super.key, required this.items, required this.menuKey});

  final List<GlassMenuItem> items;

  /// The menu's key, for the page's tour to point at it by.
  final GlobalKey menuKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GlassMenu(key: menuKey, items: items),
        const SizedBox(width: 10),
        const AppbarAvatar(),
      ],
    );
  }
}
