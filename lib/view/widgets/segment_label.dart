import 'package:material_ui/material_ui.dart';

/// A segment of a segmented control, such as a setting's or the trash's
/// switch between tasks and notes: [label], after an [icon] if it has one.
/// The label shrinks to fit a segment too narrow for it, as in large text.
class SegmentLabel extends StatelessWidget {
  const SegmentLabel({super.key, this.icon, required this.label, this.style});

  final IconData? icon;
  final String label;

  /// How [label] differs from the others, such as in the font it names.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 17), const SizedBox(width: 6)],
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: const TextStyle(fontSize: 14.5).merge(style),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
