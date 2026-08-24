part of 'popup_dialog.dart';

class PopupDialogTextField extends StatelessWidget {
  const PopupDialogTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.autofocus = false,
    this.enabled = true,
    this.placeholder,
    this.errorText = '',
    this.onChanged,
    this.onSubmitted,
    this.onTapOutside,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool enabled;
  final String? placeholder;
  final String errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TapRegionCallback? onTapOutside;

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      enabled: enabled,
      style: TextStyle(color: colors.textStrong, fontSize: 15, height: 1.2),
      decoration: InputDecoration(
        hintText: placeholder,
        errorText: errorText.isEmpty ? null : errorText,
        filled: true,
        fillColor: enabled ? colors.fieldSurface : colors.fieldDisabledSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        constraints: const BoxConstraints(minHeight: 42),
        border: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colors.focusRing, width: 3),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      onTapOutside: onTapOutside,
    );
  }
}
