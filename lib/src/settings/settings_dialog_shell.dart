import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/settings/settings_colors.dart';

class SettingsDialogHeader extends StatelessWidget {
  const SettingsDialogHeader({
    super.key,
    required this.title,
    required this.onClose,
  });

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsPageColors.of(context);
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: colors.textStrong,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: context.smPlayerI18n.t('common.close'),
            onPressed: onClose,
            icon: const Icon(FluentIcons.dismiss_24_regular),
          ),
        ],
      ),
    );
  }
}

class SettingsDialogOverlay extends StatelessWidget {
  const SettingsDialogOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsPageColors.of(context);
    return SizedBox.expand(
      child: Material(color: colors.overlay, child: Center(child: child)),
    );
  }
}
