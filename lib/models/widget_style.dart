import 'dart:math' as math;

/// One of the app's home screen widgets: the to-do list, or a note.
enum WidgetKind {
  tasks("tasksWidgetStyle", "Tasks"),
  note("noteWidgetStyle", "Note");

  const WidgetKind(this.styleKey, this.androidName);

  /// Where the widget's style is kept, beside what it shows, in the widgets'
  /// own storage, which the phone reads them from.
  final String styleKey;

  /// The name of the phone's widget, its provider's class.
  final String androidName;
}

/// The font a widget's text is in: the phone's own, or the handwritten one
/// notes can be in. Kept by its name.
enum WidgetFont { regular, casual }

/// How a home screen widget looks: its background, the colour, size and
/// font of its text, and for the to-do widget, the colour of its checks
/// and whether it shows the tasks that are done.
///
/// The phone's widgets read it as [toJson] has it, and work out the
/// automatic colours as [ink] and [inkOn] do here, so the settings' preview
/// shows what they will.
class WidgetStyle {
  const WidgetStyle({
    this.background,
    this.opacity = 1,
    this.textColor,
    this.accent = defaultAccent,
    this.textSize = 1,
    this.font = WidgetFont.regular,
    this.showDone = false,
  });

  /// The app's blue.
  static const defaultAccent = 0xff3D5AFE;

  /// The text sizes on offer, as multiples of the widget's own: from a
  /// quarter to twice the size, in eighths, as the app's own text sizes.
  static const minTextSize = 0.25;
  static const maxTextSize = 2.0;
  static const textSizeStep = 0.125;

  /// How finely the background's opacity is set: in twentieths.
  static const opacityStep = 0.05;

  /// The to-do widget's, as it first comes: on the phone's own widget
  /// background, with the tasks still to do.
  static const tasksDefault = WidgetStyle();

  /// The note widget's, as it first comes: the note on its own, bold, with
  /// no background, as the widget has always been.
  static const noteDefault = WidgetStyle(opacity: 0);

  /// The style [kind] of widget first comes with.
  static WidgetStyle defaultFor(WidgetKind kind) => switch (kind) {
    WidgetKind.tasks => tasksDefault,
    WidgetKind.note => noteDefault,
  };

  /// The colour of the widget's background, as ARGB, or null for the
  /// phone's own widget background, which follows its dark mode.
  final int? background;

  /// How much the background shows, from 0, where the widget's text sits
  /// right on the wallpaper, to 1.
  final double opacity;

  /// The colour of the widget's text, as ARGB, or null for automatic: see
  /// [ink].
  final int? textColor;

  /// The colour of the to-do widget's checks and count, as ARGB.
  final int accent;

  /// The size of the widget's text, as a multiple of its own.
  final double textSize;

  final WidgetFont font;

  /// Whether the to-do widget lists the tasks that are done, checked off,
  /// or only the ones still to do.
  final bool showDone;

  /// The colour of the text: its own, or for automatic, black or white,
  /// whichever stands out more against a background of a colour of its
  /// own, where enough of it shows. Null for the phone's own text colour,
  /// which stands out against the phone's widget background, and against
  /// the wallpaper as the phone's widgets' text does, following its dark
  /// mode.
  int? get ink => textColor ?? inkOn(background, opacity);

  /// The automatic text colour on [background] showing at [opacity]: see
  /// [ink].
  static int? inkOn(int? background, double opacity) {
    if (background == null || opacity < 0.5) return null;
    return isLight(background) ? darkInk : lightInk;
  }

  /// Text colours for light backgrounds and for dark ones.
  static const darkInk = 0xde000000;
  static const lightInk = 0xffffffff;

  /// Whether [color] is light enough for dark text, by the same measure as
  /// Flutter's ThemeData.estimateBrightnessForColor: its relative luminance
  /// in sRGB, as WCAG has it.
  static bool isLight(int color) {
    double channel(int shift) {
      final value = ((color >> shift) & 0xff) / 255;
      return value <= 0.03928
          ? value / 12.92
          : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
    }

    final luminance =
        0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0);
    return (luminance + 0.05) * (luminance + 0.05) > 0.15;
  }

  /// A copy with what's given in place of its own. [background] and
  /// [textColor] take null for automatic, so they're only left as they are
  /// when they aren't given at all.
  WidgetStyle copyWith({
    Object? background = _same,
    double? opacity,
    Object? textColor = _same,
    int? accent,
    double? textSize,
    WidgetFont? font,
    bool? showDone,
  }) {
    return WidgetStyle(
      background: identical(background, _same)
          ? this.background
          : background as int?,
      opacity: opacity ?? this.opacity,
      textColor: identical(textColor, _same)
          ? this.textColor
          : textColor as int?,
      accent: accent ?? this.accent,
      textSize: textSize ?? this.textSize,
      font: font ?? this.font,
      showDone: showDone ?? this.showDone,
    );
  }

  static const _same = Object();

  /// The style as the widgets keep it, with [defaults] for anything it
  /// lacks or has out of range.
  factory WidgetStyle.fromJson(
    Map<String, dynamic> json, {
    WidgetStyle defaults = tasksDefault,
  }) {
    int? color(String key, int? fallback) => json.containsKey(key)
        ? switch (json[key]) {
            final int value => value & 0xffffffff,
            _ => null,
          }
        : fallback;
    double number(String key, double fallback, double min, double max) =>
        switch (json[key]) {
          final num value => value.toDouble().clamp(min, max),
          _ => fallback,
        };
    return WidgetStyle(
      background: color('background', defaults.background),
      opacity: number('opacity', defaults.opacity, 0, 1),
      textColor: color('textColor', defaults.textColor),
      accent: color('accent', defaults.accent) ?? defaults.accent,
      textSize: number('textSize', defaults.textSize, minTextSize, maxTextSize),
      font: WidgetFont.values.asNameMap()[json['font']] ?? defaults.font,
      showDone: switch (json['showDone']) {
        final bool value => value,
        _ => defaults.showDone,
      },
    );
  }

  /// The colours as ARGB numbers, or null for automatic; the font by its
  /// name.
  Map<String, Object?> toJson() => {
    'background': background,
    'opacity': opacity,
    'textColor': textColor,
    'accent': accent,
    'textSize': textSize,
    'font': font.name,
    'showDone': showDone,
  };

  /// The note widget's style from before it had one of its own: its text
  /// sized and in the font the notes' settings last set it to, which it
  /// keeps until its style is changed.
  static WidgetStyle legacyNote({String? textSize, bool? casualFont}) =>
      noteDefault.copyWith(
        textSize: (double.tryParse(textSize ?? "") ?? 1).clamp(
          minTextSize,
          maxTextSize,
        ),
        font: casualFont == true ? WidgetFont.casual : WidgetFont.regular,
      );

  @override
  bool operator ==(Object other) =>
      other is WidgetStyle &&
      other.background == background &&
      other.opacity == opacity &&
      other.textColor == textColor &&
      other.accent == accent &&
      other.textSize == textSize &&
      other.font == font &&
      other.showDone == showDone;

  @override
  int get hashCode => Object.hash(
    background,
    opacity,
    textColor,
    accent,
    textSize,
    font,
    showDone,
  );

  @override
  String toString() => "WidgetStyle(${toJson()})";
}
