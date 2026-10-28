import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../../../models/clock_time.dart';
import '../../../../../models/todo_item.dart';
import '../../../../../view_model/user_view_model.dart';
import '../../../../widgets/tour.dart';
import 'task_card.dart';

/// The to-do page's tour: how a task's card works, acted out on a copy of
/// [task], the first card, whose key is [card], or, with no tasks, on an
/// example where the first card would be, [gap] under [header]; then what
/// the page's [buttons] and [menu] are for.
List<TourStep> todoTour({
  required TodoItem? task,
  required GlobalKey card,
  required GlobalKey header,
  required double gap,
  required GlobalKey buttons,
  required GlobalKey menu,
}) {
  final shown = task ?? _example();
  final target = task == null ? header : card;
  final place = task == null
      ? (BuildContext context, Rect header) =>
          Rect.fromLTWH(header.left, header.bottom + gap, header.width, 0)
      : null;
  final check = GlobalKey();
  final title = GlobalKey();
  final bell = GlobalKey();

  TourDemo demo(
    List<TourGesture> gestures, {
    TodoItem Function(TourPose pose)? taskAt,
    GlobalKey? touch,
    Alignment touchAlignment = Alignment.center,
    Widget? behind,
  }) =>
      TourDemo(
        gestures: gestures,
        place: place,
        touch: touch,
        touchAlignment: touchAlignment,
        behind: behind,
        builder: (context, pose) => _TourTaskCard(
          task: taskAt?.call(pose) ?? shown,
          checkKey: check,
          titleKey: title,
          bellKey: bell,
        ),
      );

  return [
    TourStep(
      target: target,
      icon: Icons.check_rounded,
      title: "Check Off a Task",
      message: "Tap a task to mark it done. Tap it again to undo.",
      demo: demo(
        [TourGesture.tap, TourGesture.tap],
        taskAt: (pose) =>
            shown.copyWith(done: pose.acted.isOdd ? !shown.done : shown.done),
        touchAlignment: const Alignment(0.45, 0),
      ),
    ),
    TourStep(
      target: target,
      icon: Icons.edit_rounded,
      title: "Edit a Task",
      message: "Press and hold a task's title to edit it.",
      demo: demo(
        [TourGesture.hold],
        touch: title,
        touchAlignment: const Alignment(-0.7, 0),
      ),
    ),
    TourStep(
      target: target,
      icon: Icons.swap_vert_rounded,
      title: "Move a Task",
      message: "Press and hold anywhere else on a task, then drag it to "
          "where it belongs.",
      demo: demo([TourGesture.drag], touch: check),
    ),
    TourStep(
      target: target,
      icon: Icons.delete_rounded,
      title: "Delete a Task",
      message: "Swipe a task left or right to delete it.",
      demo: demo(
        [TourGesture.swipe],
        touchAlignment: const Alignment(0.6, 0),
        behind: const TaskDeleteBackground(
            alignment: AlignmentDirectional.centerEnd),
      ),
    ),
    TourStep(
      target: target,
      icon: Icons.notifications_active_rounded,
      title: "Get Reminded",
      message: "Tap the bell to be reminded at the task's time. Press and "
          "hold it to be reminded every day.",
      demo: demo(
        [TourGesture.tap],
        // A done task has no bell.
        taskAt: (pose) {
          final undone = shown.copyWith(done: false);
          return pose.acted.isOdd ? _withBellTapped(undone) : undone;
        },
        touch: bell,
      ),
    ),
    TourStep(
      target: buttons,
      icon: Icons.add_rounded,
      title: "Add a Task",
      message: "Tap + to add a task. The button above it switches to your "
          "notes.",
      radius: 20,
      padding: 8,
    ),
    TourStep(
      target: menu,
      icon: Icons.menu_rounded,
      title: "More Options",
      message: "Back up and restore your tasks, or open Settings, from this "
          "menu.",
      radius: 19,
    ),
  ];
}

/// [task] as a tap of its bell leaves it: reminding once, or not at all if
/// it reminded once already. A daily reminder stays as it is, as the card
/// would lose its "Daily" chip, and change height.
TodoItem _withBellTapped(TodoItem task) => switch (task.reminder) {
      Reminder.none => task.copyWith(reminder: Reminder.once),
      Reminder.once => task.copyWith(reminder: Reminder.none),
      Reminder.daily => task,
    };

/// A task to show the cards' gestures on when there are none: for tomorrow
/// morning, so it's never overdue.
TodoItem _example() {
  final now = DateTime.now();
  return TodoItem(
    uuid: "tour",
    title: "Water the plants",
    desc: "And the ones out on the balcony.",
    day: DateTime(now.year, now.month, now.day + 1),
    time: const ClockTime(9, 0),
  );
}

/// A copy of [task]'s card, at the user's text sizes, with keys on its parts
/// for the tour to point at.
class _TourTaskCard extends StatelessWidget {
  const _TourTaskCard({
    required this.task,
    required this.checkKey,
    required this.titleKey,
    required this.bellKey,
  });

  final TodoItem task;
  final GlobalKey checkKey;
  final GlobalKey titleKey;
  final GlobalKey bellKey;

  @override
  Widget build(BuildContext context) {
    final (titleScale, descriptionScale, descriptionLines) =
        context.select<UserViewModel, (double, double, int)>((user) => (
              user.user.tasksTitleSize,
              user.user.tasksDescSize,
              user.user.descLines,
            ));
    return TaskCard(
      task: task,
      titleScale: titleScale,
      descriptionScale: descriptionScale,
      descriptionLines: descriptionLines,
      checkKey: checkKey,
      titleKey: titleKey,
      bellKey: bellKey,
    );
  }
}
