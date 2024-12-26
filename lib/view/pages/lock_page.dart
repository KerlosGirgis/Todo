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
import '../widgets/button.dart';

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
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 3,),
          Image.asset("assets/locked.png"),
          const Spacer(flex: 1,),
          IconButton(onPressed: () async {
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
          const Spacer(flex: 5,),
        ],
      ),
    );
  }
}