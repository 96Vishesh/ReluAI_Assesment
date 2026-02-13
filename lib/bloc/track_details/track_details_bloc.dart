import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/track.dart';
import '../../repositories/music_repository.dart';
import '../../services/deezer_service.dart';
import 'track_details_event.dart';
import 'track_details_state.dart';

/// BLoC for the Track Details screen.
/// Fetches track details and lyrics in parallel.
/// Handles generated tracks (id >= 900000000) by building details from
/// the Track data available from the library instead of calling Deezer.
class TrackDetailsBloc extends Bloc<TrackDetailsEvent, TrackDetailsState> {
  final MusicRepository _repository;

  /// IDs at or above this threshold are generated (not real Deezer tracks).
  static const int _generatedIdThreshold = 900000000;

  TrackDetailsBloc({required MusicRepository repository})
      : _repository = repository,
        super(const TrackDetailsInitial()) {
    on<FetchTrackDetails>(_onFetchTrackDetails);
  }

  /// Check if a track ID belongs to a generated track.
  bool _isGeneratedTrack(int trackId) => trackId >= _generatedIdThreshold;

  /// Build TrackDetails from the event data when Deezer API can't be used.
  TrackDetails _buildDetailsFromEvent(FetchTrackDetails event) {
    return TrackDetails(
      id: event.trackId,
      title: event.trackName,
      artistName: event.artistName,
      albumTitle: event.albumName,
      albumCoverBig: event.albumCoverUrl ?? '',
      duration: event.duration,
      releaseDate: '',
      previewUrl: '',
      trackPosition: 0,
      diskNumber: 0,
      bpm: 0,
      gain: 0.0,
      contributors: [],
    );
  }

  Future<void> _onFetchTrackDetails(
    FetchTrackDetails event,
    Emitter<TrackDetailsState> emit,
  ) async {
    emit(const TrackDetailsLoading());

    try {
      TrackDetails details;

      if (_isGeneratedTrack(event.trackId)) {
        // Generated track: build details from event data (no Deezer call)
        details = _buildDetailsFromEvent(event);
      } else {
        // Real track: fetch from Deezer API
        try {
          details = await _repository.getTrackDetails(event.trackId);
        } catch (e) {
          if (e is NoInternetException) rethrow;
          if (e.toString().contains('SocketException') ||
              e.toString().contains('TimeoutException')) {
            rethrow;
          }
          // If Deezer details fail for a real track, fall back to event data
          details = _buildDetailsFromEvent(event);
        }
      }

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
