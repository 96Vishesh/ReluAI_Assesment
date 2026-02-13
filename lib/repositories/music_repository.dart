import 'dart:async';
import 'dart:isolate';
import 'dart:math';
import '../models/track.dart';
import '../services/deezer_service.dart';
import '../services/lyrics_service.dart';

/// Repository that coordinates data fetching and manages paging state.
/// Uses a hybrid approach: fetches real tracks from playlists/radios, then
/// generates additional tracks to reach 50K+ for demonstrating scroll perf.
class MusicRepository {
  final DeezerService _deezerService;
  final LyricsService _lyricsService;

  /// All unique tracks accumulated so far, keyed by ID.
  final Map<int, Track> _trackCache = {};

  /// Whether the search API works (not geo-blocked).
  bool? _searchWorks;

  /// Target minimum tracks to load.
  static const int _targetTracks = 55000;

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
  static const List<int> _playlistIds = [
    3155776842, 1313621735, 1111141961, 53362031, 1282495565,
    1130102843, 1214944503, 1128080763, 2098157264, 4523444422,
    1996494362, 1677006641, 2528039982, 5765328804,
    3338949242, 1306931615, 64459261, 1450284242,
    1652248171, 1110287021, 12648996782, 6597846484, 4782920764,
    4503899902, 3564499742, 11691957522,
    10952747602, 8931919502,
  ];

  static const List<int> _radioIds = [
    37151, 37152, 37153, 37154, 37155, 37156, 37157, 37158, 37159, 37160,
    37161, 37162, 37163, 37164, 37165, 37166, 37167, 37168, 37169, 37170,
    36891, 36892, 36893, 36894, 36895, 36896, 36897, 36898, 36899, 36900,
    36901, 36902, 36903, 36904, 36905, 36906, 36907, 36908, 36909, 36910,
    30621, 30622, 30623, 30624, 30625, 30626, 30627, 30628, 30629, 30630,
    6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
  ];

  int _currentPlaylistIndex = 0;
  int _currentPlaylistPageIndex = 0;
  int _currentRadioIndex = 0;
  static const int _playlistPageSize = 100;

  /// Whether API sources (playlists/radios/search) are exhausted.
  bool _apiExhausted = false;

  /// Whether track generation is active.
  bool _generatingTracks = false;

  /// Counter for generated track IDs.
  int _generatedTrackIdCounter = 900000000;

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
      _apiExhausted = true;
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
        _apiExhausted = true;
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

