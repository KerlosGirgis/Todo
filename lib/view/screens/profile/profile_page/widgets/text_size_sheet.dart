import 'dart:math' as math;

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../../core/result.dart';
import '../../../../../core/ui/feedback_toast.dart';
import '../../../../../models/note.dart';
import '../../../../../models/todo_item.dart';
import '../../../../../view_model/user_view_model.dart';
import '../../../notes/note_editor_page/widgets/note_styles.dart';
import '../../../notes/notes_page/screen/notes_page.dart';
import '../../../notes/notes_page/widgets/note_card.dart';
import '../../../tasks/todo_page/widgets/task_card.dart';
import 'profile_button.dart';

const _accent = Color(0xff3D5AFE);

/// A text size the profile page sets, and how to read and save it on the
/// [UserViewModel].
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

  /// Saves [size].
  Future<Result> apply(UserViewModel user, double size) => switch (this) {
        taskTitle => user.setTasksTitleSize(size),
        taskDescription => user.setTasksDescSize(size),
        noteTitle => user.setNotesTitleSize(size),
        noteBody => user.setNotesTextSize(size),
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
  );
}

/// A slider for one of the text sizes, over a preview of the text it sizes.
class TextSizeSheet extends StatefulWidget {
  const TextSizeSheet({super.key, required this.setting});

  final TextSizeSetting setting;

  @override
  State<TextSizeSheet> createState() => _TextSizeSheetState();
}

class _TextSizeSheetState extends State<TextSizeSheet> {
  /// The size being tried out. It's kept here rather than on the
  /// [UserViewModel], so that dragging the slider rebuilds only the sheet,
  /// and not the settings under it and every other page that listens to
  /// the user's.
  late double _size = widget.setting.saved(context.read<UserViewModel>());

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserViewModel>();
    final setting = widget.setting;
    final size = _size;
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
                      setState(() => _size = (value * 8).round() / 8),
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
                          size == 1 ? null : () => setState(() => _size = 1),
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
            onPressed: size == setting.saved(user) ? null : () => _apply(user),
          ),
        ],
      ),
    );
  }

  Future<void> _apply(UserViewModel user) async {
    final result = await widget.setting.apply(user, _size);
    if (result is Success && mounted) Navigator.pop(context);
    result.when(
      onSuccess: FeedbackToast.success,
      onFailure: FeedbackToast.error,
      onInfo: FeedbackToast.info,
    );
  }
}

/// A copy of where the text appears, drawn at the draft [size], with any
/// other text on it at its saved size.
class _Preview extends StatelessWidget {
  const _Preview(
      {required this.setting, required this.size, required this.user});

  final TextSizeSetting setting;
  final double size;
  final UserViewModel user;

  @override
  Widget build(BuildContext context) {
    final saved = user.user;
    final casualFont = saved.casual == 1;
    return switch (setting) {
      TextSizeSetting.taskTitle =>
        _TaskPreview(titleSize: size, descSize: saved.tasksDescSize),
      TextSizeSetting.taskDescription =>
        _TaskPreview(titleSize: saved.tasksTitleSize, descSize: size),
      TextSizeSetting.noteTitle =>
        _NoteCardPreview(titleSize: size, casualFont: casualFont),
      TextSizeSetting.noteBody =>
        _NoteBodyPreview(size: size, casualFont: casualFont),
    };
  }
}

/// The panel a preview is drawn on, in the page's colour.
class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({this.height = defaultHeight, required this.child});

  static const defaultHeight = 220.0;

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: context.colors.pageBackground,
        shape: const RoundedSuperellipseBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
      ),
      child: child,
    );
  }
}

/// A task card as the to-do page draws it.
class _TaskPreview extends StatefulWidget {
  const _TaskPreview({required this.titleSize, required this.descSize});

  final double titleSize;
  final double descSize;

  @override
  State<_TaskPreview> createState() => _TaskPreviewState();
}

class _TaskPreviewState extends State<_TaskPreview> {
  /// Whether the card is too tall to fit, so it's faded out at the bottom
  /// rather than cut off.
  bool _overflowing = false;

  @override
  Widget build(BuildContext context) {
    return _PreviewPanel(
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
        // The card sits in the middle while it fits.
        child: Align(
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
              child: TaskCard(
                task: _sampleTask,
                titleScale: widget.titleSize,
                descriptionScale: widget.descSize,
                descriptionLines: 0,
              ),
            ),
          ),
        ),
      ),
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

/// A note's card as the notes page draws it, and as big, so its title
/// breaks over lines just as it will there. The card fits it at any size.
class _NoteCardPreview extends StatelessWidget {
  const _NoteCardPreview({required this.titleSize, required this.casualFont});

  final double titleSize;
  final bool casualFont;

  @override
  Widget build(BuildContext context) {
    final cardSize = noteCardSize(context);
    return _PreviewPanel(
      // Taller than the other previews when the card needs it.
      height: math.max(_PreviewPanel.defaultHeight, cardSize.height + 32),
      child: Center(
        child: SizedBox.fromSize(
          size: cardSize,
          child: NoteCover(
            color: _accent,
            child: NoteCardContent(
              note: _sampleNote,
              titleSize: titleSize,
              casualFont: casualFont,
            ),
          ),
        ),
      ),
    );
  }
}

final _sampleNote = Note(
  title: "Weekend Plans",
  body: "Farmers market in the morning, then a long walk by the river.",
  titleColor: Colors.white.hex,
  coverColor: _accent.hex,
  protected: 0,
);

/// A note's text as the editor draws it, in as many whole lines as fit, so
/// that a large size never cuts a line off part way through.
class _NoteBodyPreview extends StatelessWidget {
  const _NoteBodyPreview({required this.size, required this.casualFont});

  final double size;
  final bool casualFont;

  @override
  Widget build(BuildContext context) {
    final style = noteBodyStyle(context, size: size, casualFont: casualFont);
    final lineHeight =
        MediaQuery.textScalerOf(context).scale(style.fontSize!) * style.height!;
    return _PreviewPanel(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          // At the top, like in the editor, and only as tall as its lines,
          // so the fade lands on the last one rather than the room below.
          builder: (context, constraints) => Align(
            alignment: Alignment.topLeft,
            child: Text(
              "Today I finally sorted out my notes. Everything has a place "
              "now, and it feels good.",
              maxLines:
                  math.max(1, (constraints.maxHeight / lineHeight).floor()),
              overflow: TextOverflow.fade,
              style: style,
            ),
          ),
        ),
      ),
    );
  }
}
