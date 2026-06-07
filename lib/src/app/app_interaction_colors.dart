import 'package:flutter/material.dart';

class GlobalUI {
  const GlobalUI._();

  static const hoverBgColorDay = Color(0xffeaf6ff);
  static const hoverBgColorNight = Color(0x290078d7);
  static const hoverBorderColorDay = Color(0x260078d7);
  static const hoverBorderColorNight = Color(0x380078d7);
  static const selectedBgColorDay = Color(0xffd9ecfb);
  static const selectedBgColorNight = Color(0x330078d7);
  static const selectedBorderColorDay = hoverBorderColorDay;
  static const selectedBorderColorNight = hoverBorderColorNight;
  static const hoverShadowColorDay = Color(0x180078d7);
  static const hoverShadowColorNight = Color(0x26000000);
  static const selectedShadowColorDay = Color(0x300078d7);
  static const selectedShadowColorNight = Color(0x24000000);
  static const buttonHoverBgColorDay = hoverBgColorDay;
  static const buttonHoverBgColorNight = hoverBgColorNight;
  static const buttonHoverBorderColorDay = hoverBorderColorDay;
  static const buttonHoverBorderColorNight = hoverBorderColorNight;
  static const readOnlyFieldBgColorDay = Color(0xade6ebf3);
  static const readOnlyFieldBgColorNight = Color(0x08ffffff);
  static const readOnlyFieldBorderColorDay = Color(0x46bec8d6);
  static const readOnlyFieldBorderColorNight = Color(0x18d6e0ec);
  static const readOnlyFieldInsetHighlightDay = Color(0x2effffff);
  static const readOnlyFieldInsetHighlightNight = Color(0x00ffffff);
  static const hoverShadowDay = BoxShadow(
    color: hoverShadowColorDay,
    offset: Offset(0, 10),
    blurRadius: 24,
  );
  static const hoverShadowNight = BoxShadow(
    color: hoverShadowColorNight,
    offset: Offset(0, 10),
    blurRadius: 24,
  );
  static const selectedShadowDay = BoxShadow(
    color: selectedShadowColorDay,
    offset: Offset(0, 8),
    blurRadius: 18,
  );
  static const selectedShadowNight = BoxShadow(
    color: selectedShadowColorNight,
    offset: Offset(0, 10),
    blurRadius: 24,
  );
  static const sourceListSelectedBgColor = Color(0x1f0078d7);
  static const sourceListSelectedBorderColor = Color(0x700078d7);
  static const sourceListSelectedShadow = <BoxShadow>[];
  static const sourceListMobileSelectedBgColor = Color(0x140078d7);
  static const sourceListMobileSelectedBorderColor = Color(0x290078d7);
  static const sourceListMobileSelectedShadow = [
    BoxShadow(color: Color(0x1a1d2a3c), offset: Offset(0, 8), blurRadius: 18),
    BoxShadow(
      color: sourceListMobileSelectedBorderColor,
      spreadRadius: 1,
      blurStyle: BlurStyle.inner,
    ),
  ];
}

class SmPlayerInteractionColors {
  const SmPlayerInteractionColors._();

  static const hoverSurface = GlobalUI.hoverBgColorDay;
  static const hoverSurfaceDark = GlobalUI.hoverBgColorNight;
}
