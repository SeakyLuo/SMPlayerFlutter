import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

const immersiveModePlayerHeight = 120.0;
const immersiveModePlayerTopRadius = 18.0;
const immersiveModeLayoutCompactBreakpoint = 760.0;
const immersiveModeImmersiveCompactBreakpoint = 800.0;
const immersiveModeQueueRowHeight = 78.0;

const immersiveModeMiniModeWindowSize = Size(360, 360);

const immersiveModeTopButtonGlassSettings = LiquidGlassSettings(
  blur: 46,
  thickness: 24,
  refractiveIndex: 1.06,
  saturation: 1.9,
  chromaticAberration: 0,
  lightIntensity: 0.16,
  ambientStrength: 0.12,
  glowIntensity: 0.1,
  glassColor: Color(0x52ffffff),
  standardOpacityMultiplier: 0.5,
);

const immersiveModeTopButtonNightGlassSettings = LiquidGlassSettings(
  blur: 38,
  thickness: 18,
  refractiveIndex: 1.04,
  saturation: 1.45,
  chromaticAberration: 0,
  lightIntensity: 0.08,
  ambientStrength: 0.08,
  glowIntensity: 0.04,
  glassColor: Color(0x18ffffff),
  standardOpacityMultiplier: 0.28,
);
