import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:todo/view/pages/note_editor_page.dart';
import 'package:todo/view/pages/profile_page.dart';
import 'package:todo/provider/notes_provider.dart';
import 'package:todo/provider/user_provider.dart';
import 'package:todo/view/widgets/add_note_dialog.dart';
import 'package:todo/services/authentication_service.dart';
import '../widgets/appbar_avatar.dart';
import '../widgets/update_note_dialog.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final AuthenticationService authService = AuthenticationService();
  final LocalAuthentication localAuthentication = LocalAuthentication();

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NotesProvider>(context, listen: false).get();
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return Consumer<UserProvider>(
      builder: (context, user, child) {
        return Scaffold(
          backgroundColor: user.colorProvider.pageBackground,
          appBar: AppBar(
            surfaceTintColor: Colors.transparent,
            automaticallyImplyLeading: false,
            backgroundColor: user.colorProvider.pageBackground,
            title: Text(
              "Notes",
              style: TextStyle(
                fontSize: 30,
                color: user.colorProvider.appTitle,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              Row(
                children: [
                  IconButton(onPressed: () async {
                    Provider.of<NotesProvider>(context, listen: false).backup();
                  }, icon: const Icon(Icons.backup,color: Colors.grey,)),
                  IconButton(onPressed: () async {
                    Provider.of<NotesProvider>(context, listen: false).restore();
                  }, icon: const Icon(Icons.settings_backup_restore,color: Colors.grey,)),
                  IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder:
                                (context, animation, secondaryAnimation) =>
                                    const ProfilePage(),
                            transitionsBuilder: (context, animation,
                                secondaryAnimation, child) {
                              const begin = Offset(0.0, 1.0);
                              const end = Offset.zero;
                              const curve = Curves.ease;
                              var tween = Tween(begin: begin, end: end)
                                  .chain(CurveTween(curve: curve));
                              var offsetAnimation = animation.drive(tween);
                              return SlideTransition(
                                  position: offsetAnimation, child: child);
                            },
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.settings,
                        color: Colors.grey,
                      )),
                  const AppbarAvatar(),
                  const Padding(padding: EdgeInsets.only(right: 18))
                ],
              )
            ],
          ),
          floatingActionButton: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FloatingActionButton(
                  heroTag: 0,
                  backgroundColor:
                      user.colorProvider.floatingActionButtonBackground,
                  foregroundColor:
                      user.colorProvider.floatingActionButtonForeground,
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Icon(Icons.checklist_sharp)),
              const Padding(padding: EdgeInsets.only(bottom: 20)),
              FloatingActionButton(
                heroTag: 1,
                backgroundColor:
                    user.colorProvider.floatingActionButtonBackground,
                foregroundColor:
                    user.colorProvider.floatingActionButtonForeground,
                onPressed: () {
                  showDialog(
                      context: context,
                      builder: (context) {
                        return const AddNoteDialog();
                      });
                },
                child: const Icon(Icons.add),
              ),
            ],
          ),
          /*

           */

          body: Consumer<NotesProvider>(
            builder: (context, notes, child) {
              return notes.notes.isEmpty
                  ? Center(
                      child: Image.asset(
                        "assets/empty_notes.png",
                        scale: 2,
                      ),
                    )
                  : GridView.builder(
                      itemCount: notes.notes.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: MediaQuery.of(context).orientation ==
                                  Orientation.portrait
                              ? 2
                              : 4,
                          childAspectRatio: 0.7),
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          child: Container(
                            margin: const EdgeInsets.all(16),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final cardWidth = screenSize.width * 0.8;
                                const aspectRatio = 16 / 9;
                                return AspectRatio(
                                  aspectRatio: aspectRatio,
                                  child: Container(
                                      width: cardWidth,
                                      decoration: BoxDecoration(
                                        color: Color(
                                            notes.notes[index].coverColor),
                                        borderRadius:
                                            BorderRadius.circular(12.0),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.2),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            maxLines: 5,
                                            textAlign: TextAlign.center,
                                            overflow: TextOverflow.ellipsis,
                                            notes.notes[index].title,
                                            style: TextStyle(
                                                color: Color(notes
                                                    .notes[index].titleColor),
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold),
                                          ),
                                          notes.notes[index].protected == 1
                                              ? Image.asset(
                                                  "assets/lock.png",
                                                  scale: 1.4,
                                                )
                                              : const Row(),
                                        ],
                                      )),
                                );
                              },
                            ),
                          ),
                          onTap: () async {
                            if (notes.notes[index].protected == 1) {
                              bool isAuthenticated =
                                  await authService.authenticate();
                              if (isAuthenticated) {
                                if (context.mounted) {
                                  Navigator.push(
                                    context,
                                    PageRouteBuilder(
                                      pageBuilder: (context, animation,
                                              secondaryAnimation) =>
                                          NoteEditorPage(
                                        note: notes.notes[index],
                                      ),
                                      transitionsBuilder: (context, animation,
                                          secondaryAnimation, child) {
                                        const begin = Offset(1.0, 0.0);
                                        const end = Offset.zero;
                                        const curve = Curves.ease;
                                        var tween = Tween(
                                                begin: begin, end: end)
                                            .chain(CurveTween(curve: curve));
                                        var offsetAnimation =
                                            animation.drive(tween);
                                        return SlideTransition(
                                            position: offsetAnimation,
                                            child: child);
                                      },
                                    ),
                                  );
                                }
                              }
                            } else {
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder: (context, animation,
                                          secondaryAnimation) =>
                                      NoteEditorPage(
                                    note: notes.notes[index],
                                  ),
                                  transitionsBuilder: (context, animation,
                                      secondaryAnimation, child) {
                                    const begin = Offset(1.0, 0.0);
                                    const end = Offset.zero;
                                    const curve = Curves.ease;
                                    var tween = Tween(begin: begin, end: end)
                                        .chain(CurveTween(curve: curve));
                                    var offsetAnimation =
                                        animation.drive(tween);
                                    return SlideTransition(
                                        position: offsetAnimation,
                                        child: child);
                                  },
                                ),
                              );
                            }
                          },
                          onLongPress: () async {
                            if (notes.notes[index].protected == 1) {
                              bool isAuthenticated =
                                  await authService.authenticate();
                              if (isAuthenticated) {
                                if (context.mounted) {
                                  showDialog(
                                      context: context,
                                      builder: (context) {
                                        return UpdateNoteDialog(index: index);
                                      });
                                }
                              }
                            } else {
                              showDialog(
                                  context: context,
                                  builder: (context) {
                                    return UpdateNoteDialog(index: index);
                                  });
                            }
                          },
                        );
                      });
            },
          ),
        );
      },
    );
  }
}
