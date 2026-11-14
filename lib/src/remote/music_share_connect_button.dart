import 'package:flutter/material.dart';
import '../app/text_icon_button.dart';

class MusicShareConnectButton extends StatelessWidget {
  const MusicShareConnectButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.loading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool enabled;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => SmPlayerTextIconButton(
    label: label,
    icon: icon,
    height: 42,
    minWidth: 88,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    fontVariations: const [],
    horizontalPadding: 16,
    glassEnabled: false,
    disabled: !enabled,
    loading: loading,
    onPressed: onPressed,
  );
}
