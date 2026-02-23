import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:todo/view/screens/profile/widgets/settings_button.dart';

import '../../../../view_model/user_view_model.dart';
import '../../../widgets/button.dart';

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
                                  icon: Icons.text_snippet_rounded
                              ),
                            ),
                            Expanded(
                              child: SettingsButton(
                                  onPressed: () {
                                    Provider.of<UserViewModel>(context,
                                            listen: false)
                                        .changeAutoSave();
                                  },
                                  label: "Auto\nSave",
                                  status:
                                      user.user.autoSave == 1 ? true : false,
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
                                        .changeLock();
                                  },
                                  label: "App\nLock",
                                  status: user.isEnabled ? true : false,
                                  fontSize: 22,
                                  size: 1.5,
                                  icon: Icons.lock_rounded
                              ),
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
                          color: user.colorManager.wB,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Padding(padding: EdgeInsets.only(bottom: 10)),
                    Flexible(
                      child: SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(
                            value: 0,
                            label: Text("Todo"),
                            icon: Icon(Icons.checklist_sharp),
                          ),
                          ButtonSegment(
                            value: 1,
                            label: Text("Notes"),
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
                              color:
                                  user.colorManager.wB!.withValues(alpha: 0.35),
                            );
                          }),
                          backgroundColor:
                              WidgetStateProperty.resolveWith((states) {
                            return states.contains(WidgetState.selected)
                                ? user.colorManager.wB!.withValues(alpha: 0.18)
                                : Colors.transparent;
                          }),
                          foregroundColor:
                              WidgetStateProperty.resolveWith((states) {
                            return states.contains(WidgetState.selected)
                                ? user.colorManager.wB
                                : user.colorManager.wB!.withValues(alpha: 0.8);
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
                          color: user.colorManager.wB,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Padding(padding: EdgeInsets.only(bottom: 10)),
                    Flexible(
                      child: SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(
                            value: 0,
                            label: Text("off"),
                          ),
                          ButtonSegment(
                            value: 1,
                            label: Text("1"),
                          ),
                          ButtonSegment(
                            value: 2,
                            label: Text("2"),
                          ),
                          ButtonSegment(
                            value: 3,
                            label: Text("3"),
                          ),
                          ButtonSegment(
                            value: 4,
                            label: Text("4"),
                          ),
                          ButtonSegment(
                            value: 5,
                            label: Text("5"),
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
                                  user.colorManager.wB!.withValues(alpha: 0.35),
                            );
                          }),
                          backgroundColor:
                              WidgetStateProperty.resolveWith((states) {
                            return states.contains(WidgetState.selected)
                                ? user.colorManager.wB!.withValues(alpha: 0.18)
                                : Colors.transparent;
                          }),
                          foregroundColor:
                              WidgetStateProperty.resolveWith((states) {
                            return states.contains(WidgetState.selected)
                                ? user.colorManager.wB
                                : user.colorManager.wB!.withValues(alpha: 0.8);
                          }),
                        ),
                      ),
                    ),
                  ],
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    AutoSizeText(
                      "Notes Font Size",
                      minFontSize: 10,
                      style: TextStyle(
                          overflow: TextOverflow.ellipsis,
                          fontSize: 28,
                          color: user.colorManager.wB),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          flex: 10,
                          child: Slider(
                              activeColor: const Color(0xff3D5AFE),
                              value: user.tempNotesTextSize,
                              min: .25,
                              max: 2,
                              onChanged: (v) {
                                user.setTempNotesSize(v);
                              }),
                        ),
                        Expanded(
                            flex: 1,
                            child: Text(
                              maxLines: 1,
                              user.tempNotesTextSize.toStringAsPrecision(2),
                              style: TextStyle(
                                  fontSize: 22, color: user.colorManager.wB),
                            ))
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Button(
                            onPressed: () {
                              user.setNotesTextSize();
                            },
                            label: "Apply",
                            status: double.parse(user.tempNotesTextSize
                                    .toStringAsPrecision(2)) !=
                                user.user.notesTextSize,
                            fontSize: 24,
                            size: 1)
                      ],
                    )
                  ],
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
              dotColor: user.colorManager.wB!.withValues(alpha: 0.35),
            ),
          ),
        ],
      );
    });
  }
}
