import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:todo/main.dart';
import 'package:todo/services/authentication_service.dart';

import '../../../../../view_model/notes_view_model.dart';
import '../../../../../view_model/tasks_view_model.dart';
import '../../../../../view_model/user_view_model.dart';
import '../../../../../services/database_service.dart';
import '../../../../../services/verse_manager.dart';

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
            Flexible(
              child: Image.asset("assets/locked.png"),
            ),
            Flexible(
              child: IconButton(onPressed: () async {
                  final bool initialized = await AuthenticationService().initializeApp();
                  if (initialized) {
                  final DatabaseService dbService = DatabaseService();
                  await dbService.openDb();
                  await VerseManager.loadVerses();
                  runApp(MultiProvider(providers: [
                  ChangeNotifierProvider(create: (_) => UserViewModel()),
                  ChangeNotifierProvider(create: (_) => TasksViewModel()),
                  ChangeNotifierProvider(create: (_) => NotesViewModel()),
                  ], child: const MyApp()));  }
                  }, icon: const Icon(Icons.refresh_sharp,size: 70,color: Color(0xff3D5AFE),)),
            ),
          ],
        ),
      ),
    );
  }
}