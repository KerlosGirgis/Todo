import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../view_model/auth_view_model.dart';

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
              child: IconButton(
                  onPressed: () async {
                    await Provider.of<AuthViewModel>(context, listen: false).retryAuthentication();
                  },
                  icon: const Icon(Icons.refresh_sharp, size: 70, color: Color(0xff3D5AFE))
              )
            ),
          ],
        ),
      ),
    );
  }
}