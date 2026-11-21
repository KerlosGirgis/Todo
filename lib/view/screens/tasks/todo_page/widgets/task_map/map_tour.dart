import 'package:material_ui/material_ui.dart';

import '../../../../../widgets/tour.dart';
import 'map_layout.dart';

/// The map's tour: what the map is, around its centre, whose key is [hub];
/// how a task on it works, on the first one, [node], when there is one;
/// then what the [fit], [fullScreen] and [sortFilter] buttons are for, and
/// that the switch back to the list is in the [menu].
List<TourStep> mapTour({
  required GlobalKey hub,
  required GlobalKey node,
  required GlobalKey fit,
  required GlobalKey fullScreen,
  required GlobalKey sortFilter,
  required GlobalKey menu,
}) {
  return [
    TourStep(
      target: hub,
      icon: Icons.hub_rounded,
      title: "Your Tasks as a Map",
      message:
          "Tasks branch off the centre, and their subtasks branch off "
          "them. Drag the map to move around it, and pinch to zoom.",
      radius: MapLayout.hubRadius + 8,
      padding: 8,
    ),
    TourStep(
      target: node,
      icon: Icons.touch_app_rounded,
      title: "Work on a Task",
      message:
          "Tap a task's circle to check it off. Tap the task itself "
          "for buttons that add a subtask to it, edit it, set its reminder "
          "or delete it.",
      radius: 16,
      padding: 8,
    ),
    TourStep(
      target: node,
      icon: Icons.open_with_rounded,
      title: "Move a Task",
      message:
          "Press and hold a task, then drop it on another to put it "
          "inside, or just above or below one to put it next to it. Its "
          "subtasks go with it.",
      radius: 16,
      padding: 8,
    ),
    TourStep(
      target: fit,
      icon: Icons.fit_screen_rounded,
      title: "See It All",
      message: "Lost your place? This brings the whole map back into view.",
      radius: 19,
    ),
    TourStep(
      target: fullScreen,
      icon: Icons.open_in_full_rounded,
      title: "Go Full Screen",
      message:
          "Need more room? This gives the map the whole screen. Tap it "
          "again, or go back, to leave full screen.",
      radius: 19,
    ),
    TourStep(
      target: sortFilter,
      icon: Icons.filter_alt_rounded,
      title: "Sort and Filter",
      message:
          "Pick which tasks the map shows, such as just the undone or "
          "the weekly ones, and sort them by due date. The list goes by "
          "the same choices.",
      radius: 19,
    ),
    TourStep(
      target: menu,
      icon: Icons.view_agenda_rounded,
      title: "Back to the List",
      message:
          "Switch between the map and the list from this menu. They "
          "show the same tasks.",
      radius: 19,
    ),
  ];
}
