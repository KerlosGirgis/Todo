import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:todo/core/result.dart';
import 'package:todo/models/clock_time.dart';
import 'package:todo/models/todo_item.dart';
import 'package:todo/view/widgets/new_day_watcher.dart';
import 'package:todo/view_model/tasks_view_model.dart';

import '../view_model/tasks_view_model_test.dart'
    show FakeLock, FakeNotifications, FakeTasksRepository;

void main() {
  /// Tells the app it's gone to [state], as the phone does, which goes
  /// through the states between on its way there.
  Future<void> goTo(WidgetTester tester, AppLifecycleState state) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.lifecycle.name,
      SystemChannels.lifecycle.codec.encodeMessage(state.toString()),
      (_) {},
    );
    await tester.pump();
  }

  testWidgets("the daily tasks start over as the app comes back on a new "
      "day, whatever page it's on, without waiting for the midnight timer", (
    tester,
  ) async {
    var time = DateTime(2026, 5, 13, 23, 30);
    final tasks = TasksViewModel(
      repository: FakeTasksRepository(),
      notificationService: FakeNotifications(),
      lockService: FakeLock(),
      clock: () => time,
    );
    final draft = tasks.draft()
      ..setTitle("Stretch")
      ..setTime(const ClockTime(7, 0))
      ..setReminder(Reminder.daily);
    await tasks.save(draft);
    final done = await tasks.toggleDone(tasks.items.single);
    expect((done as Success).message, "Done for Today");

    // Any page will do: no to-do page is open.
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: tasks,
        child: const NewDayWatcher(child: SizedBox()),
      ),
    );
    await goTo(tester, AppLifecycleState.paused);
    // The phone sleeps through midnight, and the timer that would start the
    // day over hasn't gone off yet.
    time = DateTime(2026, 5, 14, 8);
    expect(tasks.today, DateTime(2026, 5, 13));
    expect(tasks.items.single.done, isTrue);

    await goTo(tester, AppLifecycleState.resumed);
    expect(tasks.today, DateTime(2026, 5, 14));
    expect(tasks.items.single.done, isFalse);

    await tester.pumpWidget(const SizedBox());
    tasks.dispose();
  });
}
