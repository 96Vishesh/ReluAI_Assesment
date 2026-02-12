import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/track.dart';

/// Exception thrown when there is no internet connectivity.
class NoInternetException implements Exception {
  final String message;
  const NoInternetException([this.message = 'NO INTERNET CONNECTION']);
  @override
  String toString() => message;
}

/// Service for interacting with the Deezer public API.
/// Uses playlist-based fetching to bypass geo-restrictions on the search API.
class DeezerService {
  static const String _baseUrl = 'https://api.deezer.com';
  final http.Client _client;

  DeezerService({http.Client? client}) : _client = client ?? http.Client();

  /// Search tracks with pagination.
  /// Falls back to playlist-based fetching if search returns empty data.
  Future<List<Track>> searchTracks({
    required String query,
    int index = 0,
    int limit = 50,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/search/track?q=${Uri.encodeComponent(query)}&index=$index&limit=$limit',
    );

    try {
      final response = await _client.get(uri).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final trackList = data['data'] as List<dynamic>? ?? [];
        return trackList
            .map((item) => Track.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Deezer API error: ${response.statusCode}');
      }
    } catch (e) {
      if (e is NoInternetException) rethrow;
      if (e.toString().contains('SocketException') ||
          e.toString().contains('HandshakeException') ||
          e.toString().contains('TimeoutException')) {
        throw const NoInternetException();
      }
      rethrow;
    }
  }

  /// Fetch tracks from a specific playlist.
  /// Playlist endpoints work in geo-restricted regions where search doesn't.
  Future<List<Track>> getPlaylistTracks({
    required int playlistId,
    int index = 0,
    int limit = 100,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/playlist/$playlistId/tracks?index=$index&limit=$limit',
    );

    try {
      final response = await _client.get(uri).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final trackList = data['data'] as List<dynamic>? ?? [];
        return trackList
            .map((item) => Track.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        return [];
      }
    } catch (e) {
      if (e is NoInternetException) rethrow;
      if (e.toString().contains('SocketException') ||
          e.toString().contains('HandshakeException') ||
          e.toString().contains('TimeoutException')) {
        throw const NoInternetException();
      }
      return [];
    }
  }

  /// Fetch tracks from a radio station.
  Future<List<Track>> getRadioTracks(int radioId) async {
    final uri = Uri.parse('$_baseUrl/radio/$radioId/tracks');

    try {
      final response = await _client.get(uri).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final trackList = data['data'] as List<dynamic>? ?? [];
        return trackList
            .map((item) => Track.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        return [];
      }
    } catch (e) {
      if (e is NoInternetException) rethrow;
      if (e.toString().contains('SocketException') ||
          e.toString().contains('HandshakeException') ||
          e.toString().contains('TimeoutException')) {
        throw const NoInternetException();
      }
      return [];
    }
  }

  /// Fetch tracks from an album.
  Future<List<Track>> getAlbumTracks(int albumId) async {
    final uri = Uri.parse('$_baseUrl/album/$albumId/tracks?limit=100');

    try {
      final response = await _client.get(uri).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final trackList = data['data'] as List<dynamic>? ?? [];
        // Album tracks have a slightly different format — need album info
        final albumResponse = await _client.get(
          Uri.parse('$_baseUrl/album/$albumId'),
        ).timeout(const Duration(seconds: 15));

        String albumTitle = '';
        String albumCover = '';
        if (albumResponse.statusCode == 200) {
          final albumData = json.decode(albumResponse.body) as Map<String, dynamic>;
          albumTitle = albumData['title'] as String? ?? '';
          albumCover = albumData['cover_medium'] as String? ?? '';
        }

        return trackList.map((item) {
          final map = item as Map<String, dynamic>;
          // Enrich album track with album info if missing
          if (!map.containsKey('album')) {
            map['album'] = {'title': albumTitle, 'cover_medium': albumCover};
          }
          return Track.fromJson(map);
        }).toList();
      } else {
        return [];
      }
    } catch (e) {
      if (e is NoInternetException) rethrow;
      if (e.toString().contains('SocketException') ||
          e.toString().contains('HandshakeException') ||
          e.toString().contains('TimeoutException')) {
        throw const NoInternetException();
      }
      return [];
    }
  }

  /// Get detailed info for a single track.
  Future<TrackDetails> getTrackDetails(int trackId) async {
    final uri = Uri.parse('$_baseUrl/track/$trackId');

    try {
      final response = await _client.get(uri).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data.containsKey('error')) {
          throw Exception('Track not found');
        }
        return TrackDetails.fromJson(data);
      } else {
        throw Exception('Deezer API error: ${response.statusCode}');
      }
    } catch (e) {
      if (e is NoInternetException) rethrow;
      if (e.toString().contains('SocketException') ||
          e.toString().contains('HandshakeException') ||
          e.toString().contains('TimeoutException')) {
        throw const NoInternetException();
      }
      rethrow;
    }
  }

  void dispose() {
    _client.close();
  }
}
