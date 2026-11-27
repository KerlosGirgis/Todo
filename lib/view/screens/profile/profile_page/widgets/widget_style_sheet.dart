import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../../core/result.dart';
import '../../../../../core/ui/feedback_toast.dart';
import '../../../../../models/app_lock.dart';
import '../../../../../models/widget_look.dart';
import '../../../../../models/widget_style.dart';
import '../../../../../view_model/user_view_model.dart';
import '../../../../../view_model/widgets_view_model.dart';
import '../../../../widgets/color_swatches.dart';
import '../../../../widgets/form_dialog.dart';
import '../../../../widgets/profile_button.dart';
import '../../../../widgets/settings_group.dart';
import 'text_size_sheet.dart' show formatTextSize;
import 'widget_previews.dart';

const _accent = Color(0xff3D5AFE);

// iOS's system colours, as on the settings' other rows.
const _blue = Color(0xff007AFF);
const _teal = Color(0xff30B0C7);
const _indigo = Color(0xff5856D6);
const _green = Color(0xff34C759);
const _purple = Color(0xffAF52DE);
const _pink = Color(0xffFF2D55);
const _orange = Color(0xffFF9500);

/// The name each kind of widget goes by in its sheet.
String widgetName(WidgetKind kind) => switch (kind) {
  WidgetKind.tasks => "To-Do Widget",
  WidgetKind.note => "Note Widget",
};

/// Opens the sheet that sets how [kind] of widget looks, once it's read in
/// how it looks now and how the phone draws widgets. A style that isn't
/// applied is dropped when the sheet closes.
Future<void> showWidgetStyleSheet(BuildContext context, WidgetKind kind) async {
  await context.read<WidgetsViewModel>().load();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: context.colors.dialogBackground,
    shape: RoundedSuperellipseBorder(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      side: context.colors.sheetSide,
    ),
    builder: (context) => WidgetStyleSheet(kind: kind),
  );
}

/// Which colour's palette is open.
enum _Palette { background, text, accent }

/// A live preview of one of the home screen's widgets, over the settings
/// that style it: its background, its text, and for the to-do widget, its
/// checks and whether it lists the tasks that are done.
class WidgetStyleSheet extends StatefulWidget {
  const WidgetStyleSheet({super.key, required this.kind});

  final WidgetKind kind;

  @override
  State<WidgetStyleSheet> createState() => _WidgetStyleSheetState();
}

class _WidgetStyleSheetState extends State<WidgetStyleSheet> {
  /// The style being tried out. It's kept here rather than on the view
  /// model, so that trying it rebuilds only the sheet, and not the settings
  /// under it.
  late WidgetStyle _style = context.read<WidgetsViewModel>().styleOf(
    widget.kind,
  );

  /// Whether the preview is in dark mode, which the widget follows the
  /// phone into, or null for as the phone is now.
  bool? _dark;

  _Palette? _open;

  WidgetKind get _kind => widget.kind;

  void _set(WidgetStyle style) => setState(() => _style = style);

  void _togglePalette(_Palette palette) =>
      setState(() => _open = _open == palette ? null : palette);

  void _setColor(_Palette palette, Color? color) {
    final argb = color?.toARGB32();
    _set(switch (palette) {
      _Palette.background => _style.copyWith(background: argb),
      _Palette.text => _style.copyWith(textColor: argb),
      _Palette.accent => _style.copyWith(
        accent: argb ?? WidgetStyle.defaultAccent,
      ),
    });
  }

  Future<void> _pickCustomColor(
    _Palette palette,
    WidgetThemeColors colors,
  ) async {
    final current = Color(switch (palette) {
      _Palette.background => _style.background ?? colors.background,
      _Palette.text => _style.ink ?? colors.text,
      _Palette.accent => _style.accent,
    });
    final picked = await pickCustomColor(context, current, switch (palette) {
      _Palette.background => "Background",
      _Palette.text => "Text Color",
      _Palette.accent => "Accent Color",
    });
    // A cancelled picker hands back the colour it started with.
    if (mounted && picked != current) _setColor(palette, picked);
  }

