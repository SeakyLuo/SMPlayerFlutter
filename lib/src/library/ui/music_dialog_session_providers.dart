import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';

typedef MusicDialogSessionKey = ({Object session, int songId});

enum MusicDialogOperation {
  saveProperties,
  saveLyrics,
  importLyrics,
  changeArtwork,
  saveArtwork,
}

class MusicDialogTabState {
  const MusicDialogTabState({
    this.loading = true,
    this.dirty = false,
    this.operation,
    this.showLyricsTimestamps = true,
    this.lyricsCanToggleTimestamps = false,
    this.recommendationLoading = false,
    this.revision = 0,
  });

  final bool loading;
  final bool dirty;
  final MusicDialogOperation? operation;
  final bool showLyricsTimestamps;
  final bool lyricsCanToggleTimestamps;
  final bool recommendationLoading;
  final int revision;

  MusicDialogTabState copyWith({
    bool? loading,
    bool? dirty,
    MusicDialogOperation? operation,
    bool clearOperation = false,
    bool? showLyricsTimestamps,
    bool? lyricsCanToggleTimestamps,
    bool? recommendationLoading,
    int? revision,
  }) {
    return MusicDialogTabState(
      loading: loading ?? this.loading,
      dirty: dirty ?? this.dirty,
      operation: clearOperation ? null : operation ?? this.operation,
      showLyricsTimestamps: showLyricsTimestamps ?? this.showLyricsTimestamps,
      lyricsCanToggleTimestamps:
          lyricsCanToggleTimestamps ?? this.lyricsCanToggleTimestamps,
      recommendationLoading:
          recommendationLoading ?? this.recommendationLoading,
      revision: revision ?? this.revision,
    );
  }
}

class MusicDialogTabStateNotifier
    extends
        AutoDisposeFamilyNotifier<MusicDialogTabState, MusicDialogSessionKey> {
  @override
  MusicDialogTabState build(MusicDialogSessionKey arg) {
    return const MusicDialogTabState();
  }

  void reset() {
    state = const MusicDialogTabState();
  }

  void loaded({
    bool dirty = false,
    bool? showLyricsTimestamps,
    bool? lyricsCanToggleTimestamps,
  }) {
    state = state.copyWith(
      loading: false,
      dirty: dirty,
      clearOperation: true,
      showLyricsTimestamps: showLyricsTimestamps,
      lyricsCanToggleTimestamps: lyricsCanToggleTimestamps,
      revision: state.revision + 1,
    );
  }

  void setDirty(bool dirty) {
    if (state.dirty == dirty) {
      return;
    }
    state = state.copyWith(dirty: dirty);
  }

  void updateLyricsEditor({
    required bool dirty,
    required bool canToggleTimestamps,
    bool? showTimestamps,
    bool refresh = false,
  }) {
    final nextRevision = refresh ? state.revision + 1 : state.revision;
    if (state.dirty == dirty &&
        state.lyricsCanToggleTimestamps == canToggleTimestamps &&
        (showTimestamps == null ||
            state.showLyricsTimestamps == showTimestamps) &&
        nextRevision == state.revision) {
      return;
    }
    state = state.copyWith(
      dirty: dirty,
      lyricsCanToggleTimestamps: canToggleTimestamps,
      showLyricsTimestamps: showTimestamps,
      revision: nextRevision,
    );
  }

  void begin(MusicDialogOperation operation) {
    state = state.copyWith(operation: operation);
  }

  void finish({bool? dirty, bool refresh = false}) {
    state = state.copyWith(
      dirty: dirty,
      clearOperation: true,
      revision: refresh ? state.revision + 1 : state.revision,
    );
  }

  void refresh({bool? dirty}) {
    state = state.copyWith(dirty: dirty, revision: state.revision + 1);
  }

  void setRecommendationLoading(bool loading, {bool refresh = false}) {
    if (state.recommendationLoading == loading && !refresh) {
      return;
    }
    state = state.copyWith(
      recommendationLoading: loading,
      revision: refresh ? state.revision + 1 : state.revision,
    );
  }
}

final musicDialogPropertiesStateProvider = NotifierProvider.autoDispose.family<
  MusicDialogTabStateNotifier,
  MusicDialogTabState,
  MusicDialogSessionKey
>(MusicDialogTabStateNotifier.new);

final musicDialogLyricsStateProvider = NotifierProvider.autoDispose.family<
  MusicDialogTabStateNotifier,
  MusicDialogTabState,
  MusicDialogSessionKey
>(MusicDialogTabStateNotifier.new);

final musicDialogArtworkStateProvider = NotifierProvider.autoDispose.family<
  MusicDialogTabStateNotifier,
  MusicDialogTabState,
  MusicDialogSessionKey
>(MusicDialogTabStateNotifier.new);

final internetLyricsCandidateSearchProvider = AsyncNotifierProvider.autoDispose
    .family<
      InternetLyricsCandidateSearchNotifier,
      List<InternetLyricsCandidate>,
      MusicDialogSessionKey
    >(InternetLyricsCandidateSearchNotifier.new);

class InternetLyricsCandidateSearchNotifier
    extends
        AutoDisposeFamilyAsyncNotifier<
          List<InternetLyricsCandidate>,
          MusicDialogSessionKey
        > {
  @override
  List<InternetLyricsCandidate> build(MusicDialogSessionKey arg) => const [];

  Future<List<InternetLyricsCandidate>> search() async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref
          .read(libraryRepositoryProvider)
          .searchInternetLyricsCandidates(arg.songId),
    );
    state = result;
    return result.requireValue;
  }
}
