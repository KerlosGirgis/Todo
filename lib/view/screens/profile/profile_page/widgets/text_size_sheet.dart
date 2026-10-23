import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../../core/result.dart';
import '../../../../../core/ui/feedback_toast.dart';
import '../../../../../models/todo_item.dart';
import '../../../../../view_model/user_view_model.dart';
import '../../../notes/note_editor_page/screen/note_editor_page.dart';
import '../../../notes/notes_page/widgets/note_card.dart';
import '../../../tasks/todo_page/widgets/task_card.dart';
import 'profile_button.dart';

const _accent = Color(0xff3D5AFE);

/// A text size the profile page sets, and how to read and change it on the
/// [UserViewModel], which keeps a draft of each size while its sheet is open.
enum TextSizeSetting {
  taskTitle("Task Title"),
  taskDescription("Task Description"),
  noteTitle("Note Title"),
  noteBody("Note Body");

  const TextSizeSetting(this.label);

  final String label;

  double saved(UserViewModel user) => switch (this) {
        taskTitle => user.user.tasksTitleSize,
        taskDescription => user.user.tasksDescSize,
        noteTitle => user.user.notesTitleSize,
        noteBody => user.user.notesTextSize,
      };

  double draft(UserViewModel user) => switch (this) {
        taskTitle => user.tempTasksTitleSize,
        taskDescription => user.tempTasksDescSize,
        noteTitle => user.tempNotesTitleSize,
        noteBody => user.tempNotesTextSize,
      };

  void setDraft(UserViewModel user, double size) {
    switch (this) {
      case taskTitle:
        user.setTempTasksTitleSize(size);
      case taskDescription:
        user.setTempTasksDescSize(size);
      case noteTitle:
        user.setTempNotesTitleSize(size);
      case noteBody:
        user.setTempNotesSize(size);
    }
  }

  /// Saves the draft.
  Future<Result> apply(UserViewModel user) => switch (this) {
        taskTitle => user.setTasksTitleSize(),
        taskDescription => user.setTasksDescSize(),
        noteTitle => user.setNotesTitleSize(),
        noteBody => user.setNotesTextSize(),
      };
}

/// 1.125 -> "112.5%"
String formatTextSize(double size) {
  final percent = (size * 1000).round() / 10;
  return percent == percent.roundToDouble()
      ? "${percent.round()}%"
      : "$percent%";
}

/// Opens the sheet that sets [setting]. A size that isn't applied is dropped
/// when the sheet closes.
Future<void> showTextSizeSheet(BuildContext context, TextSizeSetting setting) {
  final user = context.read<UserViewModel>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: context.colors.cardBackground,
    shape: const RoundedSuperellipseBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (context) => TextSizeSheet(setting: setting),
  ).whenComplete(() => setting.setDraft(user, setting.saved(user)));
}

/// A slider for one of the text sizes, over a preview of the text it sizes.
class TextSizeSheet extends StatelessWidget {
  const TextSizeSheet({super.key, required this.setting});

