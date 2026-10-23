import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../../../core/result.dart';
import '../../../../../core/ui/feedback_toast.dart';
import '../../../../../view_model/user_view_model.dart';
import 'appearance_picker.dart';
import 'settings_group.dart';
import 'text_size_sheet.dart';

// iOS's system colours, so that each setting has an icon of its own colour,
// as in the Settings app.
const _blue = Color(0xff007AFF);
const _orange = Color(0xffFF9500);
const _green = Color(0xff34C759);
const _indigo = Color(0xff5856D6);
const _purple = Color(0xffAF52DE);
const _teal = Color(0xff30B0C7);
const _mint = Color(0xff00C7BE);
const _cyan = Color(0xff32ADE6);
const _pink = Color(0xffFF2D55);

class AppearanceSection extends StatelessWidget {
  const AppearanceSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const SettingsGroup(
      title: "Appearance",
      children: [AppearancePicker()],
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
          color: _blue,
          title: "Start Page",
          subtitle: const Text("Where the app opens"),
          bottom: CupertinoSlidingSegmentedControl<int>(
            groupValue: user.user.startPage,
            onValueChanged: (page) {
              if (page != null) user.changeStartPage(page);
            },
            children: const {
              0: _Segment(icon: Icons.checklist_rounded, label: "To-Do"),
              1: _Segment(icon: Icons.sticky_note_2_rounded, label: "Notes"),
            },
          ),
        ),
        SettingsSwitchTile(
          icon: Icons.auto_stories_rounded,
          color: _orange,
          title: "Daily Verse",
          subtitle: const Text("Shown when you tap your avatar"),
          value: user.user.verse == 1,
          onToggle: user.changeVerse,
        ),
        SettingsSwitchTile(
          icon: Icons.fingerprint_rounded,
          color: _green,
          title: "App Lock",
          subtitle: const Text("Unlock with your fingerprint"),
          value: user.isEnabled,
          onToggle: () => user.changeLock().then(_showResult),
        ),
      ],
    );
  }
}

class TasksSection extends StatelessWidget {
  const TasksSection({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserViewModel>();
    return SettingsGroup(
      title: "Tasks",
      children: [
        const _TextSizeTile(
          setting: TextSizeSetting.taskTitle,
          icon: Icons.title_rounded,
          color: _indigo,
          title: "Title Size",
        ),
        const _TextSizeTile(
          setting: TextSizeSetting.taskDescription,
          icon: Icons.notes_rounded,
          color: _purple,
          title: "Description Size",
        ),
        SettingsTile(
          icon: Icons.segment_rounded,
          color: _teal,
          title: "Description Lines",
          subtitle: const Text("Shown before “Show More”"),
          bottom: CupertinoSlidingSegmentedControl<int>(
            groupValue: user.user.descLines,
            onValueChanged: (lines) {
              if (lines != null) user.setDescLines(lines);
            },
            children: {
              0: const _Segment(label: "Off"),
              for (var lines = 1; lines <= 5; lines++)
                lines: _Segment(label: "$lines"),
            },
          ),
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
          color: _mint,
          title: "Auto Save",
          subtitle: const Text("Save changes as you type"),
          value: user.user.autoSave == 1,
          onToggle: user.changeAutoSave,
        ),
        SettingsSwitchTile(
          icon: Icons.numbers_rounded,
          color: _cyan,
          title: "Word Count",
          subtitle: const Text("Show a live count while you write"),
          value: user.user.count == 1,
          onToggle: user.changeCount,
        ),
        SettingsSwitchTile(
          icon: Icons.font_download_rounded,
          color: _pink,
          title: "Casual Font",
          // Written in the font itself, as a sample.
          subtitle: const Text(
            "A relaxed, handwritten look",
            style: TextStyle(fontFamily: 'casual', fontWeight: FontWeight.w600),
          ),
          value: user.user.casual == 1,
          onToggle: user.changeFont,
        ),
        const _TextSizeTile(
          setting: TextSizeSetting.noteTitle,
          icon: Icons.title_rounded,
          color: _indigo,
          title: "Title Size",
        ),
        const _TextSizeTile(
          setting: TextSizeSetting.noteBody,
          icon: Icons.notes_rounded,
          color: _purple,
          title: "Body Size",
        ),
      ],
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
    final size = context.select<UserViewModel, double>(setting.saved);
    return SettingsTile(
      icon: icon,
      color: color,
      title: title,
      trailing: DisclosureValue(formatTextSize(size)),
      onTap: () => showTextSizeSheet(context, setting),
    );
  }
}

/// A segment of a segmented control: a label, after an optional icon.
class _Segment extends StatelessWidget {
  const _Segment({this.icon, required this.label});

  final IconData? icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 17),
            const SizedBox(width: 6),
          ],
          Text(label, style: const TextStyle(fontSize: 14.5)),
        ],
      ),
    );
  }
}

void _showResult(Result result) => result.when(
      onSuccess: FeedbackToast.success,
      onFailure: FeedbackToast.error,
      onInfo: FeedbackToast.info,
    );
