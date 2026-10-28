import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../../core/result.dart';
import '../../../../../core/ui/feedback_toast.dart';
import '../../../../../models/task_filters.dart';
import '../../../../../models/todo_item.dart';
import '../../../../../view_model/tasks_view_model.dart';
import '../../../../../view_model/tour_view_model.dart';
import '../../../../../view_model/user_view_model.dart';
import '../../../../widgets/appbar_avatar.dart';
import '../../../../widgets/glass_menu.dart';
import '../../../../widgets/large_title.dart';
import '../../../../widgets/page_action_buttons.dart';
import '../../../../widgets/rise_in.dart';
import '../../../../widgets/tour.dart';
import '../../../notes/notes_page/screen/notes_page.dart';
import '../../../profile/lock_page/widgets/password_dialogs.dart';
import '../../../profile/profile_page/screen/profile_page.dart';
import '../widgets/empty_tasks.dart';
import '../widgets/form_dialog.dart';
import '../widgets/task_card.dart';
import '../widgets/task_dialog.dart';
import '../widgets/task_filter_bar.dart';
import '../widgets/tasks_overwrite_dialog.dart';
import '../widgets/tasks_summary_card.dart';
import '../widgets/todo_tour.dart';

const _title = "ToDo";

/// The gap between cards.
const _cardGap = 12.0;

/// The room above the list's first card.
const _listTop = 20.0;

/// How long the page takes to rise in, which its tour waits for.
const _tourDelay = Duration(milliseconds: 900);

class TodoPage extends StatefulWidget {
  const TodoPage({
    super.key,
  });

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  // One per scroll view, as the two layouts briefly overlap when the screen
  // turns, and a controller can't follow two scroll views at once.
  final _scrollController = ScrollController();
  final _overviewPaneScrollController = ScrollController();
  final _listPaneScrollController = ScrollController();

  /// Whether the tasks have been read in. Until then there's nothing under
  /// the title, rather than a "No Tasks" that flashes up first.
  bool _loaded = false;

  /// How many sections rise in ahead of the list's cards: the summary and
  /// the filter when the page opens, and none when only the list changes.
  int _listDelay = 2;

  /// The page's tour, which shows once, as the page first opens.
  final _tour = TourController();
  Timer? _tourStart;

  /// Whether the tour is on, or about to be, when the first card has
  /// [_firstCardKey], for the tour to find it by. It's only there then, as a
  /// global key moves a card's state along with it when the cards are
  /// reordered.
  bool _touring = false;

  /// What the tour points at.
  final _headerKey = GlobalKey();
  final _firstCardKey = GlobalKey();
  final _buttonsKey = GlobalKey();
  final _menuKey = GlobalKey();

  /// Which tours are due, which says when the user asks for them again.
  late final TourViewModel _tours;

