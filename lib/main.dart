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
import 'package:todo/services/authentication_service.dart';
import 'package:todo/services/notification.dart';
import 'package:todo/services/verse_manager.dart';
import 'package:todo/view/pages/lock_page.dart';
import 'package:todo/view/pages/todo_page.dart';
import 'package:todo/provider/notes_provider.dart';
import 'package:todo/provider/tasks_provider.dart';
import 'package:todo/provider/theme_provider.dart';
import 'package:todo/provider/user_provider.dart';
import 'package:todo/services/database_service.dart';
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
  final DatabaseService dbService = DatabaseService();
  await NotificationService.init();
  tz.initializeTimeZones();
  final bool initialized = await AuthenticationService().initializeApp();
  if (initialized) {
    await dbService.openDb();
    await VerseManager.loadVerses();
    runApp(MultiProvider(providers: [
      ChangeNotifierProvider(create: (_) => UserProvider()),
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider(create: (_) => TasksProvider()),
      ChangeNotifierProvider(create: (_) => NotesProvider()),
    ], child: const MyApp()));
  } else {
    runApp(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          fontFamily: 'arial',
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue.shade300),
          useMaterial3: true,
        ),
        home: const LockPage()));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'arial',
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue.shade300),
        useMaterial3: true,
      ),
      home: FutureBuilder(
        future: Provider.of<UserProvider>(context, listen: false).get(),
        builder: (context, snapshot) {
            return const TodoPage();
        },
      ),
    );
  }
}
