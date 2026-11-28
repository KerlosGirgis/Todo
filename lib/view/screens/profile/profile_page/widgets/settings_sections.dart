import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../../../core/result.dart';
import '../../../../../core/theme/palette.dart';
import '../../../../../core/ui/feedback_toast.dart';
import '../../../../../models/app_lock.dart';
import '../../../../../models/text_size.dart';
import '../../../../../models/user_profile.dart';
import '../../../../../models/widget_style.dart';
import '../../../../../view_model/tour_view_model.dart';
import '../../../../../view_model/user_view_model.dart';
import '../../../../../view_model/widgets_view_model.dart';
import '../../../../widgets/password_dialogs.dart';
import '../../../../widgets/segment_label.dart';
import '../../../../widgets/settings_group.dart';
import 'appearance_picker.dart';
import 'text_size_sheet.dart';
import 'widget_style_sheet.dart';

class AppearanceSection extends StatelessWidget {
  const AppearanceSection({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = context.select<UserViewModel, bool>(
      (user) => user.user.darkTheme,
    );
    final amoled = context.select<UserViewModel, bool>(
      (user) => user.user.amoledTheme,
    );
    return SettingsGroup(
      title: "Appearance",
      children: [
        const AppearancePicker(),
        if (dark)
          SettingsSwitchTile(
            icon: Icons.contrast_rounded,
            color: SystemColors.indigo,
            title: "AMOLED Black",
            subtitle: const Text("Pure black backgrounds in dark mode"),
            value: amoled,
            onChanged: (amoled) => context
                .read<UserViewModel>()
                .setAmoledTheme(amoled)
                .then(FeedbackToast.show),
          ),
      ],
    );
  }
}

class GeneralSection extends StatelessWidget {
  const GeneralSection({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserViewModel>();
    return SettingsGroup(
      title: "General",
      children: [
        SettingsTile(
          icon: Icons.home_rounded,
          color: SystemColors.blue,
          title: "Start Page",
          subtitle: const Text("Where the app opens"),
          bottom: CupertinoSlidingSegmentedControl<StartPage>(
            groupValue: user.user.startPage,
            onValueChanged: (page) {
              if (page != null) {
                user.setStartPage(page).then(FeedbackToast.show);
              }
            },
            children: const {
              StartPage.tasks: SegmentLabel(
                icon: Icons.checklist_rounded,
                label: "To-Do",
              ),
              StartPage.notes: SegmentLabel(
                icon: Icons.sticky_note_2_rounded,
                label: "Notes",
              ),
            },
          ),
        ),
        SettingsSwitchTile(
          icon: Icons.auto_stories_rounded,
          color: SystemColors.orange,
          title: "Daily Verse",
          subtitle: const Text("Shown when you tap your avatar"),
          value: user.user.showVerse,
          onChanged: (on) => user.setShowVerse(on).then(FeedbackToast.show),
        ),
        const _AppLockTile(),
        if (user.appLock == AppLock.password) const _ChangePasswordTile(),
        const _ShowTipsTile(),
      ],
    );
  }
}

/// A row that shows the pages' tips again: back on the page the settings
/// were opened from, straight away, and on the other page when it next
/// opens.
class _ShowTipsTile extends StatelessWidget {
  const _ShowTipsTile();

  @override
  Widget build(BuildContext context) {
    // Read out as a button of its own, rather than as part of the group.
    return MergeSemantics(
      child: SettingsTile(
        icon: Icons.lightbulb_rounded,
        color: SystemColors.yellow,
        title: "Show Tips Again",
        subtitle: const Text("How the To-Do and Notes pages work"),
        onTap: () {
          context.read<TourViewModel>().replay();
          Navigator.pop(context);
        },
      ),
    );
  }
}

/// The App Lock's row, with its choices under it. A change takes what the
/// app is locked with now first, and for a password lock, a new password.
class _AppLockTile extends StatefulWidget {
  const _AppLockTile();

  @override
  State<_AppLockTile> createState() => _AppLockTileState();
}

class _AppLockTileState extends State<_AppLockTile> {
  /// The lock being changed to, shown as chosen while the user confirms it.
  AppLock? _changingTo;

  Future<void> _change(AppLock lock) async {
    if (_changingTo != null) return;
    setState(() => _changingTo = lock);
    FeedbackToast.show(await _changeAppLock(context, lock));
    // Back to the lock the app has, if the change didn't go through.
    if (mounted) setState(() => _changingTo = null);
  }

