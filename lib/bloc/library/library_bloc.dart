import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/music_repository.dart';
import '../../services/deezer_service.dart';
import 'library_event.dart';
import 'library_state.dart';

/// BLoC for the Library screen.
/// Handles track loading, pagination, search, and grouping.
class LibraryBloc extends Bloc<LibraryEvent, LibraryState> {
  final MusicRepository _repository;
  Timer? _debounceTimer;
  bool _isFetching = false;

  LibraryBloc({required MusicRepository repository})
      : _repository = repository,
        super(const LibraryInitial()) {
    on<LoadTracks>(_onLoadTracks);
    on<LoadMoreTracks>(_onLoadMoreTracks);
    on<SearchTracks>(_onSearchTracks);
    on<ClearSearch>(_onClearSearch);
  }

  Future<void> _onLoadTracks(
    LoadTracks event,
    Emitter<LibraryState> emit,
  ) async {
    emit(const LibraryLoading());

    try {
      // Fetch initial bulk of pages for fast start.
      // With playlist-based fetching, each page can yield 50-100 tracks.
      await _repository.fetchBulk(10);

      final allTracks = _repository.allTracks;
      final grouped = MusicRepository.groupTracks(allTracks);

      emit(LibraryLoaded(
        allTracks: allTracks,
        displayTracks: allTracks,
        groupedTracks: grouped,
        hasMore: _repository.hasMore,
        totalLoaded: _repository.totalTracks,
      ));

      // Continue loading more in background within the same emitter scope.
      // This keeps the emitter valid since we're still inside the handler.
      for (int i = 0; i < 20 && _repository.hasMore; i++) {
        try {
          await _repository.fetchBulk(5);
        } catch (_) {
          break;
        }

        final currentState = state;
        if (currentState is LibraryLoaded && currentState.searchQuery.isEmpty) {
          final updatedTracks = _repository.allTracks;
          final updatedGrouped = MusicRepository.groupTracks(updatedTracks);
          emit(currentState.copyWith(
            allTracks: updatedTracks,
            displayTracks: updatedTracks,
            groupedTracks: updatedGrouped,
            totalLoaded: _repository.totalTracks,
            hasMore: _repository.hasMore,
          ));
        }
      }
    } on NoInternetException {
      emit(const LibraryError(
        message: 'NO INTERNET CONNECTION',
        isOffline: true,
      ));
    } catch (e) {
      emit(LibraryError(message: e.toString()));
    }
  }

  Future<void> _onLoadMoreTracks(
    LoadMoreTracks event,
    Emitter<LibraryState> emit,
  ) async {
    final currentState = state;
    if (currentState is! LibraryLoaded ||
        currentState.isLoadingMore ||
        !currentState.hasMore ||
        _isFetching) {
      return;
    }

    _isFetching = true;
    emit(currentState.copyWith(isLoadingMore: true));

    try {
      await _repository.fetchBulk(5);

      final allTracks = _repository.allTracks;
      final displayTracks = currentState.searchQuery.isNotEmpty
          ? await MusicRepository.searchTracksInBackground(
              allTracks, currentState.searchQuery)
          : allTracks;
      final grouped = MusicRepository.groupTracks(displayTracks);

      emit(currentState.copyWith(
        allTracks: allTracks,
        displayTracks: displayTracks,
        groupedTracks: grouped,
        isLoadingMore: false,
        hasMore: _repository.hasMore,
        totalLoaded: _repository.totalTracks,
      ));
    } on NoInternetException {
      emit(currentState.copyWith(isLoadingMore: false));
    } catch (e) {
      emit(currentState.copyWith(isLoadingMore: false));
    } finally {
      _isFetching = false;
    }
  }

  Future<void> _onSearchTracks(
    SearchTracks event,
    Emitter<LibraryState> emit,
  ) async {
    final currentState = state;
    if (currentState is! LibraryLoaded) return;

    // Debounce search
    _debounceTimer?.cancel();

    final completer = Completer<void>();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      final query = event.query.trim();

      if (query.isEmpty) {
        final grouped = MusicRepository.groupTracks(currentState.allTracks);
        emit(currentState.copyWith(
          displayTracks: currentState.allTracks,
          groupedTracks: grouped,
          searchQuery: '',
        ));
      } else {
        // Run search on background isolate
        final filtered = await MusicRepository.searchTracksInBackground(
          currentState.allTracks,
          query,
        );
        final grouped = MusicRepository.groupTracks(filtered);
        emit(currentState.copyWith(
          displayTracks: filtered,
          groupedTracks: grouped,
          searchQuery: query,
        ));
      }
      completer.complete();
    });

    await completer.future;
  }

  Future<void> _onClearSearch(
    ClearSearch event,
    Emitter<LibraryState> emit,
  ) async {
    final currentState = state;
    if (currentState is! LibraryLoaded) return;

    _debounceTimer?.cancel();
    final grouped = MusicRepository.groupTracks(currentState.allTracks);
    emit(currentState.copyWith(
      displayTracks: currentState.allTracks,
      groupedTracks: grouped,
      searchQuery: '',
    ));
  }

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    return super.close();
  }
}
