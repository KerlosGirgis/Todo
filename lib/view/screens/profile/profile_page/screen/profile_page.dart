import 'dart:math' as math;

import 'package:flutter/material.dart';
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
  // One per scroll view, as the two layouts briefly overlap when the screen
  // turns, and a controller can't follow two scroll views at once.
  final _scrollController = ScrollController();
  final _profilePaneScrollController = ScrollController();
  final _settingsPaneScrollController = ScrollController();

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
    _profilePaneScrollController.dispose();
    _settingsPaneScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    // Side by side when the screen is too short for one long column, as on a
    // phone turned on its side.
    final twoPanes =
        MediaQuery.orientationOf(context) == Orientation.landscape &&
            MediaQuery.sizeOf(context).aspectRatio >= 1.5;
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
        body: AnimationLimiter(
          child: twoPanes ? _buildTwoPanes(context) : _buildOnePane(context),
        ),
      ),
    );
  }

  Widget _buildOnePane(BuildContext context) {
    const avatarSize = 148.0;
    final padding = MediaQuery.paddingOf(context);
    // Keeps the cards a comfortable width on tablets.
    final gutter = math.max(16.0, (MediaQuery.sizeOf(context).width - 600) / 2);
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
              padding:
                  EdgeInsets.fromLTRB(gutter, 8, gutter, 32 + padding.bottom),
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

  Widget _buildTwoPanes(BuildContext context) {
    const avatarSize = 120.0;
    final padding = MediaQuery.paddingOf(context);
    final name =
        context.select<UserViewModel, String>((user) => user.user.name);
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Stack(
            children: [
              const Positioned.fill(child: ProfileAurora()),
              CustomScrollView(
                controller: _profilePaneScrollController,
                slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: LargeTitleBarDelegate(
                      title: name,
                      topInset: padding.top,
                      controller: _profilePaneScrollController,
                      leading: const _CloseButton(),
                      titleRevealOffset:
                          ProfileHeader.nameScrolledAway(avatarSize),
                    ),
                  ),
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                          16 + padding.left, 0, 16, 24 + padding.bottom),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: _staggered(const [
                          ProfileHeader(avatarSize: avatarSize),
                          ProgressCard(),
                        ]),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          flex: 6,
          child: CustomScrollView(
            controller: _settingsPaneScrollController,
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: LargeTitleBarDelegate(
                  title: "Settings",
                  topInset: padding.top,
                  controller: _settingsPaneScrollController,
                  trailing: const _AboutButton(),
                ),
              ),
              const SliverToBoxAdapter(child: LargeTitle("Settings")),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                    16, 8, 16 + padding.right, 32 + padding.bottom),
                sliver: SliverList.list(
                  children: _staggered(const [
                    AppearanceSection(),
                    GeneralSection(),
                    TasksSection(),
                    NotesSection(),
                  ]),
                ),
              ),
            ],
          ),
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