  @override
  Widget build(BuildContext context) {
    final lock = context.select<UserViewModel, AppLock>((user) => user.appLock);
    return SettingsTile(
      icon: Icons.lock_rounded,
      color: SystemColors.green,
      title: "App Lock",
      subtitle: const Text(
        "Needed each time the app opens, and after a "
        "minute away",
      ),
      bottom: CupertinoSlidingSegmentedControl<AppLock>(
        groupValue: _changingTo ?? lock,
        onValueChanged: (lock) {
          if (lock != null) _change(lock);
        },
        children: const {
          AppLock.off: SegmentLabel(label: "Off"),
          AppLock.fingerprint: SegmentLabel(label: "Fingerprint"),
          AppLock.password: SegmentLabel(label: "Password"),
        },
      ),
    );
  }
}

/// A row that changes the App Lock's password, once the one it has now is
/// given.
class _ChangePasswordTile extends StatelessWidget {
  const _ChangePasswordTile();

  @override
  Widget build(BuildContext context) {
    // Read out as a button of its own, rather than as part of the group.
    return MergeSemantics(
      child: SettingsTile(
        icon: Icons.password_rounded,
        color: SystemColors.green,
        title: "Change Password",
        onTap: () async =>
            FeedbackToast.show(await _changeAppLock(context, AppLock.password)),
      ),
    );
  }
}

/// Changes the App Lock to [lock], with the prompts it asks the user with.
/// Null if the user cancels.
Future<Result?> _changeAppLock(BuildContext context, AppLock lock) {
  return context.read<UserViewModel>().changeAppLock(
    lock,
    askForPassword: passwordPrompt(
      context,
      subtitle: lock == AppLock.password
          ? "Enter your current password first."
          : "Enter your password to change the App Lock.",
    ),
    askForNewPassword: newPasswordPrompt(context),
  );
}

class TasksSection extends StatelessWidget {
  const TasksSection({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserViewModel>();
    return SettingsGroup(
      title: "Tasks",
      children: [
        SettingsTile(
          icon: Icons.hub_rounded,
          color: SystemColors.green,
          title: "Show Tasks As",
          subtitle: const Text("A list, or a map that branches into subtasks"),
          bottom: CupertinoSlidingSegmentedControl<TasksView>(
            groupValue: user.user.tasksView,
            onValueChanged: (view) {
              if (view != null) {
                user.setTasksView(view).then(FeedbackToast.show);
              }
            },
            children: const {
              TasksView.list: SegmentLabel(
                icon: Icons.view_agenda_rounded,
                label: "List",
              ),
              TasksView.map: SegmentLabel(
                icon: Icons.hub_rounded,
                label: "Map",
              ),
            },
          ),
        ),
        const _TextSizeTile(
          setting: TextSizeSetting.taskTitle,
          icon: Icons.title_rounded,
          color: SystemColors.indigo,
          title: "Title Size",
        ),
        const _TextSizeTile(
          setting: TextSizeSetting.taskDescription,
          icon: Icons.notes_rounded,
          color: SystemColors.purple,
          title: "Description Size",
        ),
        SettingsTile(
          icon: Icons.segment_rounded,
          color: SystemColors.teal,
          title: "Description Lines",
          subtitle: const Text("Shown before “Show More”"),
          bottom: CupertinoSlidingSegmentedControl<int>(
            groupValue: user.user.descLines,
            onValueChanged: (lines) {
              if (lines != null) {
                user.setDescLines(lines).then(FeedbackToast.show);
              }
            },
            children: {
              0: const SegmentLabel(label: "Off"),
              for (var lines = 1; lines <= UserViewModel.maxDescLines; lines++)
                lines: SegmentLabel(label: "$lines"),
            },
          ),
        ),
        const _WidgetTile(
          kind: WidgetKind.tasks,
          subtitle: "Your tasks on the home screen",
        ),
      ],
    );
  }
}

class NotesSection extends StatelessWidget {
  const NotesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserViewModel>();
    return SettingsGroup(
      title: "Notes",
      children: [
        SettingsSwitchTile(
          icon: Icons.save_rounded,
          color: SystemColors.mint,
          title: "Auto Save",
          subtitle: const Text("Save changes as you type"),
          value: user.user.autoSave,
          onChanged: (on) => user.setAutoSave(on).then(FeedbackToast.show),
        ),
        SettingsSwitchTile(
          icon: Icons.numbers_rounded,
          color: SystemColors.cyan,
          title: "Word Count",
          subtitle: const Text("Show a live count while you write"),
          value: user.user.wordCount,
          onChanged: (on) => user.setWordCount(on).then(FeedbackToast.show),
        ),
        SettingsSwitchTile(
          icon: Icons.font_download_rounded,
          color: SystemColors.pink,
          title: "Casual Font",
          // Written in the font itself, as a sample.
          subtitle: const Text(
            "A relaxed, handwritten look",
            style: TextStyle(fontFamily: 'casual', fontWeight: FontWeight.w600),
          ),
          value: user.user.casualFont,
          onChanged: (on) => user.setCasualFont(on).then(FeedbackToast.show),
        ),
        const _TextSizeTile(
          setting: TextSizeSetting.noteTitle,
          icon: Icons.title_rounded,
          color: SystemColors.indigo,
          title: "Title Size",
        ),
        const _TextSizeTile(
          setting: TextSizeSetting.noteBody,
          icon: Icons.notes_rounded,
          color: SystemColors.purple,
          title: "Body Size",
        ),
        const _WidgetTile(
          kind: WidgetKind.note,
          subtitle: "A note on the home screen",
        ),
        const _ClearNoteWidgetTile(),
      ],
    );
  }
}

/// A row that takes the note off the home screen's note widget, which then
/// says "Note" until a note is put on it again from its editor. It says
/// which note the widget shows, and is dimmed while it shows none.
class _ClearNoteWidgetTile extends StatefulWidget {
  const _ClearNoteWidgetTile();

