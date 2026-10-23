import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/v4.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../../core/ui/feedback_toast.dart';
import '../../../../../core/utils/date_time_utils.dart';
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

/// The task's reminder, as stored in [TodoItem.notification].
const _noReminder = 0;
const _onceReminder = 1;
const _dailyReminder = 2;

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
  late final _titleController = TextEditingController(text: widget.task?.title);
  late final _descriptionController =
      TextEditingController(text: widget.task?.desc);
  late String _date = widget.task?.date ?? "";
  late String _time = widget.task?.time ?? "";
  late int _reminder = widget.task?.notification ?? _noReminder;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    final date = DateTime.tryParse(_date);
    final picked = await showDatePicker(
      context: context,
      // An overdue date is before the first one on offer, so it isn't kept.
      initialDate: date == null || date.isBefore(today) ? null : date,
      firstDate: today,
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() => _date = DateFormat("yyyy-MM-dd").format(picked));
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: DateTimeUtils.tryParseTime(_time) ?? TimeOfDay.now(),
    );
    if (picked == null) return;
    setState(() {
      _time = DateTimeUtils.formatTime(picked);
      // A time on its own is for today, unless it's for every day.
      if (_date.isEmpty && _reminder != _dailyReminder) {
        _date = DateFormat("yyyy-MM-dd").format(DateTime.now());
      }
    });
  }

  void _setReminder(int reminder) {
    setState(() {
      _reminder = reminder;
      // A daily reminder goes off at its time every day, so it has no date.
      if (reminder == _dailyReminder) _date = "";
    });
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    final tasks = context.read<TasksViewModel>();
    Navigator.of(context).pop();
    final task = widget.task;
    final result = task == null
        ? await tasks.addTask(
            TodoItem(
              title: title,
              desc: _descriptionController.text.trim(),
              status: 0,
              date: _date,
              time: _time,
              uuid: const UuidV4().generate(),
              notification: _noReminder,
            ),
            _reminder)
        : await tasks.updateTask(TodoItem(
            title: title,
            desc: _descriptionController.text.trim(),
            id: task.id,
            status: task.status,
            date: _date,
            time: _time,
            uuid: task.uuid,
            notification: _reminder,
          ));
    result.when(
      onSuccess: FeedbackToast.success,
      onFailure: FeedbackToast.error,
      onInfo: FeedbackToast.info,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ink = context.colors.wB;
    final adding = widget.task == null;
    final date = DateTime.tryParse(_date);
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
            if (_reminder != _dailyReminder)
              SettingsTile(
                icon: Icons.calendar_today_rounded,
                color: _red,
                title: "Date",
                trailing: _PickedValue(
                  label: date == null
                      ? (_date.isEmpty ? null : _date)
                      : DateTimeUtils.friendlyDay(date, now),
                  onClear: () => setState(() => _date = ""),
                ),
                onTap: _pickDate,
              ),
            SettingsTile(
              icon: Icons.schedule_rounded,
              color: _blue,
              title: "Time",
              trailing: _PickedValue(
                label: _time.isEmpty ? null : _time,
                onClear: () => setState(() => _time = ""),
              ),
              onTap: _pickTime,
            ),
            SettingsTile(
              icon: Icons.notifications_rounded,
              color: _orange,
              title: "Reminder",
              subtitle: _ReminderHint(
                reminder: _reminder,
                date: date,
                time: _time,
                now: now,
              ),
              bottom: CupertinoSlidingSegmentedControl<int>(
                groupValue: _reminder,
                onValueChanged: (reminder) {
                  if (reminder != null) _setReminder(reminder);
                },
                children: const {
                  _noReminder: _Segment("Off"),
                  _onceReminder: _Segment("Once"),
                  _dailyReminder: _Segment("Daily"),
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
        ListenableBuilder(
          listenable: _titleController,
          builder: (context, child) => ProfileButton(
            label: adding ? "Add" : "Save",
            onPressed:
                _titleController.text.trim().isEmpty ? null : () => _save(),
          ),
        ),
      ],
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
  const _ReminderHint({
    required this.reminder,
    required this.date,
    required this.time,
    required this.now,
  });

  final int reminder;
  final DateTime? date;
  final String time;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final (hint, missing) = switch (reminder) {
      _onceReminder when date == null || time.isEmpty => (
          "Needs a date and a time",
          true
        ),
      _onceReminder => (
          "${DateTimeUtils.friendlyDay(date!, now)} at $time",
          false
        ),
      _dailyReminder when time.isEmpty => ("Needs a time", true),
      _dailyReminder => ("Every day at $time", false),
      _ => ("No reminder", false),
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
