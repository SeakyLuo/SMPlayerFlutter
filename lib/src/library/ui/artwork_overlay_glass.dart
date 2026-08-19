import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

const artworkOverlayGlassColor = Color(0x9e040507);
const artworkOverlayGlassOpacityMultiplier = 0.42;
const artworkOverlayBorderColor = Color(0x38ffffff);
const artworkOverlayGlowColor = Color(0x59ffffff);
const artworkOverlayGlowRadiusFactor = 0.62;

const artworkOverlayGlassSettings = LiquidGlassSettings(
  glassColor: artworkOverlayGlassColor,
  thickness: 10,
  blur: 10,
  chromaticAberration: 0,
  lightIntensity: 0.2,
  ambientStrength: 0.16,
  refractiveIndex: 1.1,
  saturation: 2,
  glowIntensity: 0.3,
  standardOpacityMultiplier: artworkOverlayGlassOpacityMultiplier,
);