  Future<void> _apply() async {
    final result = await context.read<WidgetsViewModel>().setStyle(
      _kind,
      _style,
    );
    if (result is Success && mounted) Navigator.pop(context);
    FeedbackToast.show(result);
  }

  /// Adds a widget, styled as the sheet has it, to the home screen, once
  /// the phone has asked the user.
  Future<void> _add() async {
    final widgets = context.read<WidgetsViewModel>();
    if (_style != widgets.styleOf(_kind)) {
      final result = await widgets.setStyle(_kind, _style);
      if (result is! Success) return FeedbackToast.show(result);
    }
    if (mounted) Navigator.pop(context);
    FeedbackToast.show(await widgets.add(_kind));
  }

  @override
  Widget build(BuildContext context) {
    final widgets = context.watch<WidgetsViewModel>();
    final dark =
        _dark ?? MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final header = _Header(
      title: widgetName(_kind),
      canReset: _style != WidgetStyle.defaultFor(_kind),
      onReset: () => _set(WidgetStyle.defaultFor(_kind)),
    );
    final preview = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Read out as what it is, rather than as its sample tasks.
        Semantics(
          container: true,
          label: "Preview of the ${widgetName(_kind).toLowerCase()}",
          child: ExcludeSemantics(
            child: _PreviewPanel(
              height: _kind == WidgetKind.tasks ? 250 : 200,
              look: widgets.look,
              dark: dark,
              child: WidgetPreview(
                kind: _kind,
                style: _style,
                look: widgets.look,
                dark: dark,
                noteText: widgets.noteText,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: _ModeSwitch(
            dark: dark,
            onChanged: (dark) => setState(() => _dark = dark),
          ),
        ),
      ],
    );
    final controls = _Controls(
      kind: _kind,
      style: _style,
      open: _open,
      onChanged: _set,
      onToggle: _togglePalette,
      onColor: _setColor,
      onCustomColor: (palette) =>
          _pickCustomColor(palette, widgets.look.colors(dark: dark)),
    );
    final buttons = Row(
      children: [
        if (widgets.canAdd) ...[
          Expanded(
            child: ProfileButton(
              label: "Add Widget",
              icon: Icons.add_rounded,
              tinted: true,
              onPressed: _add,
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: ProfileButton(
            label: "Apply",
            onPressed: _style == widgets.styleOf(_kind) ? null : _apply,
          ),
        ),
      ],
    );
    // Clear of the gesture bar, which a bottom sheet's safe area leaves in.
    final padding = EdgeInsets.fromLTRB(
      20,
      0,
      20,
      20 + MediaQuery.paddingOf(context).bottom,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // On a tall enough screen, the preview stays in sight while the
        // settings under it scroll.
        if (constraints.maxHeight >= 640) {
          return Padding(
            padding: padding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                const SizedBox(height: 16),
                preview,
                const SizedBox(height: 16),
                Flexible(child: SingleChildScrollView(child: controls)),
                const SizedBox(height: 16),
                buttons,
              ],
            ),
          );
        }
        return SingleChildScrollView(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              const SizedBox(height: 16),
              preview,
              const SizedBox(height: 16),
              controls,
              const SizedBox(height: 16),
              buttons,
            ],
          ),
        );
      },
    );
  }
}

