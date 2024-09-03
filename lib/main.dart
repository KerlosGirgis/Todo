import 'package:flutter/material.dart';
import 'package:todo/pages/todo_page.dart';
import 'package:todo/services/authentication_service.dart';
import 'package:todo/services/database_service.dart';
import 'package:flutter/services.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService().openDb();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    runApp(const MyApp());
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
      home: const TodoPage(),
    );
  }
}
class AuthWrapper extends StatefulWidget {
  final AuthenticationService authService;

  const AuthWrapper({super.key, required this.authService});

  @override
  AuthWrapperState createState() => AuthWrapperState();
}

class AuthWrapperState extends State<AuthWrapper> {
  bool _isAuthenticated = false;
  bool _isAuthenticating = true;

  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }
  Future<void> _checkAuthentication() async {
    bool isAuthenticated = await widget.authService.authenticate();
    setState(() {
      _isAuthenticated = isAuthenticated;
      _isAuthenticating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isAuthenticating) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_isAuthenticated) {
      return const TodoPage();
    } else {
      return const Scaffold(
        body: Center(child: Text('Authentication failed')),
      );
    }
  }
}
