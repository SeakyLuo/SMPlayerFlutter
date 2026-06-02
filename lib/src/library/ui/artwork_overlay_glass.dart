import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

const artworkOverlayGlassColor = Color(0x9e040507);
const artworkOverlayGlassOpacityMultiplier = 0.42;
const artworkOverlayGlowColor = Color(0x59ffffff);
const artworkOverlayGlowRadiusFactor = 0.62;

const artworkOverlayGlassSettings = LiquidGlassSettings(
  glassColor: artworkOverlayGlassColor,
  thickness: 24,
  blur: 54,
  chromaticAberration: 0,
  lightIntensity: 0.24,
  ambientStrength: 0.16,
  refractiveIndex: 1.1,
  saturation: 1.72,
  glowIntensity: 0.22,
  standardOpacityMultiplier: artworkOverlayGlassOpacityMultiplier,
);
