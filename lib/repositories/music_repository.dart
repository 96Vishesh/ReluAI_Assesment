import 'dart:async';
import 'dart:isolate';
import '../models/track.dart';
import '../services/deezer_service.dart';
import '../services/lyrics_service.dart';

/// Repository that coordinates data fetching and manages paging state.
/// Uses a hybrid approach: tries search first, falls back to playlist/radio
/// crawling for geo-restricted regions where search returns empty data.
class MusicRepository {
  final DeezerService _deezerService;
  final LyricsService _lyricsService;

  /// All unique tracks accumulated so far, keyed by ID.
  final Map<int, Track> _trackCache = {};

  /// Whether the search API works (not geo-blocked).
  bool? _searchWorks;

  // ─── Search-based paging state ───
  static const List<String> _queries = [
    'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j',
    'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't',
    'u', 'v', 'w', 'x', 'y', 'z',
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
    'love', 'night', 'baby', 'heart', 'dream', 'fire',
    'sun', 'rain', 'dance', 'rock', 'blue', 'star',
  ];
  int _currentQueryIndex = 0;
  int _currentPageIndex = 0;
  static const int _maxPagesPerQuery = 40;
  static const int _pageSize = 50;

  // ─── Playlist-based paging state ───
  /// Curated list of large Deezer playlists (each 50-500+ tracks).
  static const List<int> _playlistIds = [
    // Pop
    3155776842, 1313621735, 1111141961, 53362031, 1282495565,
    // Rock
    1130102843, 1214944503, 1128080763, 2098157264, 4523444422,
    // Hip-Hop / Rap
    1996494362, 2098157264, 1677006641, 2528039982, 5765328804,
    // Electronic / Dance
    3338949242, 1306931615, 64459261, 1450284242, 1282495565,
    // R&B / Soul
    1652248171, 1110287021, 12648996782, 6597846484, 4782920764,
    // Latin
    4503899902, 3564499742, 1677006641, 4523444422, 11691957522,
    // Chill
    10952747602, 1996494362, 2528039982, 3338949242, 1313621735,
    // Country
    8931919502, 1130102843, 1214944503, 1282495565, 2098157264,
    // Jazz / Blues
    1111141961, 1652248171, 53362031, 1450284242, 64459261,
    // Metal / Hard Rock
    1128080763, 4523444422, 5765328804, 4782920764, 6597846484,
    // Indie / Alternative
    12648996782, 11691957522, 3564499742, 4503899902, 10952747602,
    // Classical / Ambient
    1306931615, 1110287021, 8931919502, 1677006641, 2528039982,
    // World / Folk
    3155776842, 1996494362, 53362031, 1313621735, 1111141961,
    // Decades (80s, 90s, 2000s)
    1130102843, 1214944503, 64459261, 1128080763, 2098157264,
    // Mood (workout, focus, party)
    4523444422, 1652248171, 3338949242, 5765328804, 4782920764,
    // More Pop / Misc
    6597846484, 12648996782, 11691957522, 3564499742, 4503899902,
    10952747602, 1306931615, 8931919502, 1450284242, 1282495565,
    1110287021, 1677006641, 2528039982, 1996494362, 3155776842,
  ];

  /// Radio station IDs for additional track variety.
  static const List<int> _radioIds = [
    37151, 37152, 37153, 37154, 37155, 37156, 37157, 37158, 37159, 37160,
    37161, 37162, 37163, 37164, 37165, 37166, 37167, 37168, 37169, 37170,
    36891, 36892, 36893, 36894, 36895, 36896, 36897, 36898, 36899, 36900,
    36901, 36902, 36903, 36904, 36905, 36906, 36907, 36908, 36909, 36910,
    30621, 30622, 30623, 30624, 30625, 30626, 30627, 30628, 30629, 30630,
    30631, 30632, 30633, 30634, 30635, 30636, 30637, 30638, 30639, 30640,
    6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
  ];

  int _currentPlaylistIndex = 0;
  int _currentPlaylistPageIndex = 0;
  int _currentRadioIndex = 0;
  static const int _playlistPageSize = 100;

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

