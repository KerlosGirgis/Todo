import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../../core/ui/feedback_toast.dart';
import '../../../../../core/utils/date_time_utils.dart';
import '../../../../../models/clock_time.dart';
import '../../../../../models/task_tree.dart';
import '../../../../../models/todo_item.dart';
import '../../../../../view_model/tasks_view_model.dart';
import '../../../../widgets/check_circle.dart';
import '../../../profile/profile_page/widgets/profile_button.dart';
import '../../../profile/profile_page/widgets/settings_group.dart';
import 'form_dialog.dart';

const _accent = Color(0xff3D5AFE);

// iOS's system colours, as on the profile page's settings: red for the date
// and blue for the time, as in Reminders, orange for the alert, and indigo
// for the task it's in.
const _red = Color(0xffFF3B30);
const _blue = Color(0xff007AFF);
const _orange = Color(0xffFF9500);
const _indigo = Color(0xff5856D6);

/// Adds a task, or edits [task] when there is one: its title and
/// description, then the task it's a subtask of, its date, time and reminder
/// in rows like the profile page's settings.
class TaskDialog extends StatefulWidget {
  const TaskDialog({super.key, this.task, this.parent})
      : assert(task == null || parent == null);

  /// The task to edit, or null for a new one.
  final TodoItem? task;

  /// The task a new one is to be a subtask of, to start with.
  final TodoItem? parent;

  @override
  State<TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends State<TaskDialog> {
  late final TaskDraft _draft;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    final tasks = context.read<TasksViewModel>();
    final parent = widget.parent;
    _draft =
        parent == null ? tasks.draft(widget.task) : tasks.subtaskDraft(parent);
    _titleController = TextEditingController(text: _draft.title);
    _descriptionController = TextEditingController(text: _draft.description);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _draft.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    final date = _draft.day;
    final picked = await showDatePicker(
      context: context,
      // An overdue date is before the first one on offer, so it isn't kept.
      initialDate: date == null || date.isBefore(today) ? null : date,
      firstDate: today,
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) _draft.setDay(picked);
  }

  Future<void> _pickTime() async {
    final time = _draft.time;
    final picked = await showTimePicker(
      context: context,
      initialTime: time == null
          ? TimeOfDay.now()
          : TimeOfDay(hour: time.hour, minute: time.minute),
    );
    if (picked != null) _draft.setTime(ClockTime(picked.hour, picked.minute));
  }

  /// Has the user pick the task this one is a subtask of, or none.
  Future<void> _pickParent() async {
    final picked = await showFormDialog<_Place>(
      context,
      _ParentDialog(places: _draft.places, parent: _draft.parent),
    );
    if (picked != null) _draft.setParent(picked.task);
  }

  Future<void> _save() async {
    final tasks = context.read<TasksViewModel>();
    Navigator.of(context).pop();
    final result = await tasks.save(_draft);
    result.when(
      onSuccess: FeedbackToast.success,
      onFailure: FeedbackToast.error,
      onInfo: FeedbackToast.info,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ink = context.colors.wB;
    final adding = _draft.adding;
    return ListenableBuilder(
      listenable: _draft,
      builder: (context, child) {
        final date = _draft.day;
        final now = DateTime.now();
        final parent = _draft.parent;
        return FormDialog(
          icon: adding ? Icons.add_task_rounded : Icons.edit_rounded,
          title: !adding
              ? "Edit Task"
              : parent == null
                  ? "New Task"
                  : "New Subtask",
          subtitle: !adding
              ? "Change its details, then save."
              : parent == null
                  ? "What do you need to get done?"
                  : "What does it take to get that done?",
          content: [
            TextField(
              controller: _titleController,
              onChanged: _draft.setTitle,
              // Ready to type straight away when adding.
              autofocus: adding,
              maxLines: 1,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              cursorColor: _accent,
              style: TextStyle(
                color: ink,
                fontSize: 18,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.2,
              ),
              decoration: formFieldDecoration(context, hint: "Title"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descriptionController,
              onChanged: _draft.setDescription,
              minLines: 2,
              maxLines: 5,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              cursorColor: _accent,
              style: TextStyle(color: ink, fontSize: 16, height: 1.35),
              decoration: formFieldDecoration(context, hint: "Description"),
            ),
            const SizedBox(height: 16),
            FormDialogGroup(
              children: [
                // Only with another task for it to be in.
                if (_draft.places.isNotEmpty)
                  SettingsTile(
                    icon: Icons.account_tree_rounded,
                    color: _indigo,
                    title: "Part Of",
                    trailing: _PickedValue(
                      label: parent?.title,
                      onClear: () => _draft.setParent(null),
                    ),
                    onTap: _pickParent,
                  ),
                if (_draft.hasDay)
                  SettingsTile(
                    icon: Icons.calendar_today_rounded,
                    color: _red,
                    title: "Date",
                    trailing: _PickedValue(
                      label: date == null
                          ? null
                          : DateTimeUtils.friendlyDay(date, now),
                      onClear: () => _draft.setDay(null),
                    ),
                    onTap: _pickDate,
                  ),
                SettingsTile(
                  icon: Icons.schedule_rounded,
                  color: _blue,
                  title: "Time",
                  trailing: _PickedValue(
                    label: _draft.time?.label,
                    onClear: () => _draft.setTime(null),
                  ),
                  onTap: _pickTime,
                ),
                SettingsTile(
                  icon: Icons.notifications_rounded,
                  color: _orange,
                  title: "Reminder",
                  subtitle: _ReminderHint(draft: _draft, now: now),
                  bottom: CupertinoSlidingSegmentedControl<Reminder>(
                    groupValue: _draft.reminder,
                    onValueChanged: (reminder) {
                      if (reminder != null) _draft.setReminder(reminder);
                    },
                    children: const {
                      Reminder.none: _Segment("Off"),
                      Reminder.once: _Segment("Once"),
                      Reminder.daily: _Segment("Daily"),
                    },
                  ),
                ),
              ],
            ),
          ],
          actions: [
            ProfileButton(
              label: "Cancel",
              tinted: true,
              onPressed: () => Navigator.of(context).pop(),
            ),
            // Only once there's a title to save.
            ProfileButton(
              label: adding ? "Add" : "Save",
              onPressed: _draft.canSave ? _save : null,
            ),
          ],
        );
      },
    );
  }
}

/// A row's chosen value, in the accent, with a button that clears it, or
/// "None" before there is one.
class _PickedValue extends StatelessWidget {
  const _PickedValue({required this.label, required this.onClear});

  final String? label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (label == null) return const DisclosureValue("None");
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // A long one, like a task's title, is cut short.
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 132),
          child: Text(
            label!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.colors.moreLess,
              fontSize: 16,
              fontWeight: FontWeight.w500,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        IconButton(
          onPressed: onClear,
          tooltip: "Clear",
          visualDensity: VisualDensity.compact,
          icon: Icon(
            Icons.cancel_rounded,
            size: 20,
            color: context.colors.wB.withValues(alpha: 0.3),
          ),
        ),
      ],
    );
  }
}

