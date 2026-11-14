import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../../core/extensions/theme_extensions.dart';
import '../../../../../../models/todo_item.dart';
import '../../../../../widgets/glass.dart';

/// iOS's system red, a touch brighter on dark pages, as there.
Color _systemRed(bool isDarkTheme) =>
    isDarkTheme ? const Color(0xffFF453A) : const Color(0xffFF3B30);

/// The buttons that act on the task picked out, on a glass bar that comes
/// up beside it: they check it off, add a subtask to it, edit it, set its
/// reminder and delete it.
class MapToolbar extends StatelessWidget {
  const MapToolbar({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onAddSubtask,
    required this.onEdit,
    required this.onReminder,
    required this.onDailyReminder,
    required this.onDelete,
  });

  static const height = 46.0;
  static const width = 5 * _ToolButton.size + 8;

  final TodoItem task;
  final VoidCallback onToggle;
  final VoidCallback onAddSubtask;
  final VoidCallback onEdit;
  final VoidCallback onReminder;
  final VoidCallback onDailyReminder;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final ink = context.colors.wB;
    final accent = context.colors.moreLess;
    final reminds = task.reminder != Reminder.none;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      builder: (context, shown, child) => Opacity(
        opacity: shown,
        child: Transform.scale(scale: 0.9 + 0.1 * shown, child: child),
      ),
      child: SizedBox(
        width: width,
        height: height,
        child: Glass(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                _ToolButton(
                  icon: task.done ? Icons.replay_rounded : Icons.check_rounded,
                  tooltip: task.done ? "Mark Not Done" : "Mark Done",
                  color: accent,
                  onPressed: onToggle,
                ),
                _ToolButton(
                  icon: Icons.subdirectory_arrow_right_rounded,
                  tooltip: "Add Subtask",
                  color: ink,
                  onPressed: onAddSubtask,
                ),
                _ToolButton(
                  icon: Icons.edit_rounded,
                  tooltip: "Edit",
                  color: ink,
                  onPressed: onEdit,
                ),
                // A done task has no reminder, as on its card.
                _ToolButton(
                  icon: reminds
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_none_rounded,
                  tooltip: reminds ? "Turn Reminder Off" : "Remind Me",
                  color: reminds ? accent : ink,
                  onPressed: task.done ? null : onReminder,
                  // Only while it has none: the tap turns one off.
                  onLongPress: task.done || reminds ? null : onDailyReminder,
                ),
                _ToolButton(
                  icon: Icons.delete_outline_rounded,
                  tooltip: "Delete",
                  color: _systemRed(isDarkTheme),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One of the buttons that act on the task picked out.
class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onPressed,
    this.onLongPress,
  });

  static const size = 46.0;

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final onPressed = this.onPressed;
    final onLongPress = this.onLongPress;
    return Tooltip(
      message: tooltip,
      // A long press does something of its own on some, so it can't bring
      // the tooltip up too.
      triggerMode: onLongPress == null ? null : TooltipTriggerMode.manual,
      child: SizedBox.square(
        dimension: size,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onPressed == null
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onPressed();
                  },
            onLongPress: onLongPress == null
                ? null
                : () {
                    HapticFeedback.mediumImpact();
                    onLongPress();
                  },
            customBorder: const CircleBorder(),
            // Glass highlights a pressed button instead of rippling.
            splashFactory: NoSplash.splashFactory,
            highlightColor: context.colors.wB.withValues(alpha: 0.1),
            child: Icon(
              icon,
              size: 22,
              color: color.withValues(alpha: onPressed == null ? 0.3 : 1),
            ),
          ),
        ),
      ),
    );
  }
}
