import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';

class PopupDialog extends StatelessWidget {
  const PopupDialog({
    super.key,
    required this.navLabel,
    required this.onClose,
    required this.navChildren,
    required this.child,
    this.className = '',
    this.navClassName = '',
    this.ariaLabel,
    this.overlayClassName = '',
    this.afterNav,
    this.footer,
    this.closeOnBackdrop = false,
    this.width = 780,
    this.height = 760,
  });

  final String className;
  final String navClassName;
  final String navLabel;
  final String? ariaLabel;
  final String overlayClassName;
  final List<Widget> navChildren;
  final Widget? afterNav;
  final Widget child;
  final Widget? footer;
  final VoidCallback onClose;
  final bool closeOnBackdrop;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;

    return Material(
      color: Colors.transparent,
      child: Semantics(
        label: ariaLabel ?? navLabel,
        namesRoute: true,
        scopesRoute: true,
        explicitChildNodes: true,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: closeOnBackdrop ? onClose : null,
              child: const DecoratedBox(
                decoration: BoxDecoration(color: PopupDialogColors.overlay),
              ),
            ),
            Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: width,
                    maxHeight: height,
                  ),
                  child: FractionallySizedBox(
                    widthFactor: 1,
                    heightFactor: 1,
                    child: Container(
                      margin: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: PopupDialogColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: PopupDialogColors.border),
                        boxShadow: const [
                          BoxShadow(
                            color: PopupDialogColors.shadow,
                            blurRadius: 80,
                            offset: Offset(0, 26),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          Semantics(
                            label: navLabel,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                28,
                                22,
                                28,
                                18,
                              ),
                              child: Row(
                                children: [
                                  ...navChildren,
                                  const Spacer(),
                                  Tooltip(
                                    message: i18n.t('common.close'),
                                    child: IconButton(
                                      style: IconButton.styleFrom(
                                        fixedSize: const Size.square(42),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          side: const BorderSide(
                                            color:
                                                PopupDialogColors.buttonBorder,
                                          ),
                                        ),
                                        backgroundColor:
                                            PopupDialogColors.buttonSurface,
                                      ),
                                      icon: const Icon(
                                        FluentIcons.dismiss_20_regular,
                                        size: 18,
                                      ),
                                      onPressed: onClose,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (afterNav != null) afterNav!,
                          Expanded(child: child),
                          if (footer != null) footer!,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PopupDialogTab extends StatelessWidget {
  const PopupDialogTab({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
    this.first = false,
    this.last = false,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        fixedSize: const Size(138, 40),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        foregroundColor:
            selected ? PopupDialogColors.accent : PopupDialogColors.text,
        backgroundColor:
            selected
                ? PopupDialogColors.activeButtonSurface
                : PopupDialogColors.buttonSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(
            left: first ? const Radius.circular(8) : Radius.zero,
            right: last ? const Radius.circular(8) : Radius.zero,
          ),
          side: BorderSide(
            color:
                selected
                    ? PopupDialogColors.activeButtonBorder
                    : PopupDialogColors.buttonBorder,
          ),
        ),
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

Future<String?> showPopupTextDialog({
  required BuildContext context,
  required String title,
  required String initialValue,
  required String confirmLabel,
}) {
  final controller = TextEditingController(text: initialValue);

  return showDialog<String>(
    context: context,
    barrierColor: Colors.transparent,
    builder: (dialogContext) {
      final i18n = dialogContext.smPlayerI18n;

      return PopupDialog(
        navLabel: title,
        ariaLabel: title,
        width: 520,
        height: 260,
        onClose: () {
          Navigator.of(dialogContext).pop();
        },
        navChildren: [
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: PopupDialogColors.textStrong,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
        footer: Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                child: Text(i18n.t('common.cancel')),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(controller.text.trim());
                },
                child: Text(confirmLabel),
              ),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 18),
          child: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (value) {
              Navigator.of(dialogContext).pop(value);
            },
          ),
        ),
      );
    },
  ).whenComplete(controller.dispose);
}

class PopupDialogColors {
  const PopupDialogColors._();

  static const overlay = Color(0x3d181e26);
  static const surface = Color(0xfafbfcff);
  static const border = Color(0x80b9c3d2);
  static const shadow = Color(0x47232d3c);
  static const buttonSurface = Color(0xebffffff);
  static const activeButtonSurface = Color(0xf5eff6ff);
  static const buttonBorder = Color(0x9ebec8d6);
  static const activeButtonBorder = Color(0x610078d7);
  static const accent = Color(0xff0063b1);
  static const accentSoft = Color(0x290078d7);
  static const text = Color(0xff273142);
  static const textStrong = Color(0xff111827);
  static const textMuted = Color(0xff5b697a);
  static const fieldSurface = Color(0xe6ffffff);
  static const fieldDisabledSurface = Color(0xade6ebf3);
}
