import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:toastification/toastification.dart';
import 'package:todo/core/result.dart';
import 'package:todo/core/theme/app_theme.dart';
import 'package:todo/view/widgets/form_dialog.dart';
import 'package:todo/view/widgets/profile_button.dart';
import 'package:todo/view/widgets/restore_backup_dialog.dart';

void main() {
  /// Lets [duration] go by a frame at a time, as it does on a phone, for the
  /// animations in it, a toast's too.
  Future<void> wait(
    WidgetTester tester, [
    Duration duration = const Duration(seconds: 1),
  ]) async {
    const frame = Duration(milliseconds: 50);
    for (var waited = Duration.zero; waited < duration; waited += frame) {
      await tester.pump(frame);
    }
  }

  /// Opens the dialog for [things], restoring them with [restore].
  Future<void> open(
    WidgetTester tester,
    String things,
    Future<Result?> Function(BuildContext context, bool overwrite) restore,
  ) async {
    await tester.pumpWidget(
      ToastificationWrapper(
        child: MaterialApp(
          theme: AppTheme.getTheme(isDarkMode: false),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showFormDialog<void>(
                  context,
                  RestoreBackupDialog(things: things, restore: restore),
                ),
                child: const Text("Open"),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text("Open"));
    await wait(tester);
  }

  ProfileButton importButton(WidgetTester tester) =>
      tester.widget(find.widgetWithText(ProfileButton, "Import"));

  testWidgets("Import starts one restore, and is off while it runs; then the "
      "dialog closes and says how it went", (tester) async {
    final asked = <bool>[];
    final restored = Completer<Result?>();
    await open(tester, "tasks", (context, overwrite) {
      asked.add(overwrite);
      return restored.future;
    });
    await tester.tap(find.text("Add to My Tasks"));
    await tester.pump();
    await tester.tap(find.text("Import"));
    await tester.pump();
    expect(importButton(tester).onPressed, isNull);
    await tester.tap(find.text("Import"), warnIfMissed: false);
    await tester.pump();
    expect(asked, [false]);

    restored.complete(const Success("Data Restored"));
    await wait(tester);
    expect(find.text("Restore Backup"), findsNothing);
    expect(find.text("Data Restored"), findsOneWidget);
    // Till the toast has gone.
    await wait(tester, const Duration(seconds: 5));
  });

  testWidgets("it speaks of what it restores, and replaces them unless the "
      "user picks adding to them", (tester) async {
    final asked = <bool>[];
    await open(tester, "notes", (context, overwrite) async {
      asked.add(overwrite);
      return null;
    });
    expect(find.text("Import notes from a backup file."), findsOneWidget);
    expect(find.text("Replace My Notes"), findsOneWidget);
    expect(find.text("Add to My Notes"), findsOneWidget);

    await tester.tap(find.text("Import"));
    await wait(tester);
    expect(asked, [true]);
    // Cancelled: closed, with nothing said.
    expect(find.text("Restore Backup"), findsNothing);
  });
}