  final TextSizeSetting setting;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserViewModel>();
    final size = setting.draft(user);
    final secondary = context.colors.wB.withValues(alpha: 0.5);
    return SingleChildScrollView(
      // Clear of the gesture bar, which a bottom sheet's safe area leaves in.
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, 20 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            setting.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.colors.wB,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Drag the slider until it reads comfortably.",
            textAlign: TextAlign.center,
            style: TextStyle(color: secondary, fontSize: 14),
          ),
          const SizedBox(height: 20),
          _Preview(setting: setting, size: size, user: user),
          const SizedBox(height: 24),
          Row(
            children: [
              Text(
                "A",
                style: TextStyle(
                    color: secondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CupertinoSlider(
                  value: size,
                  min: 0.25,
                  max: 2,
                  divisions: 14,
                  activeColor: _accent,
                  // Snapped to the eighths the divisions stand for, so the
                  // value reads cleanly and matches the saved one exactly.
                  onChanged: (value) =>
                      setting.setDraft(user, (value * 8).round() / 8),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "A",
                style: TextStyle(
                    color: secondary,
                    fontSize: 26,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          SizedBox(
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  formatTextSize(size),
                  style: TextStyle(
                    color: context.colors.wB,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: AnimatedOpacity(
                    opacity: size == 1 ? 0 : 1,
                    duration: const Duration(milliseconds: 150),
                    child: TextButton(
                      onPressed:
                          size == 1 ? null : () => setting.setDraft(user, 1),
                      style: TextButton.styleFrom(
                          foregroundColor: context.colors.moreLess),
                      child: const Text("Reset"),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ProfileButton(
            label: "Apply",
            onPressed: size == setting.saved(user)
                ? null
                : () => _apply(context, user),
          ),
        ],
      ),
    );
  }

  Future<void> _apply(BuildContext context, UserViewModel user) async {
    final result = await setting.apply(user);
    if (result is Success && context.mounted) Navigator.pop(context);
    result.when(
      onSuccess: FeedbackToast.success,
      onFailure: FeedbackToast.error,
      onInfo: FeedbackToast.info,
    );
  }
}

/// A copy of where the text appears, drawn at the draft [size], with any
/// other text on it at its saved size.
class _Preview extends StatefulWidget {
  const _Preview(
      {required this.setting, required this.size, required this.user});

  final TextSizeSetting setting;
  final double size;
  final UserViewModel user;

  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  /// Whether the text is too big to fit, so it's faded out at the bottom
  /// rather than cut off.
  bool _overflowing = false;

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final saved = widget.user.user;
    final preview = switch (widget.setting) {
      TextSizeSetting.taskTitle =>
        _TaskPreview(titleSize: size, descSize: saved.tasksDescSize),
      TextSizeSetting.taskDescription =>
        _TaskPreview(titleSize: saved.tasksTitleSize, descSize: size),
      TextSizeSetting.noteTitle => _NoteCardPreview(titleSize: size),
      TextSizeSetting.noteBody =>
        _NoteBodyPreview(size: size, casualFont: saved.casual == 1),
    };
    return Container(
      height: 220,
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: context.colors.pageBackground,
        shape: const RoundedSuperellipseBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
      ),
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black,
            Colors.black,
            _overflowing ? Colors.transparent : Colors.black,
          ],
          stops: const [0, 0.82, 1],
        ).createShader(bounds),
        child: Align(
          // A note's body starts at the top, like in the editor; the cards
          // sit in the middle while they fit.
          alignment: widget.setting == TextSizeSetting.noteBody
              ? Alignment.topLeft
              : Alignment.center,
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: (notification) {
              final overflowing = notification.metrics.maxScrollExtent > 0;
              if (overflowing != _overflowing) {
                setState(() => _overflowing = overflowing);
              }
              return true;
            },
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: preview,
            ),
          ),
        ),
      ),
    );
  }
}

/// A task card as the to-do page draws it.
class _TaskPreview extends StatelessWidget {
  const _TaskPreview({required this.titleSize, required this.descSize});

  final double titleSize;
  final double descSize;

  @override
  Widget build(BuildContext context) {
    return TaskCard(
      task: _sampleTask,
      titleScale: titleSize,
      descriptionScale: descSize,
      descriptionLines: 0,
    );
  }
}

final _sampleTask = TodoItem(
  title: "Water the plants",
  desc: "The ferns on the balcony are looking thirsty.",
  status: 0,
  date: "",
  time: "6:00 PM",
  uuid: "",
  notification: 1,
);

/// A note's card as the notes page draws it.
class _NoteCardPreview extends StatelessWidget {
  const _NoteCardPreview({required this.titleSize});

  final double titleSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 188,
      child: NoteCover(
        color: _accent,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Weekend Plans",
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24 * titleSize,
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                  letterSpacing: -0.4 * titleSize,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  "Farmers market in the morning, then a long walk by the "
                  "river.",
                  overflow: TextOverflow.fade,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 15,
                    height: 1.38,
                    letterSpacing: -0.15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A note's text as the editor draws it.
class _NoteBodyPreview extends StatelessWidget {
  const _NoteBodyPreview({required this.size, required this.casualFont});

  final double size;
  final bool casualFont;

  @override
  Widget build(BuildContext context) {
    return Text(
      "Today I finally sorted out my notes. Everything has a place now, and "
      "it feels good.",
      style: noteBodyStyle(context, size: size, casualFont: casualFont),
    );
  }
}
