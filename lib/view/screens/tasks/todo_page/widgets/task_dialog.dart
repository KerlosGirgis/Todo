import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../../core/ui/feedback_toast.dart';
import '../../../../../core/utils/date_time_utils.dart';
import '../../../../../models/clock_time.dart';
import '../../../../../models/todo_item.dart';
import '../../../../../view_model/tasks_view_model.dart';
import '../../../profile/profile_page/widgets/profile_button.dart';
import '../../../profile/profile_page/widgets/settings_group.dart';
import 'form_dialog.dart';

const _accent = Color(0xff3D5AFE);

// iOS's system colours, as on the profile page's settings: red for the date
// and blue for the time, as in Reminders, and orange for the alert.
const _red = Color(0xffFF3B30);
const _blue = Color(0xff007AFF);
const _orange = Color(0xffFF9500);

/// Adds a task, or edits [task] when there is one: its title and
/// description, then its date, time and reminder in rows like the profile
/// page's settings.
class TaskDialog extends StatefulWidget {
  const TaskDialog({super.key, this.task});

  /// The task to edit, or null for a new one.
  final TodoItem? task;

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
    _draft = context.read<TasksViewModel>().draft(widget.task);
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
        return FormDialog(
          icon: adding ? Icons.add_task_rounded : Icons.edit_rounded,
          title: adding ? "New Task" : "Edit Task",
          subtitle: adding
              ? "What do you need to get done?"
              : "Change its details, then save.",
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
        Text(
          label!,
          style: TextStyle(
            color: context.colors.moreLess,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            fontFeatures: const [FontFeature.tabularFigures()],
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
