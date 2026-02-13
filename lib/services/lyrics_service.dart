import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/track.dart';
import 'deezer_service.dart';

/// Service for fetching lyrics from LRCLIB.
/// Uses the search endpoint for flexible matching instead of get-cached
/// which requires exact album name + duration.
class LyricsService {
  static const String _baseUrl = 'https://lrclib.net/api';
  final http.Client _client;

  LyricsService({http.Client? client}) : _client = client ?? http.Client();

  /// Search for lyrics using track name and artist name.
  /// The search endpoint is more flexible than get-cached and
  /// doesn't require exact album name or duration matching.
  Future<Lyrics?> getLyrics({
    required String trackName,
    required String artistName,
    required String albumName,
    required int duration,
  }) async {
    // Try the search endpoint first (more flexible matching)
    final searchResult = await _searchLyrics(
      trackName: trackName,
      artistName: artistName,
    );
    if (searchResult != null) return searchResult;

    // Fallback: try get-cached with exact parameters
    return _getCachedLyrics(
      trackName: trackName,
      artistName: artistName,
      albumName: albumName,
      duration: duration,
    );
  }

  /// Search for lyrics using the LRCLIB search endpoint.
  /// Returns the best match from the results array.
  Future<Lyrics?> _searchLyrics({
    required String trackName,
    required String artistName,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/search?'
      'track_name=${Uri.encodeComponent(trackName)}'
      '&artist_name=${Uri.encodeComponent(artistName)}',
    );

    try {
      final response = await _client.get(uri, headers: {
        'User-Agent': 'MusicLibraryApp/1.0.0',
      }).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List && data.isNotEmpty) {
          // Find the best match: prefer one with plainLyrics
          for (final item in data) {
            final map = item as Map<String, dynamic>;
            final plainLyrics = map['plainLyrics'] as String?;
            if (plainLyrics != null && plainLyrics.isNotEmpty) {
              return Lyrics.fromJson(map);
            }
          }
          // If no plainLyrics found, return the first result anyway
          return Lyrics.fromJson(data[0] as Map<String, dynamic>);
        }
        return null;
      }
      return null;
    } catch (e) {
      if (e is NoInternetException) rethrow;
      if (e.toString().contains('SocketException') ||
          e.toString().contains('HandshakeException') ||
          e.toString().contains('TimeoutException')) {
        throw const NoInternetException();
      }
      return null;
    }
  }

  /// Fallback: try the exact get-cached endpoint.
  Future<Lyrics?> _getCachedLyrics({
    required String trackName,
    required String artistName,
    required String albumName,
    required int duration,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/get-cached?'
      'track_name=${Uri.encodeComponent(trackName)}'
      '&artist_name=${Uri.encodeComponent(artistName)}'
      '&album_name=${Uri.encodeComponent(albumName)}'
      '&duration=$duration',
    );

    try {
      final response = await _client.get(uri, headers: {
        'User-Agent': 'MusicLibraryApp/1.0.0',
      }).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return Lyrics.fromJson(data);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        return null;
      }
    } catch (e) {
      if (e is NoInternetException) rethrow;
      if (e.toString().contains('SocketException') ||
          e.toString().contains('HandshakeException') ||
          e.toString().contains('TimeoutException')) {
        throw const NoInternetException();
      }
      return null;
    }
  }

  void dispose() {
    _client.close();
  }
}
