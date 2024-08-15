import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key,});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(onPressed: (){}, icon: const Icon(Icons.menu_sharp)),
        title: const Text("ToDo",style: TextStyle(fontWeight: FontWeight.bold,),),
        actions: [
          Row(
            children: [
              CircleAvatar(child: IconButton(onPressed: (){}, icon: const Icon(Icons.person_sharp)),),
              const Padding(padding: EdgeInsets.only(right: 15))
            ],
          )
        ],
      ),
    );
  }
}
