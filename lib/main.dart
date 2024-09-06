import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:todo/pages/todo_page.dart';
import 'package:todo/provider/notes_provider.dart';
import 'package:todo/provider/tasks_provider.dart';
import 'package:todo/provider/theme_provider.dart';
import 'package:todo/provider/user_provider.dart';
import 'package:todo/services/database_service.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService().openDb();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  DatabaseService().storeEncryptionKey();
  runApp(MultiProvider(providers: [
    ChangeNotifierProvider(create: (_) => UserProvider()),
    ChangeNotifierProvider(create: (_) => ThemeProvider()),
    ChangeNotifierProvider(create: (_) => TasksProvider()),
    ChangeNotifierProvider(create: (_) => NotesProvider()),
  ], child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
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
