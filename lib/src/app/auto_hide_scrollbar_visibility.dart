import 'dart:async';

import 'package:flutter/widgets.dart';

mixin AutoHideScrollbarVisibility<T extends StatefulWidget> on State<T> {
  static const autoHideScrollbarDelay = Duration(milliseconds: 700);

  var _scrollbarVisible = false;
  var _scrollbarHovered = false;
  var _scrollbarDragging = false;
  Timer? _scrollbarHideTimer;

  bool get autoHideScrollbarVisible =>
      _scrollbarVisible || _scrollbarHovered || _scrollbarDragging;

  bool get autoHideScrollbarExpanded => _scrollbarHovered || _scrollbarDragging;

  void showAutoHideScrollbar() {
    _scrollbarHideTimer?.cancel();
    if (!_scrollbarVisible) {
      setState(() {
        _scrollbarVisible = true;
      });
    }
    scheduleAutoHideScrollbar();
  }

  void setAutoHideScrollbarHovered(bool hovered) {
    if (_scrollbarHovered == hovered) {
      return;
    }
    _scrollbarHideTimer?.cancel();
    setState(() {
      _scrollbarHovered = hovered;
      if (hovered) {
        _scrollbarVisible = true;
      }
    });
    if (!hovered) {
      scheduleAutoHideScrollbar();
    }
  }

  void beginAutoHideScrollbarDrag() {
    _scrollbarHideTimer?.cancel();
    setState(() {
      _scrollbarDragging = true;
      _scrollbarVisible = true;
    });
  }

  void endAutoHideScrollbarDrag() {
    if (!_scrollbarDragging) {
      return;
    }
    setState(() {
      _scrollbarDragging = false;
    });
    scheduleAutoHideScrollbar();
  }

  void scheduleAutoHideScrollbar() {
    _scrollbarHideTimer?.cancel();
    if (_scrollbarHovered || _scrollbarDragging) {
      return;
    }
    _scrollbarHideTimer = Timer(autoHideScrollbarDelay, () {
      if (!mounted || _scrollbarHovered || _scrollbarDragging) {
        return;
      }
      setState(() {
        _scrollbarVisible = false;
      });
    });
  }

  @override
  void dispose() {
    _scrollbarHideTimer?.cancel();
    super.dispose();
  }
}