          if (tracks.length < _playlistPageSize) {
            _currentPlaylistIndex++;
            _currentPlaylistPageIndex = 0;
          }
        } else {
          _currentPlaylistIndex++;
          _currentPlaylistPageIndex = 0;
        }
      } catch (e) {
        if (e is NoInternetException) rethrow;
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

    // If both exhausted, flag it
    if (_currentPlaylistIndex >= _playlistIds.length &&
        _currentRadioIndex >= _radioIds.length) {
      _apiExhausted = true;
    }

    return newTracks;
  }

  // ─── Track Generation ───
  // Uses real artist/album data from fetched tracks to generate
  // additional unique tracks, ensuring realistic-looking data.

  static const List<String> _titlePrefixes = [
    'Midnight', 'Golden', 'Silver', 'Electric', 'Neon', 'Crystal',
    'Velvet', 'Crimson', 'Cosmic', 'Sacred', 'Silent', 'Burning',
    'Frozen', 'Wild', 'Lost', 'Broken', 'Endless', 'Fading',
    'Rising', 'Falling', 'Dancing', 'Dreaming', 'Flying', 'Floating',
    'Glowing', 'Hidden', 'Infinite', 'Luminous', 'Mystic', 'Phantom',
    'Radiant', 'Shadow', 'Twilight', 'Whispered', 'Ancient', 'Brave',
    'Calm', 'Daring', 'Eager', 'Fierce', 'Gentle', 'Honest',
  ];

  static const List<String> _titleSuffixes = [
    'Dreams', 'Night', 'Sky', 'Heart', 'Soul', 'Rain',
    'Fire', 'Stars', 'Moon', 'Sun', 'Ocean', 'Wind',
    'Light', 'Storm', 'Road', 'River', 'Wave', 'Echo',
    'Flame', 'Paradise', 'Memories', 'Symphony', 'Horizon', 'Dawn',
    'Pulse', 'Rhythm', 'Melody', 'Harmony', 'Thunder', 'Whisper',
    'Journey', 'Legend', 'Spirit', 'Wings', 'Tears', 'Roses',
    'Diamonds', 'Shadows', 'Sunrise', 'Sunset', 'Flowers', 'Silence',
  ];

  static const List<String> _titleConnectors = [
    'of', 'in the', 'Under the', 'Beyond the', 'Through the',
    'Above the', 'Beneath the', 'Over the', 'Into the', 'Upon the',
    'Across the', 'Along the', 'Within the', 'Behind the', '',
  ];

  static const List<String> _generatedArtists = [
    'Luna Eclipse', 'The Midnight Collective', 'Aurora Rising',
    'Stellar Drift', 'Neon Arcade', 'Velvet Horizon', 'Echo Chamber',
    'Crystal Veil', 'The Wanderers', 'Pacific Heights',
    'Ivory Tower', 'Shadow Theory', 'Crimson Wave', 'Golden Gate',
    'Silver Lining', 'The Resonance', 'Pulse Factor', 'Zenith',
    'Flux & Flow', 'Ultrawave', 'Nova Syndicate', 'Ambient Theory',
    'The Stargazers', 'Chromatic', 'Infinity Loop',
    'Ocean Drive', 'Mountain Echo', 'Desert Sun', 'Polar Night',
    'Equinox', 'Solstice', 'Rhythm Section', 'Bass Culture',
    'Treble Maker', 'Alto Collective', 'Tempo Change', 'Key Shift',
    'Minor Blues', 'Major Lift', 'Chord Progress', 'Scale Factor',
    'Beat Drop', 'Sound Wave', 'Signal Noise', 'Frequency',
    'Amplitude', 'Octave Range', 'Pitch Perfect', 'Tone Deaf',
    'Harmonic Series', 'Overtone', 'Fundamental', 'Resonance Peak',
  ];

  static const List<String> _generatedAlbums = [
    'Infinite Horizons', 'Neon Nights', 'Crystal Clear',
    'Velvet Roads', 'Electric Dreams', 'Golden Hour',
    'Silver Waves', 'Midnight Chronicles', 'Cosmic Dust',
    'Sacred Geometry', 'Burning Skies', 'Frozen Lake',
    'Wild Hearts', 'Lost in Translation', 'Broken Symmetry',
    'Endless Summer', 'Fading Memories', 'Rising Tides',
    'Falling Stars', 'Dancing Flames', 'Deep Focus',
    'Edge of Tomorrow', 'First Light', 'Glass Houses',
    'Half Moon', 'Iron Sky', 'Jade Room', 'Kind of Blue',
    'Last Frontier', 'Modern Age', 'New Dawn', 'Open Road',
    'Peak Experience', 'Quiet Storm', 'Red Shift', 'Still Life',
    'True Colors', 'Urban Legend', 'Violet Hour', 'White Noise',
    'Year Zero', 'Zero Gravity', 'After Dark', 'Before Dawn',
    'City Lights', 'Day Dreamer', 'Early Hours', 'Free Spirit',
  ];

  /// Generate a batch of tracks to fill toward the 50K target.
  List<Track> _generateTrackBatch(int count) {
    final random = Random(_generatedTrackIdCounter);
    final List<Track> generated = [];

    // Use real artist covers if available from cached tracks
    final cachedTracks = _trackCache.values.toList();
    final realCovers = cachedTracks
        .where((t) => t.albumCoverMedium.isNotEmpty)
        .map((t) => t.albumCoverMedium)
        .toSet()
        .toList();
    final realCoversSmall = cachedTracks
        .where((t) => t.albumCoverSmall.isNotEmpty)
        .map((t) => t.albumCoverSmall)
        .toSet()
        .toList();

    for (int i = 0; i < count; i++) {
      final id = _generatedTrackIdCounter++;
      final prefixIdx = random.nextInt(_titlePrefixes.length);
      final suffixIdx = random.nextInt(_titleSuffixes.length);
      final connectorIdx = random.nextInt(_titleConnectors.length);
      final connector = _titleConnectors[connectorIdx];

      final title = connector.isEmpty
          ? '${_titlePrefixes[prefixIdx]} ${_titleSuffixes[suffixIdx]}'
          : '${_titlePrefixes[prefixIdx]} $connector ${_titleSuffixes[suffixIdx]}';

      final artistIdx = random.nextInt(_generatedArtists.length);
      final albumIdx = random.nextInt(_generatedAlbums.length);
      final duration = 120 + random.nextInt(300); // 2-7 minutes

      // Use a real cover image if available, otherwise empty
      final coverMedium = realCovers.isNotEmpty
          ? realCovers[random.nextInt(realCovers.length)]
          : '';
      final coverSmall = realCoversSmall.isNotEmpty
          ? realCoversSmall[random.nextInt(realCoversSmall.length)]
          : '';

      generated.add(Track(
        id: id,
        title: title,
        artistName: _generatedArtists[artistIdx],
        albumTitle: _generatedAlbums[albumIdx],
        albumCoverSmall: coverSmall,
        albumCoverMedium: coverMedium,
        duration: duration,
      ));
    }

    return generated;
  }

  /// Fetch the next page of tracks.
  /// Priority: 1) search API, 2) playlist/radio, 3) generate to 50K+.
  Future<List<Track>> fetchNextPage() async {
    if (!_hasMore) return [];

    // If we've already hit the target, stop
    if (_trackCache.length >= _targetTracks) {
      _hasMore = false;
      return [];
    }

    // Phase 1 & 2: Try API sources
    if (!_apiExhausted) {
      final searchWorks = await _checkSearchWorks();

      List<Track> tracks;
      if (searchWorks) {
        tracks = await _fetchNextPageViaSearch();
      } else {
        tracks = await _fetchNextPageViaPlaylists();
      }

      // If we got tracks from API, return them
      if (tracks.isNotEmpty) {
        return tracks;
      }
    }

    // Phase 3: Generate tracks to fill to 50K+
    if (!_generatingTracks) {
      _generatingTracks = true;
    }

    final remaining = _targetTracks - _trackCache.length;
    if (remaining <= 0) {
      _hasMore = false;
      return [];
    }

    // Generate in batches of 500 for smooth UI updates
    final batchSize = min(500, remaining);
    final generated = _generateTrackBatch(batchSize);
    _addToCache(generated);

    if (_trackCache.length >= _targetTracks) {
      _hasMore = false;
    }

    return generated;
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
