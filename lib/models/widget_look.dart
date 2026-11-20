import 'widget_style.dart';

/// The colours the phone gives its widgets in light or dark mode: their
/// background, and their text on it.
class WidgetThemeColors {
  const WidgetThemeColors({
    required this.background,
    required this.text,
    required this.secondaryText,
    required this.noteText,
  });

  /// All as ARGB.
  final int background;
  final int text;
  final int secondaryText;

  /// The note widget's text, which has always been in the colour the
  /// phone's theme gives text that has none of its own: a faint one.
  final int noteText;

  factory WidgetThemeColors.fromMap(
          Map<Object?, Object?> map, WidgetThemeColors fallback) =>
      WidgetThemeColors(
        background: _color(map['background']) ?? fallback.background,
        text: _color(map['text']) ?? fallback.text,
        secondaryText: _color(map['secondary']) ?? fallback.secondaryText,
        noteText: _color(map['note']) ?? fallback.noteText,
      );
}

/// How the phone draws the app's widgets, so the settings can draw them
/// alike: the corners and colours its theme gives them, the colours of its
/// wallpaper, and how big the widgets on the home screen are.
class WidgetLook {
  const WidgetLook({
    this.radius = 24,
    this.light = lightFallback,
    this.dark = darkFallback,
    this.wallpaper = const [],
    this.sizes = const {},
  });

  /// As near as the app can tell without the phone: its colours for widgets
  /// before Android 12's took after the wallpaper.
  static const lightFallback = WidgetThemeColors(
    background: 0xfff8f9fa,
    text: 0xde000000,
    secondaryText: 0x8a000000,
    noteText: 0x61000000,
  );
  static const darkFallback = WidgetThemeColors(
    background: 0xff202124,
    text: 0xffffffff,
    secondaryText: 0xb3ffffff,
    noteText: 0x80ffffff,
  );

  /// The radius of a widget's corners, in logical pixels.
  final double radius;

  final WidgetThemeColors light;
  final WidgetThemeColors dark;

  /// The wallpaper's main colours as ARGB, the most prominent first, if the
  /// phone said.
  final List<int> wallpaper;

  /// How big the first of each kind of widget on the home screen is, in
  /// logical pixels, with the phone held upright. None for a kind that
  /// isn't there.
  final Map<WidgetKind, ({double width, double height})> sizes;

  WidgetThemeColors colors({required bool dark}) => dark ? this.dark : light;

  /// The look as the phone's channel describes it, with the fallbacks for
  /// anything it leaves out.
  factory WidgetLook.fromMap(Map<Object?, Object?> map) {
    final sizes = <WidgetKind, ({double width, double height})>{};
    if (map['sizes'] case final Map<Object?, Object?> given) {
      for (final kind in WidgetKind.values) {
        if (given[kind.androidName]
            case [final num width, final num height, ...]) {
          if (width > 0 && height > 0) {
            sizes[kind] = (width: width.toDouble(), height: height.toDouble());
          }
        }
      }
    }
    return WidgetLook(
      radius: switch (map['radius']) {
        final num radius when radius >= 0 => radius.toDouble(),
        _ => 24,
      },
      light: switch (map['light']) {
        final Map<Object?, Object?> colors =>
          WidgetThemeColors.fromMap(colors, lightFallback),
        _ => lightFallback,
      },
      dark: switch (map['dark']) {
        final Map<Object?, Object?> colors =>
          WidgetThemeColors.fromMap(colors, darkFallback),
        _ => darkFallback,
      },
      wallpaper: [
        if (map['wallpaper'] case final List<Object?> colors)
          for (final color in colors)
            if (_color(color) case final color?) color,
      ],
      sizes: sizes,
    );
  }
}

/// [value] as an ARGB colour: the phone sends them as signed 32-bit numbers.
int? _color(Object? value) => value is int ? value & 0xffffffff : null;