  @override
  State<_ClearNoteWidgetTile> createState() => _ClearNoteWidgetTileState();
}

class _ClearNoteWidgetTileState extends State<_ClearNoteWidgetTile> {
  @override
  void initState() {
    super.initState();
    // Afresh, as a note may have been put on the widget since.
    context.read<WidgetsViewModel>().loadNote();
  }

  Future<void> _clear() async =>
      FeedbackToast.show(await context.read<WidgetsViewModel>().clearNote());

  @override
  Widget build(BuildContext context) {
    final text = context.select<WidgetsViewModel, String?>(
      (widgets) => widgets.noteText,
    );
    final firstLine = text
        ?.split("\n")
        .map((line) => line.trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => "");
    return AnimatedOpacity(
      opacity: text == null ? 0.45 : 1,
      duration: const Duration(milliseconds: 200),
      // Read out as a button of its own, rather than as part of the group.
      child: MergeSemantics(
        child: SettingsTile(
          icon: Icons.backspace_rounded,
          color: SystemColors.red,
          title: "Clear Widget",
          subtitle: Text(
            text == null ? "No note on it now" : "Shows “$firstLine”",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: text == null ? null : _clear,
        ),
      ),
    );
  }
}

/// A row that opens the sheet styling [kind] of home screen widget.
class _WidgetTile extends StatelessWidget {
  const _WidgetTile({required this.kind, required this.subtitle});

  final WidgetKind kind;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    // Read out as a button of its own, rather than as part of the group.
    return MergeSemantics(
      child: SettingsTile(
        icon: Icons.widgets_rounded,
        color: SystemColors.blue,
        title: "Home Screen Widget",
        subtitle: Text(subtitle),
        trailing: const DisclosureValue("Style"),
        onTap: () => showWidgetStyleSheet(context, kind),
      ),
    );
  }
}

/// A row showing one of the text sizes, which opens its sheet.
class _TextSizeTile extends StatelessWidget {
  const _TextSizeTile({
    required this.setting,
    required this.icon,
    required this.color,
    required this.title,
  });

  final TextSizeSetting setting;
  final IconData icon;
  final Color color;
  final String title;

  @override
  Widget build(BuildContext context) {
    final size = context.select<UserViewModel, double>(
      (user) => user.user.textSize(setting),
    );
    return SettingsTile(
      icon: icon,
      color: color,
      title: title,
      trailing: DisclosureValue(formatTextSize(size)),
      onTap: () => showTextSizeSheet(context, setting),
    );
  }
}
