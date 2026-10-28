import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../../../models/note.dart';
import '../../../../../models/note_preview.dart';
import '../../../../../view_model/user_view_model.dart';
import '../../../../widgets/tour.dart';
import '../screen/notes_page.dart';
import 'note_card.dart';

/// The notes page's tour: how a note's card works, acted out on a copy of
/// [note], the first card, whose key is [card], with its [preview], or, with
/// no notes, on an example where the first card would be, [gap] under
/// [header]; then what the [search] field, when there is one, the page's
/// [buttons] and its [menu] are for.
List<TourStep> notesTour({
  required Note? note,
  required NotePreview? preview,
  required GlobalKey card,
  required GlobalKey header,
  required double gap,
  required GlobalKey? search,
  required GlobalKey buttons,
  required GlobalKey menu,
}) {
  final target = note == null ? header : card;
  final place = note == null
      ? (BuildContext context, Rect header) => Rect.fromLTWH(
          header.left, header.bottom + gap, noteCardSize(context).width, 0)
      : null;

  TourDemo demo(List<TourGesture> gestures) => TourDemo(
        gestures: gestures,
        place: place,
        pressedScale: 0.97,
        builder: (context, pose) => note == null
            ? const _TourNoteCard(note: _example, preview: _examplePreview)
            : _TourNoteCard(note: note, preview: preview),
      );

  return [
    TourStep(
      target: target,
      icon: Icons.edit_note_rounded,
      title: "Open a Note",
      message: "Tap a note to read it or write in it. To delete it, use the "
          "menu inside.",
      demo: demo([TourGesture.tap]),
    ),
    TourStep(
      target: target,
      icon: Icons.palette_rounded,
      title: "Make It Yours",
      message: "Press and hold a note to rename it, change its colors or "
          "lock it.",
      demo: demo([TourGesture.hold]),
    ),
    if (search != null)
      TourStep(
        target: search,
        icon: Icons.search_rounded,
        title: "Search",
        message: "Find a note by its title or by what it says.",
        radius: 12,
      ),
    TourStep(
      target: buttons,
      icon: Icons.add_rounded,
      title: "Write a Note",
      message: "Tap + to start a new note. The button above it switches to "
          "your to-do list.",
      radius: 20,
      padding: 8,
    ),
    TourStep(
      target: menu,
      icon: Icons.menu_rounded,
      title: "More Options",
      message: "Reorder your notes, back them up, restore a backup or open "
          "Settings from this menu.",
      radius: 19,
    ),
  ];
}

/// A note to show the cards' gestures on when there are none.
const _example = Note(
  title: "Weekend Trip",
  titleColor: 0xFFFFFFFF,
  coverColor: 0xFF5856D6,
);

const _examplePreview = NotePreview(
  lines: [
    NotePreviewLine(runs: [NotePreviewRun("Leave by ten on Saturday.")]),
    NotePreviewLine(
        runs: [NotePreviewRun("Passport")], list: NoteListKind.checked),
    NotePreviewLine(
        runs: [NotePreviewRun("Chargers")], list: NoteListKind.checked),
    NotePreviewLine(
        runs: [NotePreviewRun("Sunscreen")], list: NoteListKind.unchecked),
  ],
  checked: 2,
  unchecked: 1,
);

/// A copy of [note]'s card, as big as the grid's, at the user's title size
/// and in their font.
class _TourNoteCard extends StatelessWidget {
  const _TourNoteCard({required this.note, required this.preview});

  final Note note;
  final NotePreview? preview;

  @override
  Widget build(BuildContext context) {
    final titleSize = context
        .select<UserViewModel, double>((user) => user.user.notesTitleSize);
    final casualFont =
        context.select<UserViewModel, bool>((user) => user.user.casualFont);
    return SizedBox(
      height: noteCardSize(context).height,
      child: NoteCover(
        color: Color(note.coverColor),
        child: NoteCardContent(
          note: note,
          preview: preview,
          titleSize: titleSize,
          casualFont: casualFont,
        ),
      ),
    );
  }
}
