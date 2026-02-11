import 'package:equatable/equatable.dart';
import '../../models/track.dart';

/// States for Track Details BLoC.
abstract class TrackDetailsState extends Equatable {
  const TrackDetailsState();
  @override
  List<Object?> get props => [];
}

class TrackDetailsInitial extends TrackDetailsState {
  const TrackDetailsInitial();
}

class TrackDetailsLoading extends TrackDetailsState {
  const TrackDetailsLoading();
}

class TrackDetailsLoaded extends TrackDetailsState {
  final TrackDetails details;
  final Lyrics? lyrics;
  final bool isLoadingLyrics;
  final String? lyricsError;

  const TrackDetailsLoaded({
    required this.details,
    this.lyrics,
    this.isLoadingLyrics = false,
    this.lyricsError,
  });

  TrackDetailsLoaded copyWith({
    TrackDetails? details,
    Lyrics? lyrics,
    bool? isLoadingLyrics,
    String? lyricsError,
  }) {
    return TrackDetailsLoaded(
      details: details ?? this.details,
      lyrics: lyrics ?? this.lyrics,
      isLoadingLyrics: isLoadingLyrics ?? this.isLoadingLyrics,
      lyricsError: lyricsError,
    );
  }

  @override
  List<Object?> get props => [details, lyrics, isLoadingLyrics, lyricsError];
}

class TrackDetailsError extends TrackDetailsState {
  final String message;
  final bool isOffline;

  const TrackDetailsError({
    required this.message,
    this.isOffline = false,
  });

  @override
  List<Object?> get props => [message, isOffline];
}