/// The sheet's title, with a Reset that takes the style back to how the
/// widget first comes.
class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.canReset,
    required this.onReset,
  });

  final String title;
  final bool canReset;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Clear of the Reset either side, as it's centred.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 72),
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.colors.wB,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.4,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: AnimatedOpacity(
                opacity: canReset ? 1 : 0,
                duration: const Duration(milliseconds: 150),
                child: TextButton(
                  onPressed: canReset ? onReset : null,
                  style: TextButton.styleFrom(
                    foregroundColor: context.colors.moreLess,
                  ),
                  child: const Text("Reset"),
                ),
              ),
            ),
          ],
        ),
        Text(
          "How it looks on your home screen.",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.colors.wB.withValues(alpha: 0.5),
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

/// A panel in the wallpaper's colours, or a blue like a wallpaper's when
/// the phone doesn't say, with the preview on it: dimmed a little in dark
/// mode, as the phone dims the wallpaper.
class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({
    required this.height,
    required this.look,
    required this.dark,
    required this.child,
  });

  final double height;
  final WidgetLook look;
  final bool dark;
  final Widget child;

  static const _fallback = [
    Color(0xff27408B),
    Color(0xff4F6FD0),
    Color(0xff9DB6EE),
  ];

  @override
  Widget build(BuildContext context) {
    final wallpaper = [for (final color in look.wallpaper) Color(color)];
    final colors = switch (wallpaper.length) {
      0 => _fallback,
      // One colour, from deep to light.
      1 => [
        Color.lerp(wallpaper.first, Colors.black, 0.25)!,
        wallpaper.first,
        Color.lerp(wallpaper.first, Colors.white, 0.35)!,
      ],
      _ => wallpaper,
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        shape: const RoundedSuperellipseBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedOpacity(
            opacity: dark ? 1 : 0,
            duration: const Duration(milliseconds: 250),
            child: const ColoredBox(color: Color(0x47000000)),
          ),
          Padding(padding: const EdgeInsets.all(20), child: child),
        ],
      ),
    );
  }
}

/// Switches the preview between light and dark mode.
class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.dark, required this.onChanged});

  final bool dark;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: CupertinoSlidingSegmentedControl<bool>(
        groupValue: dark,
        onValueChanged: (dark) {
          if (dark != null) onChanged(dark);
        },
        children: const {
          false: _Segment(icon: Icons.light_mode_rounded, label: "Light"),
          true: _Segment(icon: Icons.dark_mode_rounded, label: "Dark"),
        },
      ),
    );
  }
}

/// The settings that style the widget, in a group like the profile page's.
class _Controls extends StatelessWidget {
  const _Controls({
    required this.kind,
    required this.style,
    required this.open,
    required this.onChanged,
    required this.onToggle,
    required this.onColor,
    required this.onCustomColor,
  });

  final WidgetKind kind;
  final WidgetStyle style;
  final _Palette? open;
  final ValueChanged<WidgetStyle> onChanged;
  final ValueChanged<_Palette> onToggle;
  final void Function(_Palette palette, Color? color) onColor;
  final ValueChanged<_Palette> onCustomColor;

