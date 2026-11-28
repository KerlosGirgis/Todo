import 'dart:ui';

/// The app's own colours, the same in every theme. Those that change with
/// the theme are `AppColors`', read with `context.colors`.
abstract final class AppPalette {
  /// The app's accent: what's chosen, switched on, or there to be tapped,
  /// and where its gradients start.
  static const accent = Color(0xff3D5AFE);

  /// The light blue the [accent]'s gradients run to.
  static const highlight = Color(0xff40C4FF);
}

/// iOS's system colours, as Apple gives them for light pages, and the
/// brighter ones it gives dark pages where the app uses them: so that each
/// setting, and each row of a form, has an icon of its own colour, as in the
/// Settings app; and for the colours a note or a widget can be given, and
/// the task map's branches.
abstract final class SystemColors {
  static const red = Color(0xffFF3B30);
  static const orange = Color(0xffFF9500);
  static const yellow = Color(0xffFFCC00);
  static const green = Color(0xff34C759);
  static const mint = Color(0xff00C7BE);
  static const teal = Color(0xff30B0C7);
  static const cyan = Color(0xff32ADE6);
  static const blue = Color(0xff007AFF);
  static const indigo = Color(0xff5856D6);
  static const purple = Color(0xffAF52DE);
  static const pink = Color(0xffFF2D55);

  static const redDark = Color(0xffFF453A);
  static const orangeDark = Color(0xffFF9F0A);
  static const greenDark = Color(0xff30D158);
  static const mintDark = Color(0xff63E6E2);
  static const tealDark = Color(0xff40C8E0);
  static const blueDark = Color(0xff0A84FF);
  static const indigoDark = Color(0xff5E5CE6);
  static const purpleDark = Color(0xffBF5AF2);
  static const pinkDark = Color(0xffFF375F);

  /// [orange] deepened to read as text on a light page: Apple's
  /// high-contrast version of it.
  static const orangeHighContrast = Color(0xffC93400);

  /// The grey of what's raised on a dark page, such as glass and the tour's
  /// card: Apple's gray 5 for dark pages.
  static const gray5Dark = Color(0xff2C2C2E);
}
