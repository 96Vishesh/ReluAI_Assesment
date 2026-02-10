import 'package:equatable/equatable.dart';

/// Lightweight track model from Deezer search results.
class Track extends Equatable {
  final int id;
  final String title;
  final String artistName;
  final String albumTitle;
  final String albumCoverSmall;
  final String albumCoverMedium;
  final int duration;

  const Track({
    required this.id,
    required this.title,
    required this.artistName,
    required this.albumTitle,
    required this.albumCoverSmall,
    required this.albumCoverMedium,
    required this.duration,
  });

  factory Track.fromJson(Map<String, dynamic> json) {
    final artist = json['artist'] as Map<String, dynamic>? ?? {};
    final album = json['album'] as Map<String, dynamic>? ?? {};
    return Track(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? 'Unknown',
      artistName: artist['name'] as String? ?? 'Unknown Artist',
      albumTitle: album['title'] as String? ?? 'Unknown Album',
      albumCoverSmall: album['cover_small'] as String? ?? '',
      albumCoverMedium: album['cover_medium'] as String? ?? '',
      duration: json['duration'] as int? ?? 0,
    );
  }

  /// Returns the first character (uppercased) for grouping.
  String get groupKey {
    if (title.isEmpty) return '#';
    final first = title[0].toUpperCase();
    if (RegExp(r'[A-Z]').hasMatch(first)) return first;
    return '#';
  }

  @override
  List<Object?> get props => [id];
}

/// Detailed track model from /track/{id} endpoint.
class TrackDetails extends Equatable {
  final int id;
  final String title;
  final String artistName;
  final String albumTitle;
  final String albumCoverBig;
  final int duration;
  final String releaseDate;
  final String previewUrl;
  final int trackPosition;
  final int diskNumber;
  final int bpm;
  final double gain;
  final List<String> contributors;

  const TrackDetails({
    required this.id,
    required this.title,
    required this.artistName,
    required this.albumTitle,
    required this.albumCoverBig,
    required this.duration,
    required this.releaseDate,
    required this.previewUrl,
    required this.trackPosition,
    required this.diskNumber,
    required this.bpm,
    required this.gain,
    required this.contributors,
  });

  factory TrackDetails.fromJson(Map<String, dynamic> json) {
    final artist = json['artist'] as Map<String, dynamic>? ?? {};
    final album = json['album'] as Map<String, dynamic>? ?? {};
    final contribs = (json['contributors'] as List<dynamic>?)
            ?.map((c) => (c as Map<String, dynamic>)['name'] as String? ?? '')
            .where((name) => name.isNotEmpty)
            .toList() ??
        [];

    return TrackDetails(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? 'Unknown',
      artistName: artist['name'] as String? ?? 'Unknown Artist',
      albumTitle: album['title'] as String? ?? 'Unknown Album',
      albumCoverBig: album['cover_big'] as String? ?? album['cover_medium'] as String? ?? '',
      duration: json['duration'] as int? ?? 0,
      releaseDate: json['release_date'] as String? ?? '',
      previewUrl: json['preview'] as String? ?? '',
      trackPosition: json['track_position'] as int? ?? 0,
      diskNumber: json['disk_number'] as int? ?? 0,
      bpm: (json['bpm'] as num?)?.toInt() ?? 0,
      gain: (json['gain'] as num?)?.toDouble() ?? 0.0,
      contributors: contribs,
    );
  }

  String get formattedDuration {
    final minutes = duration ~/ 60;
    final seconds = duration % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  List<Object?> get props => [id];
}

/// Lyrics model from LRCLIB.
class Lyrics extends Equatable {
  final String? plainLyrics;
  final String? syncedLyrics;
  final String trackName;
  final String artistName;

  const Lyrics({
    this.plainLyrics,
    this.syncedLyrics,
    required this.trackName,
    required this.artistName,
  });

  factory Lyrics.fromJson(Map<String, dynamic> json) {
    return Lyrics(
      plainLyrics: json['plainLyrics'] as String?,
      syncedLyrics: json['syncedLyrics'] as String?,
      trackName: json['trackName'] as String? ?? '',
      artistName: json['artistName'] as String? ?? '',
    );
  }

  bool get hasLyrics =>
      (plainLyrics != null && plainLyrics!.isNotEmpty) ||
      (syncedLyrics != null && syncedLyrics!.isNotEmpty);

  /// Returns display-ready lyrics text.
  String get displayLyrics {
    if (plainLyrics != null && plainLyrics!.isNotEmpty) return plainLyrics!;
    if (syncedLyrics != null && syncedLyrics!.isNotEmpty) {
      // Strip timestamp tags from synced lyrics
      return syncedLyrics!
          .split('\n')
          .map((line) => line.replaceAll(RegExp(r'\[\d+:\d+\.\d+\]'), '').trim())
          .where((line) => line.isNotEmpty)
          .join('\n');
    }
    return '';
  }

  @override
  List<Object?> get props => [trackName, artistName, plainLyrics];
}
