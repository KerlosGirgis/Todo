import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:todo/main.dart';
import 'package:todo/services/authentication_service.dart';

import '../../provider/notes_provider.dart';
import '../../provider/tasks_provider.dart';
import '../../provider/theme_provider.dart';
import '../../provider/user_provider.dart';
import '../../services/database_service.dart';
import '../../services/verse_manager.dart';

class LockPage extends StatefulWidget {
  const LockPage({
    super.key,
  });

  @override
  State<LockPage> createState() => LockPageState();
}

class LockPageState extends State<LockPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Image.asset("assets/locked.png"),
            ),
            Expanded(
              child: IconButton(onPressed: () async {
                  final bool initialized = await AuthenticationService().initializeApp();
                  if (initialized) {
                  final DatabaseService dbService = DatabaseService();
                  await dbService.openDb();
                  await VerseManager.loadVerses();
                  runApp(MultiProvider(providers: [
                  ChangeNotifierProvider(create: (_) => UserProvider()),
                  ChangeNotifierProvider(create: (_) => ThemeProvider()),
                  ChangeNotifierProvider(create: (_) => TasksProvider()),
                  ChangeNotifierProvider(create: (_) => NotesProvider()),
                  ], child: const MyApp()));  }
                  }, icon: const Icon(Icons.refresh_sharp,size: 70,color: Color(0xff3D5AFE),)),
            ),
          ],
        ),
      ),
    );
  }
}