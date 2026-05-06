/*
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <https://www.gnu.org/licenses/>.
 */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';
import 'package:todo/services/notification_service.dart';
import 'package:todo/view/screens/profile/lock_page/screen/lock_page.dart';
import 'package:todo/view/screens/notes/notes_page/screen/notes_page.dart';
import 'package:todo/view/screens/tasks/todo_page/screen/todo_page.dart';
import 'package:todo/view_model/auth_view_model.dart';
import 'package:todo/view_model/notes_view_model.dart';
import 'package:todo/view_model/tasks_view_model.dart';
import 'package:todo/view_model/user_view_model.dart';
import 'package:flutter/services.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await NotificationService.init();
  tz.initializeTimeZones();

  runApp(MultiProvider(providers: [
    ChangeNotifierProvider(create: (_) => AuthViewModel()..initializeApp()),
    ChangeNotifierProvider(create: (_) => UserViewModel()),
    ChangeNotifierProvider(create: (_) => TasksViewModel()),
    ChangeNotifierProvider(create: (_) => NotesViewModel()),
  ], child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ToastificationWrapper(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          fontFamily: 'arial',
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue.shade300),
          useMaterial3: true,
        ),
        home: Consumer<AuthViewModel>(
          builder: (context, auth, _) {
            if (auth.status == AuthStatus.initializing) {
              final brightness = MediaQuery.of(context).platformBrightness;
              final bool isDarkMode = brightness == Brightness.dark;
              return Scaffold(
                  backgroundColor: isDarkMode ? const Color(0xff121212) : const Color(0xffEDEDED),                  body: const Center(child: CircularProgressIndicator()));
            }
            if (auth.status == AuthStatus.unauthenticated) {
              return const LockPage();
            }
            return FutureBuilder(
                future:
                    Provider.of<UserViewModel>(context, listen: false).get(),
                builder: (context, asyncSnapshot) {
                  return Consumer<UserViewModel>(
                      builder: (context, user, child) {
                    return user.user.startPage == 0 ? TodoPage() : NotesPage();
                  });
                });
          },
        ),
      ),
    );
  }
}
