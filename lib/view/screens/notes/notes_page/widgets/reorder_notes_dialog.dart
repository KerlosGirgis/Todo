import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:provider/provider.dart';
import 'package:todo/view_model/notes_view_model.dart';

import '../../../../../core/extensions/theme_extensions.dart';

class ReorderNotesDialog extends StatelessWidget {
  const ReorderNotesDialog({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (BuildContext context, setState) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 2,
          scrollable: true,
          backgroundColor: context.colors.pageBackground,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.colors.dialogIconContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.reorder,
                    color: context.colors.dialogIcon,
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: Text(
                  "Reorder",
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 32,
                      color: context.colors.wB),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                child: IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: Icon(
                    Icons.close,
                    color: context.colors.dialogExitIcon,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.dialogExitContainer,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                  ),
                ),
              )
            ],
          ),
          content: Consumer<NotesViewModel>(
            builder: (context, notes, child) {
              return notes.notes.isEmpty
                  ? Center(
                      child: Text(
                        "Empty",
                        style: TextStyle(
                            color: context.colors.wB, fontSize: 22),
                      ),
                    )
                  : Theme(
                      data: Theme.of(context).copyWith(
                        canvasColor: Colors.transparent,
                      ),
                      child: SizedBox(
                        height: notes.notes.length < 4 &&
                                MediaQuery.orientationOf(context) ==
                                    Orientation.portrait
                            ? (MediaQuery.sizeOf(context).height / 11) *
                                notes.notes.length
                            : MediaQuery.sizeOf(context).height / 2.8,
                        width: MediaQuery.sizeOf(context).width,
                        child: ReorderableListView.builder(
                          itemCount: notes.notes.length,
                          itemBuilder: (context, index) {
                            final taskKey =
                                notes.notes[index].id.toString();
                            return AnimationLimiter(
                              key: Key(taskKey),
                              child: AnimationConfiguration.staggeredList(
                                duration: const Duration(milliseconds: 400),
                                position: index,
                                child: SlideAnimation(
                                  verticalOffset: 300,
                                  child: FadeInAnimation(
                                    child: Card(
                                      elevation: 3,
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 6),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(25),
                                      ),
                                      color: context.colors.cardBackground,
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                      notes.notes[index]
                                                          .title,
                                                      maxLines: 1,
                                                      overflow: TextOverflow
                                                          .ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 26,
                                                        color: context
                                                            .colors.wB,
                                                      )),
                                                ),
                                                Icon(
                                                  Icons.reorder,
                                                  color: Colors.grey,
                                                )
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                          onReorderItem: (int oldIndex, int newIndex) async {
                            await Provider.of<NotesViewModel>(context,
                                    listen: false)
                                .syncAfterReorder(oldIndex, newIndex);
                          },
                        ),
                      ),
                    );
            },
          ),
        );
      },
    );
  }
}
