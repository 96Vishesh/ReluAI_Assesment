import 'package:equatable/equatable.dart';

/// Events for Track Details BLoC.
abstract class TrackDetailsEvent extends Equatable {
  const TrackDetailsEvent();
  @override
  List<Object?> get props => [];
}

class FetchTrackDetails extends TrackDetailsEvent {
  final int trackId;
  final String trackName;
  final String artistName;
  final String albumName;
  final int duration;
  final String? albumCoverUrl;

  const FetchTrackDetails({
    required this.trackId,
    required this.trackName,
    required this.artistName,
    required this.albumName,
    required this.duration,
    this.albumCoverUrl,
  });

  @override
  List<Object?> get props => [trackId];
}