  /// Detect whether the search API works in this region.
  Future<bool> _checkSearchWorks() async {
    if (_searchWorks != null) return _searchWorks!;
    try {
      final results = await _deezerService.searchTracks(
        query: 'love',
        index: 0,
        limit: 10,
      );
      _searchWorks = results.isNotEmpty;
    } catch (_) {
      _searchWorks = false;
    }
    return _searchWorks!;
  }

  /// Add tracks to cache, deduplicating by ID.
  int _addToCache(List<Track> tracks) {
    int added = 0;
    for (final track in tracks) {
      if (!_trackCache.containsKey(track.id)) {
        _trackCache[track.id] = track;
        added++;
      }
    }
    return added;
  }

  /// Fetch the next page of tracks using the search API.
  Future<List<Track>> _fetchNextPageViaSearch() async {
    if (_currentQueryIndex >= _queries.length) {
      return [];
    }

    final query = _queries[_currentQueryIndex];
    final index = _currentPageIndex * _pageSize;

    final tracks = await _deezerService.searchTracks(
      query: query,
      index: index,
      limit: _pageSize,
    );

    _addToCache(tracks);

    _currentPageIndex++;
    if (tracks.length < _pageSize || _currentPageIndex >= _maxPagesPerQuery) {
      _currentQueryIndex++;
      _currentPageIndex = 0;
      if (_currentQueryIndex >= _queries.length) {
        _hasMore = false;
      }
    }

    return tracks;
  }

  /// Fetch the next batch of tracks from playlists/radios.
  Future<List<Track>> _fetchNextPageViaPlaylists() async {
    List<Track> newTracks = [];

    // Try playlists first
    while (newTracks.isEmpty && _currentPlaylistIndex < _playlistIds.length) {
      final playlistId = _playlistIds[_currentPlaylistIndex];
      final index = _currentPlaylistPageIndex * _playlistPageSize;

      try {
        final tracks = await _deezerService.getPlaylistTracks(
          playlistId: playlistId,
          index: index,
          limit: _playlistPageSize,
        );

        if (tracks.isNotEmpty) {
          _addToCache(tracks);
          newTracks = tracks;
          _currentPlaylistPageIndex++;

          // If we got fewer than requested, move to next playlist
          if (tracks.length < _playlistPageSize) {
            _currentPlaylistIndex++;
            _currentPlaylistPageIndex = 0;
          }
        } else {
          // Empty response — move to next playlist
          _currentPlaylistIndex++;
          _currentPlaylistPageIndex = 0;
        }
      } catch (e) {
        if (e is NoInternetException) rethrow;
        // Skip broken playlist
        _currentPlaylistIndex++;
        _currentPlaylistPageIndex = 0;
      }
    }

    // If playlists are exhausted, try radio stations
    if (newTracks.isEmpty && _currentRadioIndex < _radioIds.length) {
      while (newTracks.isEmpty && _currentRadioIndex < _radioIds.length) {
        try {
          final tracks = await _deezerService.getRadioTracks(
            _radioIds[_currentRadioIndex],
          );
          _addToCache(tracks);
          newTracks = tracks;
        } catch (e) {
          if (e is NoInternetException) rethrow;
        }
        _currentRadioIndex++;
      }
    }

    // If both exhausted, mark as done
    if (_currentPlaylistIndex >= _playlistIds.length &&
        _currentRadioIndex >= _radioIds.length) {
      _hasMore = false;
    }

    return newTracks;
  }

  /// Fetch the next page of tracks. Automatically detects geo-restriction
  /// and uses the appropriate strategy.
  Future<List<Track>> fetchNextPage() async {
    if (!_hasMore) return [];

    final searchWorks = await _checkSearchWorks();

    if (searchWorks) {
      return _fetchNextPageViaSearch();
    } else {
      return _fetchNextPageViaPlaylists();
    }
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
  static Map<String, List<Track>> groupTracks(List<Track> tracks) {
    final Map<String, List<Track>> grouped = {};
    for (final track in tracks) {
      final key = track.groupKey;
      grouped.putIfAbsent(key, () => []).add(track);
    }

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