  @override
  Widget build(BuildContext context) {
    final tasks = kind == WidgetKind.tasks;
    final background = style.background;
    final textColor = style.textColor;
    final lockedNote =
        tasks &&
        context.select<UserViewModel, bool>(
          (user) => user.appLock != AppLock.off,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormDialogGroup(
          children: [
            ColorTile(
              icon: Icons.format_color_fill_rounded,
              color: _blue,
              title: "Background",
              value: background == null ? null : Color(background),
              offersAutomatic: true,
              open: open == _Palette.background,
              onTap: () => onToggle(_Palette.background),
              onSelected: (color) => onColor(_Palette.background, color),
              onCustom: () => onCustomColor(_Palette.background),
            ),
            _SliderTile(
              icon: Icons.opacity_rounded,
              color: _teal,
              title: "Opacity",
              value: style.opacity,
              label: "${(style.opacity * 100).round()}%",
              min: 0,
              max: 1,
              step: WidgetStyle.opacityStep,
              onChanged: (opacity) =>
                  onChanged(style.copyWith(opacity: opacity)),
            ),
            ColorTile(
              icon: Icons.format_color_text_rounded,
              color: _indigo,
              title: "Text Color",
              value: textColor == null ? null : Color(textColor),
              offersAutomatic: true,
              open: open == _Palette.text,
              onTap: () => onToggle(_Palette.text),
              onSelected: (color) => onColor(_Palette.text, color),
              onCustom: () => onCustomColor(_Palette.text),
            ),
            if (tasks)
              ColorTile(
                icon: Icons.check_circle_rounded,
                color: _green,
                title: "Accent Color",
                value: Color(style.accent),
                open: open == _Palette.accent,
                onTap: () => onToggle(_Palette.accent),
                onSelected: (color) => onColor(_Palette.accent, color),
                onCustom: () => onCustomColor(_Palette.accent),
              ),
            _SliderTile(
              icon: Icons.format_size_rounded,
              color: _purple,
              title: "Text Size",
              value: style.textSize,
              label: formatTextSize(style.textSize),
              min: WidgetStyle.minTextSize,
              max: WidgetStyle.maxTextSize,
              step: WidgetStyle.textSizeStep,
              sizeEnds: true,
              onChanged: (size) => onChanged(style.copyWith(textSize: size)),
            ),
            SettingsTile(
              icon: Icons.font_download_rounded,
              color: _pink,
              title: "Font",
              bottom: CupertinoSlidingSegmentedControl<WidgetFont>(
                groupValue: style.font,
                onValueChanged: (font) {
                  if (font != null) onChanged(style.copyWith(font: font));
                },
                children: const {
                  WidgetFont.regular: _Segment(label: "Regular"),
                  // Written in the font itself, as a sample.
                  WidgetFont.casual: _Segment(label: "Casual", casual: true),
                },
              ),
            ),
            if (tasks)
              SettingsSwitchTile(
                icon: Icons.task_alt_rounded,
                color: _orange,
                title: "Show Done Tasks",
                subtitle: const Text("Checked off, rather than hidden"),
                value: style.showDone,
                onChanged: (showDone) =>
                    onChanged(style.copyWith(showDone: showDone)),
              ),
          ],
        ),
        if (lockedNote)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              "While the App Lock is on, the widget only shows how many "
              "tasks are left, as anyone with your phone could read it.",
              style: TextStyle(
                color: context.colors.wB.withValues(alpha: 0.5),
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ),
      ],
    );
  }
}

/// A row with a slider under it, and the slider's value at its end. A
/// slider for a size has a small and a large "A" at its ends.
class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.label,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
    this.sizeEnds = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final double value;
  final String label;
  final double min;
  final double max;
  final double step;
  final ValueChanged<double> onChanged;
  final bool sizeEnds;

  @override
  Widget build(BuildContext context) {
    final secondary = context.colors.wB.withValues(alpha: 0.5);
    Widget end(double size) => Text(
      "A",
      style: TextStyle(
        color: secondary,
        fontSize: size,
        fontWeight: FontWeight.w600,
      ),
    );
    final slider = CupertinoSlider(
      value: value.clamp(min, max),
      min: min,
      max: max,
      divisions: ((max - min) / step).round(),
      activeColor: _accent,
      // Snapped to the steps the divisions stand for, so the value reads
      // cleanly and matches the saved one exactly.
      onChanged: (value) => onChanged((value / step).round() * step),
    );
    return SettingsTile(
      icon: icon,
      color: color,
      title: title,
      trailing: Text(
        label,
        style: TextStyle(
          color: context.colors.wB.withValues(alpha: 0.45),
          fontSize: 16,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      bottom: sizeEnds
          ? Row(
              children: [
                end(13),
                const SizedBox(width: 10),
                Expanded(child: slider),
                const SizedBox(width: 10),
                end(22),
              ],
            )
          : slider,
    );
  }
}

/// A segment of a segmented control: a label, after an optional icon.
class _Segment extends StatelessWidget {
  const _Segment({this.icon, required this.label, this.casual = false});

  final IconData? icon;
  final String label;

  /// Whether the label is in the handwritten font.
  final bool casual;

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
                style: TextStyle(
                  fontSize: 14.5,
                  fontFamily: casual ? 'casual' : null,
                  fontWeight: casual ? FontWeight.w600 : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
