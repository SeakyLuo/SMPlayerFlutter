part of 'settings_page.dart';

class ToggleSettingRow extends StatelessWidget {
  const ToggleSettingRow({
    super.key,
    required this.label,
    required this.checked,
    required this.onChange,
    this.hint,
    this.enabled = true,
    this.loading = false,
  });

  final String label;
  final String? hint;
  final bool checked;
  final ValueChanged<bool> onChange;
  final bool enabled;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsPageColors.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 38),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        hoverColor: Colors.transparent,
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        onTap: enabled && !loading ? () => onChange(!checked) : null,
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: colors.textStrong,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (hint != null) ...[
                    const SizedBox(width: 8),
                    Tooltip(
                      message: hint!,
                      child: Icon(
                        FluentIcons.info_24_regular,
                        size: 16,
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            if (loading) ...[
              SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.accent,
                ),
              ),
              const SizedBox(width: 10),
            ],
            IgnorePointer(
              ignoring: !enabled || loading,
              child: Opacity(
                opacity: enabled ? 1 : 0.55,
                child: SmPlayerSwitch(
                  value: checked,
                  onChanged: onChange,
                  trackKey: const ValueKey('settings-toggle-track'),
                  thumbKey: const ValueKey('settings-toggle-thumb'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
