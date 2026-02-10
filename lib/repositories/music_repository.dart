import 'dart:async';
import 'dart:isolate';
import '../models/track.dart';
import '../services/deezer_service.dart';
import '../services/lyrics_service.dart';

/// Repository that coordinates data fetching and manages paging state.
/// Uses multi-query rotation to accumulate 50k+ unique tracks.
class MusicRepository {
  final DeezerService _deezerService;
  final LyricsService _lyricsService;

  /// All unique tracks accumulated so far, keyed by ID.
  final Map<int, Track> _trackCache = {};

  /// Query rotation: a-z, 0-9, common terms for broader coverage.
  static const List<String> _queries = [
    'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j',
    'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't',
    'u', 'v', 'w', 'x', 'y', 'z',
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
    'love', 'night', 'baby', 'heart', 'dream', 'fire',
    'sun', 'rain', 'dance', 'rock', 'blue', 'star',
  ];

  /// Current position in the query rotation.
  int _currentQueryIndex = 0;

  /// Current page offset for the active query.
  int _currentPageIndex = 0;

  /// Max pages per query before rotating.
  static const int _maxPagesPerQuery = 40; // 40 * 50 = 2000 per query

  /// Page size for Deezer API.
  static const int _pageSize = 50;

  /// Whether there are more pages available.
  bool _hasMore = true;

  MusicRepository({
    DeezerService? deezerService,
    LyricsService? lyricsService,
  })  : _deezerService = deezerService ?? DeezerService(),
        _lyricsService = lyricsService ?? LyricsService();

  /// Get all cached tracks as a sorted list.
  List<Track> get allTracks {
    final list = _trackCache.values.toList();
    list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return list;
  }

  /// Total count of unique tracks loaded.
  int get totalTracks => _trackCache.length;

  /// Whether more tracks can be fetched.
  bool get hasMore => _hasMore;

  /// Fetch the next page of tracks. Returns the new tracks added.
  Future<List<Track>> fetchNextPage() async {
    if (!_hasMore) return [];

    final query = _queries[_currentQueryIndex];
    final index = _currentPageIndex * _pageSize;

    final tracks = await _deezerService.searchTracks(
      query: query,
      index: index,
      limit: _pageSize,
    );

    for (final track in tracks) {
      if (!_trackCache.containsKey(track.id)) {
        _trackCache[track.id] = track;
      }
    }

    // Advance pagination
    _currentPageIndex++;

    // If we got fewer results than requested or hit max pages, rotate query
    if (tracks.length < _pageSize || _currentPageIndex >= _maxPagesPerQuery) {
      _currentQueryIndex++;
      _currentPageIndex = 0;

      // If we've exhausted all queries, stop
      if (_currentQueryIndex >= _queries.length) {
        _hasMore = false;
      }
    }

    return tracks.where((t) => _trackCache.containsKey(t.id)).toList();
  }

  /// Fetch multiple pages at once for faster initial load.
  Future<void> fetchBulk(int pages) async {
    for (int i = 0; i < pages && _hasMore; i++) {
      await fetchNextPage();
    }
  }

  /// Get track details by ID.
  Future<TrackDetails> getTrackDetails(int trackId) async {
    return _deezerService.getTrackDetails(trackId);
  }

  /// Get lyrics for a track.
  Future<Lyrics?> getLyrics({
    required String trackName,
    required String artistName,
    required String albumName,
    required int duration,
  }) async {
    return _lyricsService.getLyrics(
      trackName: trackName,
      artistName: artistName,
      albumName: albumName,
      duration: duration,
    );
  }

  /// Group tracks by first letter (A-Z, # for non-alpha).
  /// Runs on a background isolate to avoid UI jank.
  static Map<String, List<Track>> groupTracks(List<Track> tracks) {
    final Map<String, List<Track>> grouped = {};
    for (final track in tracks) {
      final key = track.groupKey;
      grouped.putIfAbsent(key, () => []).add(track);
    }

    // Sort keys: A-Z first, then #
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        if (a == '#') return 1;
        if (b == '#') return -1;
        return a.compareTo(b);
      });

    final sortedMap = <String, List<Track>>{};
    for (final key in sortedKeys) {
      sortedMap[key] = grouped[key]!;
    }
    return sortedMap;
  }

  /// Search/filter tracks on a background isolate.
  static Future<List<Track>> searchTracksInBackground(
    List<Track> allTracks,
    String query,
  ) async {
    if (query.isEmpty) return allTracks;
    return Isolate.run(() {
      final lowerQuery = query.toLowerCase();
      return allTracks.where((track) {
        return track.title.toLowerCase().contains(lowerQuery) ||
            track.artistName.toLowerCase().contains(lowerQuery) ||
            track.albumTitle.toLowerCase().contains(lowerQuery);
      }).toList();
    });
  }

  void dispose() {
    _deezerService.dispose();
    _lyricsService.dispose();
  }
}
