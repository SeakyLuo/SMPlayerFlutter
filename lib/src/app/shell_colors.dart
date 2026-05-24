import 'package:flutter/material.dart';

class ShellColors {
  const ShellColors._();

  static const bodyHighlight = Color(0xd1ffffff);
  static const bodyTop = Color(0xfff6f8fb);
  static const bodyBottom = Color(0xffedf2f7);
  static const workspaceSurface = Color(0xbdfafcff);
  static const workspaceSolidSurface = Color(0xfffafcff);
  static const workspaceShadow = Color(0x2e2f425c);
  static const navigationOverlaySurface = Color(0xfff8fbfe);
  static const navigationOverlayShadow = Color(0x2e2a384e);
  static const navigationMinimalShadow = Color(0x33363046);
  static const headerText = Color(0xff1f2933);
  static const nightBodyHighlight = Color(0x1a5f9ed1);
  static const nightBodyTop = Color(0xff111317);
  static const nightBodyBottom = Color(0xff1a2028);
  static const nightWorkspaceSurface = Color(0xff141a21);
  static const nightWorkspaceShadow = Color(0x66000000);
  static const nightNavigationOverlaySurface = Color(0xf5101419);
  static const nightNavigationOverlayShadow = Color(0x5c000000);
  static const nightNavigationMinimalShadow = Color(0x61000000);
  static const nightHeaderText = Color(0xffe8edf5);
}

@immutable
class ShellThemeColors extends ThemeExtension<ShellThemeColors> {
  const ShellThemeColors({
    required this.bodyHighlight,
    required this.bodyTop,
    required this.bodyBottom,
    required this.workspaceSurface,
    required this.workspaceSolidSurface,
    required this.workspaceShadow,
    required this.navigationOverlaySurface,
    required this.navigationOverlayShadow,
    required this.navigationMinimalShadow,
    required this.headerText,
  });

  final Color bodyHighlight;
  final Color bodyTop;
  final Color bodyBottom;
  final Color workspaceSurface;
  final Color workspaceSolidSurface;
  final Color workspaceShadow;
  final Color navigationOverlaySurface;
  final Color navigationOverlayShadow;
  final Color navigationMinimalShadow;
  final Color headerText;

  static const light = ShellThemeColors(
    bodyHighlight: ShellColors.bodyHighlight,
    bodyTop: ShellColors.bodyTop,
    bodyBottom: ShellColors.bodyBottom,
    workspaceSurface: ShellColors.workspaceSurface,
    workspaceSolidSurface: ShellColors.workspaceSolidSurface,
    workspaceShadow: ShellColors.workspaceShadow,
    navigationOverlaySurface: ShellColors.navigationOverlaySurface,
    navigationOverlayShadow: ShellColors.navigationOverlayShadow,
    navigationMinimalShadow: ShellColors.navigationMinimalShadow,
    headerText: ShellColors.headerText,
  );

  static const dark = ShellThemeColors(
    bodyHighlight: ShellColors.nightBodyHighlight,
    bodyTop: ShellColors.nightBodyTop,
    bodyBottom: ShellColors.nightBodyBottom,
    workspaceSurface: ShellColors.nightWorkspaceSurface,
    workspaceSolidSurface: ShellColors.nightWorkspaceSurface,
    workspaceShadow: ShellColors.nightWorkspaceShadow,
    navigationOverlaySurface: ShellColors.nightNavigationOverlaySurface,
    navigationOverlayShadow: ShellColors.nightNavigationOverlayShadow,
    navigationMinimalShadow: ShellColors.nightNavigationMinimalShadow,
    headerText: ShellColors.nightHeaderText,
  );

  static ShellThemeColors of(BuildContext context) {
    return Theme.of(context).extension<ShellThemeColors>()!;
  }

  @override
  ShellThemeColors copyWith({
    Color? bodyHighlight,
    Color? bodyTop,
    Color? bodyBottom,
    Color? workspaceSurface,
    Color? workspaceSolidSurface,
    Color? workspaceShadow,
    Color? navigationOverlaySurface,
    Color? navigationOverlayShadow,
    Color? navigationMinimalShadow,
    Color? headerText,
  }) {
    return ShellThemeColors(
      bodyHighlight: bodyHighlight ?? this.bodyHighlight,
      bodyTop: bodyTop ?? this.bodyTop,
      bodyBottom: bodyBottom ?? this.bodyBottom,
      workspaceSurface: workspaceSurface ?? this.workspaceSurface,
      workspaceSolidSurface:
          workspaceSolidSurface ?? this.workspaceSolidSurface,
      workspaceShadow: workspaceShadow ?? this.workspaceShadow,
      navigationOverlaySurface:
          navigationOverlaySurface ?? this.navigationOverlaySurface,
      navigationOverlayShadow:
          navigationOverlayShadow ?? this.navigationOverlayShadow,
      navigationMinimalShadow:
          navigationMinimalShadow ?? this.navigationMinimalShadow,
      headerText: headerText ?? this.headerText,
    );
  }

  @override
  ShellThemeColors lerp(ThemeExtension<ShellThemeColors>? other, double t) {
    if (other is! ShellThemeColors) {
      return this;
    }
    return ShellThemeColors(
      bodyHighlight: Color.lerp(bodyHighlight, other.bodyHighlight, t)!,
      bodyTop: Color.lerp(bodyTop, other.bodyTop, t)!,
      bodyBottom: Color.lerp(bodyBottom, other.bodyBottom, t)!,
      workspaceSurface:
          Color.lerp(workspaceSurface, other.workspaceSurface, t)!,
      workspaceSolidSurface:
          Color.lerp(workspaceSolidSurface, other.workspaceSolidSurface, t)!,
      workspaceShadow: Color.lerp(workspaceShadow, other.workspaceShadow, t)!,
      navigationOverlaySurface:
          Color.lerp(
            navigationOverlaySurface,
            other.navigationOverlaySurface,
            t,
          )!,
      navigationOverlayShadow:
          Color.lerp(
            navigationOverlayShadow,
            other.navigationOverlayShadow,
            t,
          )!,
      navigationMinimalShadow:
          Color.lerp(
            navigationMinimalShadow,
            other.navigationMinimalShadow,
            t,
          )!,
      headerText: Color.lerp(headerText, other.headerText, t)!,
    );
  }
}
