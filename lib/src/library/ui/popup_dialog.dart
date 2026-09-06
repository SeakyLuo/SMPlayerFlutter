import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:smplayer_flutter/src/app/app_interaction_colors.dart';
import 'package:smplayer_flutter/src/app/shell_models.dart';
import 'package:smplayer_flutter/src/app/shell_widgets.dart';
import 'package:smplayer_flutter/src/app/svg_icon.dart';
import 'package:smplayer_flutter/src/app/text_icon_button.dart';
import 'package:smplayer_flutter/src/app/window_drag_provider.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/ui/page_search_history_panel.dart';

part 'popup_dialog_core.dart';
part 'popup_dialog_backdrop.dart';
part 'popup_dialog_class_names.dart';
part 'popup_dialog_close_button.dart';
part 'popup_dialog_mobile_title_bar.dart';
part 'popup_dialog_tab.dart';
part 'popup_text_dialog.dart';
part 'popup_confirm_dialog.dart';
part 'popup_input_dialog_shell.dart';
part 'popup_dialog_text_field.dart';
part 'popup_dialog_actions.dart';
part 'popup_dialog_message_content.dart';
part 'popup_dialog_colors.dart';
part 'popup_dialog_hover_tooltip.dart';

const popupDialogMobileBreakpoint = 720.0;
const popupConfirmDialogDismissDelay = Duration(milliseconds: 170);

typedef PopupDialogCloseHandler = VoidCallback;

final List<PopupDialogCloseHandler> _popupDialogCloseHandlers = [];

bool closeTopPopupDialog() {
  final closeHandler = _popupDialogCloseHandlers.lastOrNull;
  if (closeHandler == null) {
    return false;
  }
  closeHandler();
  return true;
}
