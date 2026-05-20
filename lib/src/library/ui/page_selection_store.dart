class PageSelectionState<T> {
  const PageSelectionState({
    required this.multiSelect,
    required this.selectedItems,
    this.selectionAnchor,
  });

  const PageSelectionState.empty()
    : multiSelect = false,
      selectedItems = const {},
      selectionAnchor = null;

  final bool multiSelect;
  final Set<T> selectedItems;
  final T? selectionAnchor;

  PageSelectionState<T> copyWith({
    bool? multiSelect,
    Set<T>? selectedItems,
    T? selectionAnchor,
  }) {
    return PageSelectionState<T>(
      multiSelect: multiSelect ?? this.multiSelect,
      selectedItems: selectedItems ?? this.selectedItems,
      selectionAnchor: selectionAnchor ?? this.selectionAnchor,
    );
  }
}

class PageSelectionController<T> {
  PageSelectionController() : _storageKey = null;

  PageSelectionController.stored(String storageKey) : _storageKey = storageKey {
    final storedState = _storedStates[storageKey];
    if (storedState != null) {
      _state = PageSelectionState<T>(
        multiSelect: storedState.multiSelect,
        selectedItems: storedState.selectedItems.cast<T>().toSet(),
        selectionAnchor: storedState.selectionAnchor as T?,
      );
    }
  }

  static final _storedStates = <String, PageSelectionState<dynamic>>{};

  static void clearStoredStates() {
    _storedStates.clear();
  }

  final String? _storageKey;
  PageSelectionState<T> _state = PageSelectionState<T>(
    multiSelect: false,
    selectedItems: <T>{},
  );

  PageSelectionState<T> get state => _state;

  bool get multiSelect => _state.multiSelect;

  Set<T> get selectedItems => _state.selectedItems;

  int get selectedCount => _state.selectedItems.length;

  bool isSelected(T item) {
    return _state.selectedItems.contains(item);
  }

  void enterMultiSelect() {
    _state = _state.copyWith(multiSelect: true);
    _save();
  }

  void cancel() {
    _state = PageSelectionState<T>(multiSelect: false, selectedItems: <T>{});
    _save();
  }

  void clearSelection() {
    _state = _state.copyWith(selectedItems: <T>{});
    _save();
  }

  void toggle(T item) {
    final nextSelectedItems = {..._state.selectedItems};
    if (nextSelectedItems.contains(item)) {
      nextSelectedItems.remove(item);
    } else {
      nextSelectedItems.add(item);
    }
    _state = _state.copyWith(
      multiSelect: true,
      selectedItems: nextSelectedItems,
      selectionAnchor: item,
    );
    _save();
  }

  void selectSingle(T item) {
    _state = _state.copyWith(selectedItems: {item}, selectionAnchor: item);
    _save();
  }

  void selectWithModifiers(
    T item,
    Iterable<T> orderedItems, {
    required bool extendSelection,
    required bool rangeSelection,
  }) {
    if (!extendSelection && !rangeSelection) {
      selectSingle(item);
      return;
    }

    final selectionAnchor = _state.selectionAnchor;
    final orderedItemsList = orderedItems.toList();
    if (rangeSelection && selectionAnchor != null) {
      final anchorIndex = orderedItemsList.indexOf(selectionAnchor);
      final targetIndex = orderedItemsList.indexOf(item);
      if (anchorIndex < 0 || targetIndex < 0) {
        toggle(item);
        return;
      }

      final startIndex = anchorIndex < targetIndex ? anchorIndex : targetIndex;
      final endIndex = anchorIndex < targetIndex ? targetIndex : anchorIndex;
      _state = _state.copyWith(
        multiSelect: true,
        selectedItems:
            orderedItemsList.sublist(startIndex, endIndex + 1).toSet(),
      );
      _save();
      return;
    }

    toggle(item);
  }

  void selectAll(Iterable<T> items) {
    _state = _state.copyWith(multiSelect: true, selectedItems: items.toSet());
    _save();
  }

  void reverseSelection(Iterable<T> items) {
    final selectedItems = _state.selectedItems;
    _state = _state.copyWith(
      multiSelect: true,
      selectedItems:
          items.where((item) => !selectedItems.contains(item)).toSet(),
    );
    _save();
  }

  void hideAfterOperation(bool hideMultiSelectCommandBarAfterOperation) {
    if (hideMultiSelectCommandBarAfterOperation) {
      cancel();
    }
  }

  void _save() {
    final storageKey = _storageKey;
    if (storageKey == null) {
      return;
    }

    _storedStates[storageKey] = PageSelectionState<dynamic>(
      multiSelect: _state.multiSelect,
      selectedItems: _state.selectedItems.cast<dynamic>().toSet(),
      selectionAnchor: _state.selectionAnchor,
    );
  }
}
