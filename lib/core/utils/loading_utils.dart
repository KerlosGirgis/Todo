import 'dart:math';

class LoadingUtils {
  static const List<String> _messages = [
    "NEGOTIATING WITH PROCRASTINATION",
    "CHASING OVERDUE TASKS",
    "LOCATING FRANKENSTEIN'S BRAIN...",
    "GATHERING SCATTERED BRAIN CELLS",
    "GIVING A MONKEY A SHOWER...",
    "POLISHING BRILLIANT IDEAS",
    "DISCOVERING SOMETHING THAT DOESN'T EXIST...",
  ];

  static String getRandomMessage() {
    return _messages[Random().nextInt(_messages.length)];
  }
}