  @override
  void initState() {
    super.initState();
    _tours = Provider.of<TourViewModel>(context, listen: false)
      ..addListener(_toursReplayed);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final tourDue = _tours.isDue(PageTour.tasks);
      var touring = false;
      try {
        await Provider.of<TasksViewModel>(context, listen: false).get();
        touring = await tourDue;
      } finally {
        if (mounted) {
          setState(() {
            _loaded = true;
            _touring = touring;
          });
        }
      }
      if (touring && mounted) _tourStart = Timer(_tourDelay, _startTour);
    });
  }

  @override
  void dispose() {
    _tours.removeListener(_toursReplayed);
    _tourStart?.cancel();
    _tour.dispose();
    _scrollController.dispose();
    _overviewPaneScrollController.dispose();
    _listPaneScrollController.dispose();
    super.dispose();
  }

  /// Shows the user how the page works: on the first card, or on an example
  /// one when there are no tasks.
  /// Shows the tour again once the user asks for the tips again in the
  /// settings, as they come back from them.
  Future<void> _toursReplayed() async {
    if (_touring || !await _tours.isDue(PageTour.tasks) || !mounted) return;
    setState(() => _touring = true);
    _tourStart?.cancel();
    _tourStart = Timer(_tourDelay, _startTour);
  }

  void _startTour() {
    final tasks = Provider.of<TasksViewModel>(context, listen: false).items;
    _tour.start(
      todoTour(
        task: tasks.firstOrNull,
        card: _firstCardKey,
        header: _headerKey,
        gap: _listTop,
        buttons: _buttonsKey,
        menu: _menuKey,
      ),
      onEnd: () {
        setState(() => _touring = false);
        _tours.finish(PageTour.tasks);
      },
    );
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
      child: Tour(
        controller: _tour,
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: context.colors.pageBackground,
          floatingActionButton: KeyedSubtree(
            key: _buttonsKey,
            child: PageActionButtons(
              switchIcon: Icons.edit_note_rounded,
              switchTooltip: "Notes",
              onSwitch: _openNotes,
              addTooltip: "Add Task",
              onAdd: _addTask,
            ),
          ),
          body: twoPanes ? _buildTwoPanes(context) : _buildOnePane(context),
        ),
      ),
    );
  }

  Widget _buildOnePane(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    // Keeps the cards a comfortable width on tablets.
    final gutter = math.max(16.0, (MediaQuery.sizeOf(context).width - 640) / 2);
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: LargeTitleBarDelegate(
            title: _title,
            topInset: padding.top,
            controller: _scrollController,
            trailing: _BarActions(items: _menuItems(), menuKey: _menuKey),
            titleRevealOffset: _TodoHeader.scrolledAway,
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          sliver: SliverToBoxAdapter(
            child: Column(
              key: _headerKey,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const RiseIn(child: _TodoHeader()),
                if (_loaded) _Overview(onFilterChanged: _changeFilter),
              ],
            ),
          ),
        ),
        if (_loaded)
          _TaskListSliver(
            padding: EdgeInsets.fromLTRB(gutter, _listTop, gutter,
                PageActionButtons.height + 24 + padding.bottom),
            listDelay: _listDelay,
            onEdit: _editTask,
            firstCardKey: _touring ? _firstCardKey : null,
          ),
      ],
    );
  }

  Widget _buildTwoPanes(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: CustomScrollView(
            controller: _overviewPaneScrollController,
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: LargeTitleBarDelegate(
                  title: _title,
                  topInset: padding.top,
                  controller: _overviewPaneScrollController,
                  titleRevealOffset: _TodoHeader.scrolledAway,
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                    16 + padding.left, 0, 16, 24 + padding.bottom),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    key: _headerKey,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const RiseIn(child: _TodoHeader()),
                      if (_loaded) _Overview(onFilterChanged: _changeFilter),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 6,
          child: CustomScrollView(
            controller: _listPaneScrollController,
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: LargeTitleBarDelegate(
                  // The title is in the other pane already.
                  title: "",
                  topInset: padding.top,
                  controller: _listPaneScrollController,
                  trailing: _BarActions(items: _menuItems(), menuKey: _menuKey),
                ),
              ),
              if (_loaded)
                _TaskListSliver(
                  padding: EdgeInsets.fromLTRB(16, 8, 16 + padding.right,
                      PageActionButtons.height + 24 + padding.bottom),
                  listDelay: _listDelay,
                  onEdit: _editTask,
                  firstCardKey: _touring ? _firstCardKey : null,
                ),
            ],
          ),
        ),
      ],
    );
  }

  List<GlassMenuItem> _menuItems() => [
        GlassMenuItem(
          icon: Icons.settings_backup_restore_rounded,
          tooltip: "Restore Backup",
          onPressed: () =>
              showFormDialog<void>(context, const TasksOverwriteDialog()),
        ),
        GlassMenuItem(
          icon: Icons.backup_rounded,
          tooltip: "Back Up Tasks",
          onPressed: _backUp,
        ),
        GlassMenuItem(
          icon: Icons.settings_rounded,
          tooltip: "Settings",
          onPressed: _openSettings,
        ),
      ];

  void _changeFilter(TaskFilter filter) {
    // The cards rise in again for the new filter, straight away.
    setState(() => _listDelay = 0);
    Provider.of<TasksViewModel>(context, listen: false).setFilter(filter);
  }

  /// Backs the tasks up, once the App Lock lets the user through.
  void _backUp() {
    Provider.of<TasksViewModel>(context, listen: false)
        .backup(
          askForPassword: passwordPrompt(context,
              subtitle: "Enter your password to back up your tasks."),
          askForBackupPassword: newBackupPasswordPrompt(context),
        )
        .then(_showResult);
  }

  void _addTask() => showFormDialog<void>(context, const TaskDialog());

  void _editTask(TodoItem task) =>
      showFormDialog<void>(context, TaskDialog(task: task));

  void _openNotes() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const NotesPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            SlideTransition(
          position: animation.drive(
              Tween(begin: const Offset(-1, 0), end: Offset.zero)
                  .chain(CurveTween(curve: Curves.ease))),
          child: child,
        ),
      ),
    );
  }

  void _openSettings() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const ProfilePage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            SlideTransition(
          position: animation.drive(
              Tween(begin: const Offset(0, 1), end: Offset.zero)
                  .chain(CurveTween(curve: Curves.ease))),
          child: child,
        ),
      ),
    );
  }
}