/// What the reminder will do, or what it still needs before it can.
class _ReminderHint extends StatelessWidget {
  const _ReminderHint({required this.draft, required this.now});

  final TaskDraft draft;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final (hint, missing) = switch (draft.reminderStatus(now)) {
      ReminderStatus.off => ("No reminder", false),
      ReminderStatus.needsDayAndTime => ("Needs a date and a time", true),
      ReminderStatus.needsTime => ("Needs a time", true),
      ReminderStatus.inPast => ("Needs a date and time in the future", true),
      ReminderStatus.ready => draft.reminder == Reminder.daily
          ? ("Every day at ${draft.time!.label}", false)
          : (
              "${DateTimeUtils.friendlyDay(draft.day!, now)} at "
                  "${draft.time!.label}",
              false
            ),
    };
    return Text(
      hint,
      style: missing
          ? TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xffFF9F0A)
                  : const Color(0xffC93400),
            )
          : null,
    );
  }
}

/// A segment of the reminder's segmented control.
class _Segment extends StatelessWidget {
  const _Segment(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Text(label, style: const TextStyle(fontSize: 14.5)),
    );
  }
}

/// What the user picked for the task a task is a subtask of: [task], or
/// none at all, for a task of its own.
class _Place {
  const _Place(this.task);

  final TodoItem? task;
}

/// Has the user pick the task a task is a subtask of, from [places], each
/// under the task it's in itself, or none, for a task of its own. The one
/// it's in now, [parent], is ticked.
class _ParentDialog extends StatelessWidget {
  const _ParentDialog({required this.places, required this.parent});

  final List<TaskNode> places;
  final TodoItem? parent;

  @override
  Widget build(BuildContext context) {
    final current = parent;
    return FormDialog(
      icon: Icons.account_tree_rounded,
      title: "Part Of",
      subtitle: "Pick the task this one is a part of.",
      content: [
        ConstrainedBox(
          // About six rows, then they scroll.
          constraints: BoxConstraints(
              maxHeight: MediaQuery.textScalerOf(context).scale(16) * 3 + 250),
          child: Material(
            color: context.colors.wB.withValues(alpha: 0.06),
            shape: const RoundedSuperellipseBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: places.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _PlaceRow(
                    title: "None",
                    detail: "A task of its own",
                    picked: current == null,
                    onTap: () => Navigator.of(context).pop(const _Place(null)),
                  );
                }
                final node = places[index - 1];
                return _PlaceRow(
                  title: node.task.title,
                  depth: node.depth,
                  done: node.task.done,
                  picked: current != null && node.task.uuid == current.uuid,
                  onTap: () => Navigator.of(context).pop(_Place(node.task)),
                );
              },
            ),
          ),
        ),
      ],
      actions: [
        ProfileButton(
          label: "Cancel",
          tinted: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

/// A task to pick, a step in for each task it's inside of, with its check
/// as its card has it, and a tick at the end of the one that's picked.
class _PlaceRow extends StatelessWidget {
  const _PlaceRow({
    required this.title,
    this.detail,
    this.depth,
    this.done = false,
    required this.picked,
    required this.onTap,
  });

  final String title;
  final String? detail;

  /// How many tasks it's inside of, or null for the row that's no task.
  final int? depth;
  final bool done;
  final bool picked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = context.colors.wB;
    final depth = this.depth;
    final detail = this.detail;
    return MergeSemantics(
      child: Semantics(
        selected: picked,
        button: true,
        child: InkWell(
          onTap: onTap,
          splashFactory: NoSplash.splashFactory,
          highlightColor: ink.withValues(alpha: 0.06),
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
                // Less for each step once they're many, as on the list.
                14 + 16.0 * (depth ?? 0).clamp(0, 6),
                10,
                12,
                10),
            child: Row(
              children: [
                if (depth == null)
                  Icon(Icons.horizontal_rule_rounded,
                      size: 20, color: ink.withValues(alpha: 0.4))
                else
                  CheckCircle(doneness: done ? 1 : 0, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ink.withValues(alpha: done ? 0.45 : 1),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (detail != null)
                        Text(
                          detail,
                          style: TextStyle(
                            color: ink.withValues(alpha: 0.5),
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
                if (picked)
                  Icon(Icons.check_rounded,
                      size: 22, color: context.colors.moreLess),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
