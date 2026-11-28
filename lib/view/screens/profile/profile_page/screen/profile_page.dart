import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../../view_model/user_view_model.dart';
import '../../../../widgets/glass_icon_button.dart';
import '../../../../widgets/large_title.dart';
import '../../../../widgets/page_gutters.dart';
import '../../../../widgets/themed_status_bar.dart';
import '../widgets/aurora.dart';
import '../widgets/profile_header.dart';
import '../widgets/progress_card.dart';
import '../widgets/settings_sections.dart';

/// The settings, under the user's profile, sliding up over the page they're
/// opened from.
Route<void> profileRoute() => PageRouteBuilder<void>(
  pageBuilder: (context, animation, secondaryAnimation) => const ProfilePage(),
  transitionsBuilder: (context, animation, secondaryAnimation, child) =>
      SlideTransition(
        position: animation.drive(
          Tween(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.ease)),
        ),
        child: child,
      ),
);

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ThemedStatusBar(
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: context.colors.pageBackground,
        body: AnimationLimiter(child: _buildBody(context)),
      ),
    );
  }

  /// The profile, then the settings under it, in one column, on a phone
  /// turned on its side as well.
  Widget _buildBody(BuildContext context) {
    const avatarSize = 148.0;
    final padding = MediaQuery.paddingOf(context);
    // A comfortable width for the cards on wide screens.
    final EdgeInsets(:left, :right) = pageGutters(context, maxWidth: 600);
    final name = context.select<UserViewModel, String>(
      (user) => user.user.name,
    );
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: padding.top + 460,
          // Drifts up at half the speed of the page, for a little depth.
          child: ListenableBuilder(
            listenable: _scrollController,
            builder: (context, child) => Transform.translate(
              offset: Offset(
                0,
                _scrollController.hasClients
                    ? -_scrollController.offset / 2
                    : 0,
              ),
              child: child,
            ),
            child: const ProfileAurora(),
          ),
        ),
        CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: LargeTitleBarDelegate(
                title: name,
                topInset: padding.top,
                controller: _scrollController,
                leading: const _CloseButton(),
                trailing: const _AboutButton(),
                titleRevealOffset: ProfileHeader.nameScrolledAway(avatarSize),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(left, 8, right, 32 + padding.bottom),
              sliver: SliverList.list(
                children: _staggered(const [
                  ProfileHeader(avatarSize: avatarSize),
                  ProgressCard(),
                  AppearanceSection(),
                  GeneralSection(),
                  TasksSection(),
                  NotesSection(),
                ]),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// [sections], spaced apart, rising into place one after another as the page
/// opens.
List<Widget> _staggered(List<Widget> sections) => [
  for (final (index, section) in sections.indexed)
    AnimationConfiguration.staggeredList(
      position: index,
      duration: const Duration(milliseconds: 500),
      child: SlideAnimation(
        verticalOffset: 32,
        curve: Curves.easeOutCubic,
        child: FadeInAnimation(
          curve: Curves.easeOut,
          child: Padding(
            padding: EdgeInsets.only(top: index == 0 ? 0 : 28),
            child: section,
          ),
        ),
      ),
    ),
];

class _CloseButton extends StatelessWidget {
  const _CloseButton();

  @override
  Widget build(BuildContext context) {
    // Points down, the way the page leaves.
    return GlassIconButton(
      icon: Icons.keyboard_arrow_down_rounded,
      tooltip: "Close",
      onPressed: () => Navigator.pop(context),
    );
  }
}

class _AboutButton extends StatelessWidget {
  const _AboutButton();

  @override
  Widget build(BuildContext context) {
    return GlassIconButton(
      icon: Icons.info_outline_rounded,
      tooltip: "About",
      onPressed: () {
        toastification.show(
          title: Text(
            "Developed with ❤️ by Kerlos Girgis",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          type: ToastificationType.info,
          autoCloseDuration: const Duration(seconds: 5),
          dragToClose: true,
          alignment: AlignmentGeometry.directional(0, 1),
          style: ToastificationStyle.flat,
        );
      },
    );
  }
}
