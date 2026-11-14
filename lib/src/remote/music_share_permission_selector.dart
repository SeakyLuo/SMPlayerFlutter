import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../app/text_icon_button.dart';
import '../i18n/app_i18n.dart';
import '../library/ui/menu_flyout.dart';

class MusicSharePermissionSelector extends StatelessWidget {
  const MusicSharePermissionSelector({
    super.key,
    required this.canWrite,
    required this.onChanged,
    this.enabled = true,
    this.loading = false,
  });

  final bool canWrite;
  final ValueChanged<bool> onChanged;
  final bool enabled;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    return SmPlayerTextIconButton(
      label: i18n.t(canWrite ? 'share.readWrite' : 'share.readOnly'),
      trailingIcon: FluentIcons.chevron_down_20_regular,
      height: 36,
      minWidth: 88,
      glassEnabled: false,
      disabled: !enabled,
      loading: loading,
      onPressed:
          () => showMenuFlyout(
            context,
            items: [
              for (final write in [false, true])
                MenuFlyoutItem(
                  key: write ? 'read-write' : 'read-only',
                  text: i18n.t(write ? 'share.readWrite' : 'share.readOnly'),
                  checked: canWrite == write,
                  disabled: canWrite == write,
                  onPressed: () => onChanged(write),
                ),
            ],
          ),
    );
  }
}
