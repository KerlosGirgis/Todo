import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../view_model/tasks_view_model.dart';

/// Starts the daily tasks over when the app comes back on a new day,
/// whichever page it's on: the to-do page, the notes, or one over them. The
/// timer that does it at midnight can go off late once the phone has slept,
/// so it's checked again as the app comes back. For the whole app, as the
/// App Lock's watch on it going away and coming back is: see AppLockGuard.
class NewDayWatcher extends StatefulWidget {
  const NewDayWatcher({super.key, required this.child});

  final Widget child;

  @override
  State<NewDayWatcher> createState() => _NewDayWatcherState();
}

class _NewDayWatcherState extends State<NewDayWatcher> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: context.read<TasksViewModel>().checkForNewDay,
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
