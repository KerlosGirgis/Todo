import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:todo/view/screens/profile/profile_page/widgets/font_button.dart';
import 'package:todo/view/screens/profile/profile_page/widgets/settings_button.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../../core/result.dart';
import '../../../../../core/ui/feedback_toast.dart';
import '../../../../../view_model/user_view_model.dart';
import '../../../../widgets/button.dart';

class SettingsPageView extends StatelessWidget {
  SettingsPageView({
    super.key,
  });

  final PageController _controller = PageController();

  @override
  Widget build(BuildContext context) {
    return Consumer<UserViewModel>(builder: (context, user, child) {
      return Column(
        children: [
          Expanded(
            child: PageView(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: MediaQuery.of(context).orientation ==
                              Orientation.portrait
                          ? MediaQuery.sizeOf(context).width / 30
                          : MediaQuery.sizeOf(context).width / 70),
                  child: Column(
                    spacing: MediaQuery.of(context).orientation ==
                            Orientation.portrait
                        ? MediaQuery.sizeOf(context).height / 70
                        : MediaQuery.sizeOf(context).height / 30,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Row(
                          spacing: MediaQuery.of(context).orientation ==
                                  Orientation.portrait
                              ? MediaQuery.sizeOf(context).width / 50
                              : MediaQuery.sizeOf(context).width / 80,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: SettingsButton(
                                onPressed: () {
                                  Provider.of<UserViewModel>(context,
                                          listen: false)
                                      .changeTheme();
                                },
                                label: "Dark\nMode",
                                status: user.user.theme == 1 ? true : false,
                                fontSize: 22,
                                size: 1.5,
                                icon: Icons.dark_mode,
                              ),
                            ),
                            Expanded(
                              child: SettingsButton(
                                  onPressed: () {
                                    Provider.of<UserViewModel>(context,
                                            listen: false)
                                        .changeCount();
                                  },
                                  label: "Word\nCount",
                                  status: user.user.count == 1 ? true : false,
                                  fontSize: 22,
                                  size: 1.5,
                                  icon: Icons.text_snippet_rounded),
                            ),
                            Expanded(
                              child: SettingsButton(
                                onPressed: () {
                                  Provider.of<UserViewModel>(context,
                                          listen: false)
                                      .changeAutoSave();
                                },
                                label: "Auto\nSave",
                                status: user.user.autoSave == 1 ? true : false,
                                fontSize: 22,
                                size: 1.5,
                                icon: Icons.save_rounded,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          spacing: MediaQuery.of(context).orientation ==
                                  Orientation.portrait
                              ? MediaQuery.sizeOf(context).width / 50
                              : MediaQuery.sizeOf(context).width / 80,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: SettingsButton(
                                onPressed: () {
                                  Provider.of<UserViewModel>(context,
                                          listen: false)
                                      .changeFont();
                                },
                                label: "Casual\nFont",
                                status: user.user.casual == 1 ? true : false,
                                fontSize: 22,
                                size: 1.5,
                                icon: Icons.font_download_rounded,
                              ),
                            ),
                            Expanded(
                              child: SettingsButton(
                                onPressed: () {
                                  Provider.of<UserViewModel>(context,
                                          listen: false)
                                      .changeVerse();
                                },
                                label: "Daily\nVerse",
                                status: user.user.verse == 1 ? true : false,
                                fontSize: 22,
                                size: 1.5,
                                icon: Icons.auto_stories_rounded,
                              ),
                            ),
                            Expanded(
                              child: SettingsButton(
                                  onPressed: () {
                                    Provider.of<UserViewModel>(context,
                                            listen: false)
                                        .changeLock()
                                        .then((result) {
                                      if (result is Success) {
                                        FeedbackToast.success(result.message);
                                      } else if (result is Failure) {
                                        FeedbackToast.error(result.message);
                                      } else if (result is Info) {
                                        FeedbackToast.info(result.message);
                                      }
                                    });
                                  },
                                  label: "App\nLock",
                                  status: user.isEnabled ? true : false,
                                  fontSize: 22,
                                  size: 1.5,
                                  icon: Icons.lock_rounded),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        "Start Page",
                        style: TextStyle(
                          fontSize: 26,
                          color: context.colors.wB,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Padding(padding: EdgeInsets.only(bottom: 10)),
                    Flexible(
                      child: SegmentedButton<int>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                            value: 0,
                            label: Text("Todo",
                                style: TextStyle(
                                  fontSize: 20,
                                )),
                            icon: Icon(Icons.checklist_sharp),
                          ),
                          ButtonSegment(
                            value: 1,
                            label: Text("Notes",
                                style: TextStyle(
                                  fontSize: 20,
                                )),
                            icon: Icon(Icons.edit_note_sharp),
                          )
                        ],
                        selected: {user.user.startPage},
                        emptySelectionAllowed: false,
                        onSelectionChanged: (v) =>
                            user.changeStartPage(v.first),
                        style: ButtonStyle(
                          shape: WidgetStateProperty.all(
                            RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          side: WidgetStateProperty.resolveWith((states) {
                            return BorderSide(
                              color: context.colors.wB.withValues(alpha: 0.35),
                            );
                          }),
                          backgroundColor:
                              WidgetStateProperty.resolveWith((states) {
                            return states.contains(WidgetState.selected)
                                ? context.colors.wB.withValues(alpha: 0.18)
                                : Colors.transparent;
                          }),
                          foregroundColor:
                              WidgetStateProperty.resolveWith((states) {
                            return states.contains(WidgetState.selected)
                                ? context.colors.wB
                                : context.colors.wB.withValues(alpha: 0.8);
                          }),
                        ),
                      ),
                    ),
                    Padding(padding: EdgeInsets.only(bottom: 10)),
                    Flexible(
                      child: Text(
                        "Task description lines limit",
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 26,
                          color: context.colors.wB,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Padding(padding: EdgeInsets.only(bottom: 10)),
                    Flexible(
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width / 1.05,
                        child: SegmentedButton<int>(
                          showSelectedIcon: false,
                          segments: [
                            ButtonSegment(
                              value: 0,
                              label: Text(
                                "Off",
                                style: TextStyle(
                                  fontSize: 20,
                                ),
                              ),
                            ),
                            ButtonSegment(
                              value: 1,
                              label: Text("1",
                                  style: TextStyle(
                                    fontSize: 20,
                                  )),
                            ),
                            ButtonSegment(
                              value: 2,
                              label: Text("2",
                                  style: TextStyle(
                                    fontSize: 20,
                                  )),
                            ),
                            ButtonSegment(
                              value: 3,
                              label: Text("3",
                                  style: TextStyle(
                                    fontSize: 20,
                                  )),
                            ),
                            ButtonSegment(
                              value: 4,
                              label: Text("4",
                                  style: TextStyle(
                                    fontSize: 20,
                                  )),
                            ),
                            ButtonSegment(
                              value: 5,
                              label: Text("5",
                                  style: TextStyle(
                                    fontSize: 20,
                                  )),
                            ),
                          ],
                          selected: {user.user.descLines},
                          emptySelectionAllowed: false,
                          onSelectionChanged: (v) => user.setDescLines(v.first),
                          style: ButtonStyle(
                            shape: WidgetStateProperty.all(
                              RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            side: WidgetStateProperty.resolveWith((states) {
                              return BorderSide(
                                color:
                                    context.colors.wB.withValues(alpha: 0.35),
                              );
                            }),
                            backgroundColor:
                                WidgetStateProperty.resolveWith((states) {
                              return states.contains(WidgetState.selected)
                                  ? context.colors.wB.withValues(alpha: 0.18)
                                  : Colors.transparent;
                            }),
                            foregroundColor:
                                WidgetStateProperty.resolveWith((states) {
                              return states.contains(WidgetState.selected)
                                  ? context.colors.wB
                                  : context.colors.wB.withValues(alpha: 0.8);
                            }),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: MediaQuery.of(context).orientation ==
                              Orientation.portrait
                          ? MediaQuery.sizeOf(context).width / 30
                          : MediaQuery.sizeOf(context).width / 70),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: MediaQuery.of(context).orientation ==
                            Orientation.portrait
                        ? MediaQuery.sizeOf(context).height / 70
                        : MediaQuery.sizeOf(context).height / 30,
                    children: [
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.format_size_rounded,
                                color: context.colors.wB, size: 32),
                            Padding(padding: EdgeInsets.only(right: 10)),
                            AutoSizeText(
                              "Font Sizes",
                              minFontSize: 10,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: context.colors.wB,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Row(
                          spacing: MediaQuery.widthOf(context) / 30,
                          children: [
                            Expanded(
                              child: FontButton(
                                onPressed: () {
                                  showModalBottomSheet(
                                      context: context,
                                      backgroundColor:
                                          context.colors.cardBackground,
                                      isScrollControlled: true,
                                      useSafeArea: true,
                                      builder: (BuildContext context) {
                                        return Consumer<UserViewModel>(
                                            builder: (context, user, child) {
                                          return Padding(
                                            padding: EdgeInsets.symmetric(
                                                vertical: 30),
                                            child: SingleChildScrollView(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    "A",
                                                    style: TextStyle(
                                                      color: context.colors.wB,
                                                      fontSize: 26 *
                                                          user.tempTasksTitleSize,
                                                    ),
                                                  ),
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Expanded(
                                                        flex: 9,
                                                        child: Slider(
                                                          activeColor:
                                                              const Color(
                                                                  0xff3D5AFE),
                                                          value: user
                                                              .tempTasksTitleSize,
                                                          min: .25,
                                                          max: 2,
                                                          divisions: 14,
                                                          onChanged: (v) {
                                                            user.setTempTasksTitleSize(
                                                                v);
                                                          },
                                                        ),
                                                      ),
                                                      Padding(
                                                          padding:
                                                              EdgeInsets.only(
                                                                  right: 5)),
                                                      Expanded(
                                                          flex: 1,
                                                          child: Text(
                                                            maxLines: 1,
                                                            user.tempTasksTitleSize
                                                                .toString(),
                                                            style: TextStyle(
                                                                fontSize: 24,
                                                                color: context
                                                                    .colors.wB),
                                                          ))
                                                    ],
                                                  ),
                                                  Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Flexible(
                                                          child: Button(
                                                            onPressed: () {
                                                              user
                                                                  .setTasksTitleSize()
                                                                  .then(
                                                                      (result) {
                                                                if (result
                                                                    is Success) {
                                                                  if (context
                                                                      .mounted) {
                                                                    Navigator.pop(
                                                                        context);
                                                                  }
                                                                  FeedbackToast
                                                                      .success(
                                                                          result
                                                                              .message);
                                                                } else if (result
                                                                    is Failure) {
                                                                  FeedbackToast
                                                                      .error(result
                                                                          .message);
                                                                } else if (result
                                                                    is Info) {
                                                                  FeedbackToast
                                                                      .info(result
                                                                          .message);
                                                                }
                                                              });
                                                            },
                                                            label: 'Apply',
                                                            status: user
                                                                    .tempTasksTitleSize !=
                                                                user.user
                                                                    .tasksTitleSize,
                                                            fontSize: 22,
                                                            size: 1,
                                                          ),
                                                        )
                                                      ])
                                                ],
                                              ),
                                            ),
                                          );
                                        });
                                      }).then(
                                    (value) {
                                      user.setTempTasksTitleSize(
                                          user.user.tasksTitleSize);
                                    },
                                  );
                                },
                                label: "Task Title",
                                fontSize: 22,
                                size: 1.5,
                              ),
                            ),
                            Expanded(
                              child: FontButton(
                                onPressed: () {
                                  showModalBottomSheet(
                                      context: context,
                                      backgroundColor:
                                          context.colors.cardBackground,
                                      isScrollControlled: true,
                                      useSafeArea: true,
                                      builder: (BuildContext context) {
                                        return Consumer<UserViewModel>(
                                            builder: (context, user, child) {
                                          return Padding(
                                            padding: EdgeInsets.symmetric(
                                                vertical: 30),
                                            child: SingleChildScrollView(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    "A",
                                                    style: TextStyle(
                                                      color: context.colors.wB,
                                                      fontSize: 20 *
                                                          user.tempTasksDescSize,
                                                    ),
                                                  ),
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Expanded(
                                                        flex: 9,
                                                        child: Slider(
                                                          activeColor:
                                                              const Color(
                                                                  0xff3D5AFE),
                                                          value: user
                                                              .tempTasksDescSize,
                                                          min: .25,
                                                          max: 2,
                                                          divisions: 14,
                                                          onChanged: (v) {
                                                            user.setTempTasksDescSize(
                                                                v);
                                                          },
                                                        ),
                                                      ),
                                                      Padding(
                                                          padding:
                                                              EdgeInsets.only(
                                                                  right: 5)),
                                                      Expanded(
                                                          flex: 1,
                                                          child: Text(
                                                            maxLines: 1,
                                                            user.tempTasksDescSize
                                                                .toString(),
                                                            style: TextStyle(
                                                                fontSize: 24,
                                                                color: context
                                                                    .colors.wB),
                                                          ))
                                                    ],
                                                  ),
                                                  Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Flexible(
                                                          child: Button(
                                                            onPressed: () {
                                                              user
                                                                  .setTasksDescSize()
                                                                  .then(
                                                                      (result) {
                                                                if (result
                                                                    is Success) {
                                                                  if (context
                                                                      .mounted) {
                                                                    Navigator.pop(
                                                                        context);
                                                                  }
                                                                  FeedbackToast
                                                                      .success(
                                                                          result
                                                                              .message);
                                                                } else if (result
                                                                    is Failure) {
                                                                  FeedbackToast
                                                                      .error(result
                                                                          .message);
                                                                } else if (result
                                                                    is Info) {
                                                                  FeedbackToast
                                                                      .info(result
                                                                          .message);
                                                                }
                                                              });
                                                            },
                                                            label: 'Apply',
                                                            status: user
                                                                    .tempTasksDescSize !=
                                                                user.user
                                                                    .tasksDescSize,
                                                            fontSize: 22,
                                                            size: 1,
                                                          ),
                                                        )
                                                      ])
                                                ],
                                              ),
                                            ),
                                          );
                                        });
                                      }).then(
                                    (value) {
                                      user.setTempTasksTitleSize(
                                          user.user.tasksTitleSize);
                                    },
                                  );
                                },
                                label: "Task\nDescription",
                                fontSize: 22,
                                size: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Row(
                          spacing: MediaQuery.widthOf(context) / 30,
                          children: [
                            Expanded(
                              child: FontButton(
                                onPressed: () {
                                  showModalBottomSheet(
                                      context: context,
                                      backgroundColor:
                                          context.colors.cardBackground,
                                      isScrollControlled: true,
                                      useSafeArea: true,
                                      builder: (BuildContext context) {
                                        return Consumer<UserViewModel>(
                                            builder: (context, user, child) {
                                          return Padding(
                                            padding: EdgeInsets.symmetric(
                                                vertical: 30),
                                            child: SingleChildScrollView(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    "A",
                                                    style: TextStyle(
                                                      color: context.colors.wB,
                                                      fontSize: 24 *
                                                          user.tempNotesTitleSize,
                                                    ),
                                                  ),
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Expanded(
                                                        flex: 9,
                                                        child: Slider(
                                                          activeColor:
                                                              const Color(
                                                                  0xff3D5AFE),
                                                          value: user
                                                              .tempNotesTitleSize,
                                                          min: .25,
                                                          max: 2,
                                                          divisions: 14,
                                                          onChanged: (v) {
                                                            user.setTempNotesTitleSize(
                                                                v);
                                                          },
                                                        ),
                                                      ),
                                                      Padding(
                                                          padding:
                                                              EdgeInsets.only(
                                                                  right: 5)),
                                                      Expanded(
                                                          flex: 1,
                                                          child: Text(
                                                            maxLines: 1,
                                                            user.tempNotesTitleSize
                                                                .toString(),
                                                            style: TextStyle(
                                                                fontSize: 24,
                                                                color: context
                                                                    .colors.wB),
                                                          ))
                                                    ],
                                                  ),
                                                  Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Flexible(
                                                          child: Button(
                                                            onPressed: () {
                                                              user
                                                                  .setNotesTitleSize()
                                                                  .then(
                                                                      (result) {
                                                                if (result
                                                                    is Success) {
                                                                  if (context
                                                                      .mounted) {
                                                                    Navigator.pop(
                                                                        context);
                                                                  }
                                                                  FeedbackToast
                                                                      .success(
                                                                          result
                                                                              .message);
                                                                } else if (result
                                                                    is Failure) {
                                                                  FeedbackToast
                                                                      .error(result
                                                                          .message);
                                                                } else if (result
                                                                    is Info) {
                                                                  FeedbackToast
                                                                      .info(result
                                                                          .message);
                                                                }
                                                              });
                                                            },
                                                            label: 'Apply',
                                                            status: user
                                                                    .tempNotesTitleSize !=
                                                                user.user
                                                                    .notesTitleSize,
                                                            fontSize: 22,
                                                            size: 1,
                                                          ),
                                                        )
                                                      ])
                                                ],
                                              ),
                                            ),
                                          );
                                        });
                                      }).then(
                                    (value) {
                                      user.setTempNotesTitleSize(
                                          user.user.notesTitleSize);
                                    },
                                  );
                                },
                                label: "Note Title",
                                fontSize: 22,
                                size: 1.5,
                              ),
                            ),
                            Expanded(
                              child: FontButton(
                                onPressed: () {
                                  showModalBottomSheet(
                                      context: context,
                                      backgroundColor:
                                          context.colors.cardBackground,
                                      isScrollControlled: true,
                                      useSafeArea: true,
                                      builder: (BuildContext context) {
                                        return Consumer<UserViewModel>(
                                            builder: (context, user, child) {
                                          return Padding(
                                            padding: EdgeInsets.symmetric(
                                                vertical: 30),
                                            child: SingleChildScrollView(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    "A",
                                                    style: TextStyle(
                                                      color: context.colors.wB,
                                                      fontSize: 26 *
                                                          user.tempNotesTextSize,
                                                    ),
                                                  ),
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Expanded(
                                                        flex: 9,
                                                        child: Slider(
                                                          activeColor:
                                                              const Color(
                                                                  0xff3D5AFE),
                                                          value: user
                                                              .tempNotesTextSize,
                                                          min: .25,
                                                          max: 2,
                                                          divisions: 14,
                                                          onChanged: (v) {
                                                            user.setTempNotesSize(
                                                                v);
                                                          },
                                                        ),
                                                      ),
                                                      Padding(
                                                          padding:
                                                              EdgeInsets.only(
                                                                  right: 5)),
                                                      Expanded(
                                                          flex: 1,
                                                          child: Text(
                                                            maxLines: 1,
                                                            user.tempNotesTextSize
                                                                .toString(),
                                                            style: TextStyle(
                                                                fontSize: 24,
                                                                color: context
                                                                    .colors.wB),
                                                          ))
                                                    ],
                                                  ),
                                                  Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Flexible(
                                                          child: Button(
                                                            onPressed: () {
                                                              user
                                                                  .setNotesTextSize()
                                                                  .then(
                                                                      (result) {
                                                                if (result
                                                                    is Success) {
                                                                  if (context
                                                                      .mounted) {
                                                                    Navigator.pop(
                                                                        context);
                                                                  }
                                                                  FeedbackToast
                                                                      .success(
                                                                          result
                                                                              .message);
                                                                } else if (result
                                                                    is Failure) {
                                                                  FeedbackToast
                                                                      .error(result
                                                                          .message);
                                                                } else if (result
                                                                    is Info) {
                                                                  FeedbackToast
                                                                      .info(result
                                                                          .message);
                                                                }
                                                              });
                                                            },
                                                            label: 'Apply',
                                                            status: user
                                                                    .tempNotesTextSize !=
                                                                user.user
                                                                    .notesTextSize,
                                                            fontSize: 22,
                                                            size: 1,
                                                          ),
                                                        )
                                                      ])
                                                ],
                                              ),
                                            ),
                                          );
                                        });
                                      }).then(
                                    (value) {
                                      user.setTempNotesSize(
                                          user.user.notesTextSize);
                                    },
                                  );
                                },
                                label: "Note Body",
                                fontSize: 22,
                                size: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
          Padding(padding: EdgeInsets.only(bottom: 8)),
          SmoothPageIndicator(
            controller: _controller,
            count: 3,
            effect: SlideEffect(
              activeDotColor: Color(0xff3D5AFE),
              dotColor: context.colors.wB.withValues(alpha: 0.35),
            ),
          ),
        ],
      );
    });
  }
}
