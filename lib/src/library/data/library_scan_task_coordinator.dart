import 'dart:async';

import 'library_models.dart';

final libraryScanTaskCoordinator = LibraryScanTaskCoordinator();

class LibraryScanTaskCoordinator {
  final _activeTasks = <LibraryScanTaskHandle>{};

  LibraryScanTaskHandle begin(LocalFolderScanCancellation cancellation) {
    final task = LibraryScanTaskHandle._(this, cancellation);
    _activeTasks.add(task);
    return task;
  }

  Future<void> cancelAndWaitForActiveTasks() async {
    while (_activeTasks.isNotEmpty) {
      final tasks = _activeTasks.toList(growable: false);
      for (final task in tasks) {
        task.requestCancellation();
      }
      await Future.wait(tasks.map((task) => task.completed));
    }
  }

  void _complete(LibraryScanTaskHandle task) {
    _activeTasks.remove(task);
  }
}

class LibraryScanTaskHandle {
  LibraryScanTaskHandle._(this._coordinator, this._cancellation);

  final LibraryScanTaskCoordinator _coordinator;
  final LocalFolderScanCancellation _cancellation;
  final _completion = Completer<void>();
  var _canCancel = true;

  Future<void> get completed => _completion.future;

  void updateProgress(LocalFolderRefreshProgress progress) {
    _canCancel = progress.canCancel;
  }

  void requestCancellation() {
    if (_canCancel) {
      _cancellation.cancel();
    }
  }

  void complete() {
    _coordinator._complete(this);
    _completion.complete();
  }
}
