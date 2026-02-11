import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/music_repository.dart';
import '../../services/deezer_service.dart';
import 'track_details_event.dart';
import 'track_details_state.dart';

/// BLoC for the Track Details screen.
/// Fetches track details and lyrics in parallel.
class TrackDetailsBloc extends Bloc<TrackDetailsEvent, TrackDetailsState> {
  final MusicRepository _repository;

  TrackDetailsBloc({required MusicRepository repository})
      : _repository = repository,
        super(const TrackDetailsInitial()) {
    on<FetchTrackDetails>(_onFetchTrackDetails);
  }

  Future<void> _onFetchTrackDetails(
    FetchTrackDetails event,
    Emitter<TrackDetailsState> emit,
  ) async {
    emit(const TrackDetailsLoading());

    try {
      // Fetch track details
      final details = await _repository.getTrackDetails(event.trackId);

      // Emit loaded state with lyrics loading indicator
      emit(TrackDetailsLoaded(
        details: details,
        isLoadingLyrics: true,
      ));

      // Now fetch lyrics
      try {
        final lyrics = await _repository.getLyrics(
          trackName: event.trackName,
          artistName: event.artistName,
          albumName: event.albumName,
          duration: event.duration,
        );

        final currentState = state;
        if (currentState is TrackDetailsLoaded) {
          emit(currentState.copyWith(
            lyrics: lyrics,
            isLoadingLyrics: false,
          ));
        }
      } catch (lyricsError) {
        final currentState = state;
        if (currentState is TrackDetailsLoaded) {
          emit(currentState.copyWith(
            isLoadingLyrics: false,
            lyricsError: 'Could not load lyrics',
          ));
        }
      }
    } on NoInternetException {
      emit(const TrackDetailsError(
        message: 'NO INTERNET CONNECTION',
        isOffline: true,
      ));
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('TimeoutException')) {
        emit(const TrackDetailsError(
          message: 'NO INTERNET CONNECTION',
          isOffline: true,
        ));
      } else {
        emit(TrackDetailsError(message: e.toString()));
      }
    }
  }
}
