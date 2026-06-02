import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

const artworkOverlayGlassColor = Color(0xc8121720);
const artworkOverlayGlassOpacityMultiplier = 0.55;

const artworkOverlayGlassSettings = LiquidGlassSettings(
  glassColor: artworkOverlayGlassColor,
  thickness: 10,
  blur: 20,
  chromaticAberration: 0,
  lightIntensity: 0.1,
  ambientStrength: 0.08,
  refractiveIndex: 1.06,
  saturation: 1.65,
  glowIntensity: 0.04,
  standardOpacityMultiplier: artworkOverlayGlassOpacityMultiplier,
);
