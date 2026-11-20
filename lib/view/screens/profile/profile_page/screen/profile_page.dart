import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';
import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../../view_model/notes_view_model.dart';
import '../../../../../view_model/tasks_view_model.dart';
import '../../../../../view_model/user_view_model.dart';
import '../../../../widgets/glass_icon_button.dart';
import '../../../../widgets/large_title.dart';
import '../widgets/aurora.dart';
import '../widgets/profile_header.dart';
import '../widgets/progress_card.dart';
import '../widgets/settings_sections.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
  });

  @override
  State<ProfilePage> createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // The progress card's counts, which are otherwise only loaded by the
      // tasks' and notes' own pages.
      Provider.of<TasksViewModel>(context, listen: false).get();
      Provider.of<NotesViewModel>(context, listen: false).get();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // There's no app bar to pick the status bar's icons, so they're set here.
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            isDarkTheme ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDarkTheme ? Brightness.dark : Brightness.light,
      ),
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
    // Clear of a camera cutout on a phone turned on its side, and a
    // comfortable width for the cards on wide screens.
    final centred = (MediaQuery.sizeOf(context).width - 600) / 2;
    final left = math.max(16 + padding.left, centred);
    final right = math.max(16 + padding.right, centred);
    final name =
        context.select<UserViewModel, String>((user) => user.user.name);
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
                      : 0),
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
            style: ToastificationStyle.flat);
      },
    );
  }
}