/// Shows how [result] went, if there's a result to show: none when the user
/// cancels.
void _showResult(Result? result) => result?.when(
      onSuccess: FeedbackToast.success,
      onFailure: FeedbackToast.error,
      onInfo: FeedbackToast.info,
    );

/// The menu of the tasks' less frequent actions, and the avatar, at the end
/// of the bar.
class _BarActions extends StatelessWidget {
  const _BarActions({required this.items, required this.menuKey});

  final List<GlassMenuItem> items;
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

/// Today's date over the page's large title, which scrolls away under the
/// bar.
class _TodoHeader extends StatelessWidget {
  const _TodoHeader();

  /// About how far the header scrolls before its title is under the bar, so
  /// the bar can bring in its own copy of the title.
  static const scrolledAway = 40.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DateFormat("EEEE, MMMM d").format(DateTime.now()).toUpperCase(),
          style: TextStyle(
            color: context.colors.moreLess,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: context.colors.wB,
            fontSize: 34,
            fontWeight: FontWeight.bold,
            height: 1.2,
            letterSpacing: -0.7,
          ),
        ),
      ],
    );
  }
}

/// The progress summary and the filters, under the title. Hidden while
/// there are no tasks, unless a filter other than All is still on, so it
/// can be turned off.
class _Overview extends StatelessWidget {
  const _Overview({required this.onFilterChanged});

  final ValueChanged<TaskFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final (total, filtered) =
        context.select<TasksViewModel, (int, bool)>((tasks) => (
              tasks.finishedTasksCount + tasks.unfinishedTasksCount,
              tasks.currentFilter is! AllTasksFilter,
            ));
    if (total == 0 && !filtered) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (total > 0)
          const Padding(
            padding: EdgeInsets.only(top: 18),
            child: RiseIn(delay: RiseIn.stagger, child: TasksSummaryCard()),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: RiseIn(
            delay: RiseIn.stagger * 2,
            child: TaskFilterBar(onChanged: onFilterChanged),
          ),
        ),
      ],
    );
  }
}

/// The tasks the filter lets through, or what to show instead when there
/// are none.
class _TaskListSliver extends StatelessWidget {
  const _TaskListSliver({
    required this.padding,
    required this.listDelay,
    required this.onEdit,
    required this.firstCardKey,
  });

  /// Around the list. Its bottom keeps the last card clear of the buttons.
  final EdgeInsets padding;

  /// How many sections rise in ahead of the first card.
  final int listDelay;

  /// Opens the editor for the task.
  final ValueChanged<TodoItem> onEdit;

  /// The key for the first card, if it's to have one.
  final GlobalKey? firstCardKey;

  @override
  Widget build(BuildContext context) {
    final tasks = context.watch<TasksViewModel>();
    if (tasks.emptyReason case final reason?) {
      return SliverFillRemaining(
        hasScrollBody: false,
        // Centred in the room the buttons leave, within the page rather than
        // past its end, so an empty page doesn't scroll.
        child: Padding(
          padding: EdgeInsets.only(top: padding.top, bottom: padding.bottom),
          child:
              RiseIn(key: ValueKey(reason), child: EmptyTasks(reason: reason)),
        ),
      );
    }
    return SliverPadding(
      padding: padding,
      // A new list for each filter, so the cards rise in afresh.
      sliver: _ReorderableTaskList(
        key: ValueKey(tasks.currentFilter.runtimeType),
        tasks: tasks,
        listDelay: listDelay,
        onEdit: onEdit,
        firstCardKey: firstCardKey,
      ),
    );
  }
}

class _ReorderableTaskList extends StatefulWidget {
  const _ReorderableTaskList({
    super.key,
    required this.tasks,
    required this.listDelay,
    required this.onEdit,
    required this.firstCardKey,
  });

