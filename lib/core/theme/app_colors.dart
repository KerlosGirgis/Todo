import 'package:flutter/material.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color floatingActionButtonBackground;
  final Color floatingActionButtonForeground;
  final Color wB;
  final Color cardBackground;
  final Color subtitle;
  final Color pageBackground;
  final Color profileAlertBackground;
  final Color profilePageName;
  final Color appBarIcons;
  final Color moreLess;
  final Color dialogIconContainer;
  final Color dialogIcon;
  final Color dialogExitIcon;
  final Color dialogExitContainer;

  const AppColors({
    required this.floatingActionButtonBackground,
    required this.floatingActionButtonForeground,
    required this.wB,
    required this.cardBackground,
    required this.subtitle,
    required this.pageBackground,
    required this.profileAlertBackground,
    required this.profilePageName,
    required this.appBarIcons,
    required this.moreLess,
    required this.dialogIconContainer,
    required this.dialogIcon,
    required this.dialogExitIcon,
    required this.dialogExitContainer,
  });

  static const light = AppColors(
    floatingActionButtonBackground: Color(0xff3D5AFE),
    floatingActionButtonForeground: Colors.white,
    wB: Colors.black,
    cardBackground: Color(0xffF5F5F5),
    subtitle: Color(0xff424242),
    pageBackground: Color(0xffEDEDED),
    profileAlertBackground: Colors.grey,
    profilePageName: Colors.blue,
    appBarIcons: Color(0xff616161),
    moreLess: Color(0xff3D5AFE),
    dialogIconContainer: Color(0xffd8defb),
    dialogIcon: Color(0xff3D5AFE),
    dialogExitIcon: Color(0xff424242),
    dialogExitContainer: Color(0xffE0E0E0),
  );

  static final dark = AppColors(
    floatingActionButtonBackground: const Color(0xff404040),
    floatingActionButtonForeground: Colors.grey.shade300,
    wB: Colors.white,
    cardBackground: const Color(0xff1E1E1E),
    subtitle: Colors.grey.shade200,
    pageBackground: const Color(0xff121212),
    profileAlertBackground: Colors.grey.shade800.withValues(alpha: .8),
    profilePageName: Colors.blue.shade100,
    appBarIcons: Colors.grey,
    moreLess: const Color(0xff90CAF9),
    dialogIconContainer: const Color(0xff404040),
    dialogIcon: Colors.white,
    dialogExitIcon: Colors.white,
    dialogExitContainer: const Color(0xff404040),
  );

  /// Safe accessor
  static AppColors of(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>();

    assert(
    colors != null,
    'AppColors extension not found. '
        'Did you forget to add it to ThemeData.extensions?',
    );

    return colors ?? light;
  }

  @override
  AppColors copyWith({
    Color? floatingActionButtonBackground,
    Color? floatingActionButtonForeground,
    Color? wB,
    Color? cardBackground,
    Color? subtitle,
    Color? pageBackground,
    Color? profileAlertBackground,
    Color? profilePageName,
    Color? appBarIcons,
    Color? moreLess,
    Color? dialogIconContainer,
    Color? dialogIcon,
    Color? dialogExitIcon,
    Color? dialogExitContainer,
  }) {
    return AppColors(
      floatingActionButtonBackground:
      floatingActionButtonBackground ??
          this.floatingActionButtonBackground,
      floatingActionButtonForeground:
      floatingActionButtonForeground ??
          this.floatingActionButtonForeground,
      wB: wB ?? this.wB,
      cardBackground: cardBackground ?? this.cardBackground,
      subtitle: subtitle ?? this.subtitle,
      pageBackground: pageBackground ?? this.pageBackground,
      profileAlertBackground:
      profileAlertBackground ?? this.profileAlertBackground,
      profilePageName: profilePageName ?? this.profilePageName,
      appBarIcons: appBarIcons ?? this.appBarIcons,
      moreLess: moreLess ?? this.moreLess,
      dialogIconContainer:
      dialogIconContainer ?? this.dialogIconContainer,
      dialogIcon: dialogIcon ?? this.dialogIcon,
      dialogExitIcon: dialogExitIcon ?? this.dialogExitIcon,
      dialogExitContainer:
      dialogExitContainer ?? this.dialogExitContainer,
    );
  }

  @override
  AppColors lerp(
      covariant ThemeExtension<AppColors>? other,
      double t,
      ) {
    if (other is! AppColors) return this;

    return AppColors(
      floatingActionButtonBackground: Color.lerp(
        floatingActionButtonBackground,
        other.floatingActionButtonBackground,
        t,
      )!,
      floatingActionButtonForeground: Color.lerp(
        floatingActionButtonForeground,
        other.floatingActionButtonForeground,
        t,
      )!,
      wB: Color.lerp(wB, other.wB, t)!,
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,
      subtitle: Color.lerp(subtitle, other.subtitle, t)!,
      pageBackground: Color.lerp(pageBackground, other.pageBackground, t)!,
      profileAlertBackground: Color.lerp(
        profileAlertBackground,
        other.profileAlertBackground,
        t,
      )!,
      profilePageName: Color.lerp(
        profilePageName,
        other.profilePageName,
        t,
      )!,
      appBarIcons: Color.lerp(
        appBarIcons,
        other.appBarIcons,
        t,
      )!,
      moreLess: Color.lerp(
        moreLess,
        other.moreLess,
        t,
      )!,
      dialogIconContainer: Color.lerp(
        dialogIconContainer,
        other.dialogIconContainer,
        t,
      )!,
      dialogIcon: Color.lerp(
        dialogIcon,
        other.dialogIcon,
        t,
      )!,
      dialogExitIcon: Color.lerp(
        dialogExitIcon,
        other.dialogExitIcon,
        t,
      )!,
      dialogExitContainer: Color.lerp(
        dialogExitContainer,
        other.dialogExitContainer,
        t,
      )!,
    );
  }
}