import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:toastification/toastification.dart';

import '../result.dart';

class FeedbackToast {
  /// The toast with the last deletion's Undo, which the next one replaces.
  static ToastificationItem? _undoToast;

  static void success(String message) {
    _show(message, ToastificationType.success);
  }

  static void error(String message) {
    _show(message, ToastificationType.error);
  }

  static void info(String message) {
    _show(
        message,
        ToastificationType.custom(
            "info", Color(0xff1E1E1E), Icons.info_outline_rounded));
  }

  /// Shows [message], about something just moved to the trash, with an Undo
  /// button that puts it back with [onUndo]. It stays up a little longer
  /// than the others, to give the user time to take it back. Only the last
  /// deletion's shows: the next one replaces it, as the trash has the rest.
  static void deleted(String message, {required VoidCallback onUndo}) {
    if (_undoToast case final previous?) toastification.dismiss(previous);
    late final ToastificationItem toast;
    toast = toastification.show(
      title: Row(
        children: [
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 17),
            ),
          ),
          const SizedBox(width: 8),
          _UndoButton(
            onPressed: () {
              toastification.dismiss(toast);
              onUndo();
            },
          ),
        ],
      ),
      type: ToastificationType.custom(
          "deleted", Color(0xff1E1E1E), Icons.delete_rounded),
      autoCloseDuration: const Duration(seconds: 5),
      dragToClose: true,
      style: ToastificationStyle.fillColored,
      alignment: AlignmentGeometry.directional(0, 1),
      // Undo is its button; it's swiped away to close it.
      closeButton: const ToastCloseButton(showType: CloseButtonShowType.none),
    );
    _undoToast = toast;
  }

  /// Shows how putting something back from a toast's Undo went, unless it
  /// went well: then it's back in view, which says so.
  static void undone(Result result) {
    switch (result) {
      case Success():
        break;
      case Failure(:final message):
        error(message);
      case Info(:final message):
        info(message);
    }
  }

  static void _show(String message, ToastificationType type) {
    toastification.show(
      title: Text(
        message,
        style: TextStyle(fontSize: 17),
      ),
      type: type,
      autoCloseDuration: const Duration(seconds: 3),
      dragToClose: true,
      style: ToastificationStyle.fillColored,
      alignment: AlignmentGeometry.directional(0, 1),
    );
  }
}

/// A toast's Undo: bold, in a light blue that reads on the toast's
/// graphite, and dimmed while it's held, as iOS's buttons are. The toast is
/// laid out above the app's Material, so it's drawn with none of its own.
class _UndoButton extends StatefulWidget {
  const _UndoButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_UndoButton> createState() => _UndoButtonState();
}

class _UndoButtonState extends State<_UndoButton> {
  bool _pressed = false;

  void _press(bool pressed) {
    if (pressed != _pressed) setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: "Undo",
      excludeSemantics: true,
      onTap: widget.onPressed,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _press(true),
        onTapUp: (_) => _press(false),
        onTapCancel: () => _press(false),
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onPressed();
        },
        child: ConstrainedBox(
          // As big as a fingertip, however small the word.
          constraints: const BoxConstraints(minWidth: 48, minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Center(
              widthFactor: 1,
              child: AnimatedOpacity(
                opacity: _pressed ? 0.45 : 1,
                duration: const Duration(milliseconds: 120),
                child: const Text(
                  "Undo",
                  style: TextStyle(
                    color: Color(0xff90CAF9),
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
