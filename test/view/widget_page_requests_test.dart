import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:todo/models/user_profile.dart';
import 'package:todo/models/widget_style.dart';
import 'package:todo/view/widgets/widget_page_requests.dart';
import 'package:todo/view_model/auth_view_model.dart';
import 'package:todo/view_model/user_view_model.dart';
import 'package:todo/view_model/widgets_view_model.dart';

import '../view_model/tasks_view_model_test.dart' show FakeLock;
import '../view_model/user_view_model_test.dart'
    show FakeDatabase, FakeDevice, FakeUserRepository;
import '../view_model/widgets_view_model_test.dart' show FakeWidgets;

/// An App Lock that's locked or not as a test says.
class FakeAuth extends AuthViewModel {
  FakeAuth(super.user, {super.lockService});

  AuthStatus _status = AuthStatus.authenticated;

  @override
  AuthStatus get status => _status;

  set status(AuthStatus status) {
    _status = status;
    notifyListeners();
  }
}

/// The to-do page, as far as taps on the widgets go.
class _TodoPage extends StatefulWidget {
  const _TodoPage({required this.opened});

  final List<String> opened;

  @override
  State<_TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<_TodoPage>
    with WidgetPageRequests<_TodoPage> {
  @override
  StartPage get widgetPage => StartPage.tasks;

  @override
  void openOtherPage() => widget.opened.add("notes");

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => const AlertDialog(title: Text("Edit Task")),
            ),
            child: const Text("Open a dialog"),
          ),
        ),
      );
}

void main() {
  late FakeWidgets phone;
  late WidgetsViewModel widgets;
  late FakeAuth auth;
  late List<String> opened;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    opened = [];
  });

  tearDown(() => widgets.dispose());

  /// Shows the page, with the view models made in the test's own zone, as
  /// a stream's events go by the zone it was listened to in.
  Future<void> showPage(WidgetTester tester) {
    phone = FakeWidgets();
    widgets = WidgetsViewModel(service: phone);
    final lock = FakeLock();
    auth = FakeAuth(
      UserViewModel(
        repository: FakeUserRepository(),
        lockService: lock,
        deviceService: FakeDevice(),
        databaseService: FakeDatabase(),
      ),
      lockService: lock,
    );
    return tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthViewModel>.value(value: auth),
          ChangeNotifierProvider.value(value: widgets),
        ],
        child: MaterialApp(home: _TodoPage(opened: opened)),
      ),
    );
  }

  Future<void> tap(WidgetTester tester, WidgetKind kind) async {
    phone.tapped.add(kind);
    await tester.pumpAndSettle();
  }

  testWidgets("a tap on the other page's widget goes over to it",
      (tester) async {
    await showPage(tester);
    await tap(tester, WidgetKind.tasks);
    expect(opened, isEmpty);
    await tap(tester, WidgetKind.note);
    expect(opened, ["notes"]);
  });

  testWidgets("not from under a dialog the user is in the middle of",
      (tester) async {
    await showPage(tester);
    await tester.tap(find.text("Open a dialog"));
    await tester.pumpAndSettle();
    await tap(tester, WidgetKind.note);
    expect(opened, isEmpty);
    // Nor later, once it's closed.
    Navigator.of(tester.element(find.text("Edit Task"))).pop();
    await tester.pumpAndSettle();
    expect(opened, isEmpty);
  });

  testWidgets("while the app is locked, once it's unlocked", (tester) async {
    await showPage(tester);
    auth.status = AuthStatus.unauthenticated;
    await tap(tester, WidgetKind.note);
    expect(opened, isEmpty);
    auth.status = AuthStatus.authenticated;
    await tester.pumpAndSettle();
    expect(opened, ["notes"]);
    // Only the once.
    auth.status = AuthStatus.unauthenticated;
    auth.status = AuthStatus.authenticated;
    await tester.pumpAndSettle();
    expect(opened, ["notes"]);
  });

  testWidgets(
      "a tap on its own widget while it's locked asks for nothing "
      "more", (tester) async {
    await showPage(tester);
    auth.status = AuthStatus.unauthenticated;
    await tap(tester, WidgetKind.note);
    await tap(tester, WidgetKind.tasks);
    auth.status = AuthStatus.authenticated;
    await tester.pumpAndSettle();
    expect(opened, isEmpty);
  });
}
