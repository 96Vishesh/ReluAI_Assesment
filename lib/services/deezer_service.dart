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
class DeezerService {
  static const String _baseUrl = 'https://api.deezer.com';
  final http.Client _client;

  DeezerService({http.Client? client}) : _client = client ?? http.Client();

  /// Search tracks with pagination.
  /// [query] - search term, [index] - offset, [limit] - page size.
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