  final TasksViewModel tasks;
  final int listDelay;
  final ValueChanged<TodoItem> onEdit;
  final GlobalKey? firstCardKey;

  @override
  State<_ReorderableTaskList> createState() => _ReorderableTaskListState();
}

class _ReorderableTaskListState extends State<_ReorderableTaskList> {
  /// Whether the list is being laid out for the first time, when the cards in
  /// view rise in one after another.
  bool _opening = true;

  /// The tasks listed at the last build, so a task added since can rise in
  /// by itself.
  Set<String> _listed = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _opening = false);
  }

  @override
  Widget build(BuildContext context) {
    final tasks = widget.tasks;
    final items = tasks.items;
    // Keyed by uuid, as ids change whenever the list is reordered, with a
    // count to tell apart any tasks that share one.
    final occurrences = <String, int>{};
    final keys = [
      for (final task in items)
        switch (occurrences.update(task.uuid, (count) => count + 1,
            ifAbsent: () => 0)) {
          0 => task.uuid,
          final count => "${task.uuid}#$count",
        },
    ];
    final listed = keys.toSet();
    final added = _opening ? const <String>{} : listed.difference(_listed);
    _listed = listed;
    final (titleScale, descriptionScale, descriptionLines) =
        context.select<UserViewModel, (double, double, int)>((user) => (
              user.user.tasksTitleSize,
              user.user.tasksDescSize,
              user.user.descLines,
            ));

    TaskCard card(TodoItem task, {bool interactive = true}) {
      return TaskCard(
        task: task,
        titleScale: titleScale,
        descriptionScale: descriptionScale,
        descriptionLines: descriptionLines,
        onToggle: !interactive
            ? null
            : () => tasks.toggleDone(task).then(_showResult),
        onEdit: !interactive ? null : () => widget.onEdit(task),
        onReminder: !interactive
            ? null
            : () => tasks.toggleReminder(task).then(_showResult),
        // Only while it has no reminder: the bell's tap turns one off.
        onDailyReminder: !interactive || task.reminder != Reminder.none
            ? null
            : () => tasks.remindDaily(task).then(_showResult),
      );
    }

    return SliverReorderableList(
      itemCount: items.length,
      onReorderStart: (_) => HapticFeedback.mediumImpact(),
      onReorderItem: tasks.syncAfterReorder,
      // The card being dragged is drawn again, without its entrance or its
      // swipe, which would start over in the drag's overlay.
      proxyDecorator: (child, index, animation) => _LiftedCard(
        animation: animation,
        child: card(items[index], interactive: false),
      ),
      itemBuilder: (context, index) {
        final task = items[index];
        final key = keys[index];
        return ReorderableDelayedDragStartListener(
          key: ValueKey(key),
          index: index,
          child: Padding(
            padding: const EdgeInsets.only(bottom: _cardGap),
            child: RiseIn(
              animate: _opening || added.contains(key),
              delay: _opening
                  ? RiseIn.stagger * (widget.listDelay + math.min(index, 8))
                  : Duration.zero,
              child: Dismissible(
                key: ValueKey(key),
                background: const TaskDeleteBackground(
                    alignment: AlignmentDirectional.centerStart),
                secondaryBackground: const TaskDeleteBackground(
                    alignment: AlignmentDirectional.centerEnd),
                onDismissed: (direction) => tasks
                    .delete(task)
                    .then((_) => FeedbackToast.info("Task Deleted")),
                child: KeyedSubtree(
                  key: index == 0 ? widget.firstCardKey : null,
                  child: card(task),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A card picked up to be reordered: it grows a little and casts a deeper
/// shadow, then settles back as it's dropped.
class _LiftedCard extends StatelessWidget {
  const _LiftedCard({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final lift = Curves.easeOutCubic.transform(animation.value);
        return Transform.scale(
          scale: 1 + 0.03 * lift,
          child: Stack(
            children: [
              Positioned.fill(
                bottom: _cardGap,
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    shape: TaskCard.shape,
                    shadows: [
                      BoxShadow(
                        color: Colors.black.withValues(
                            alpha: (isDarkTheme ? 0.5 : 0.18) * lift),
                        blurRadius: 32,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                ),
              ),
              child!,
            ],
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: _cardGap),
        child: child,
      ),
    );
  }
}
