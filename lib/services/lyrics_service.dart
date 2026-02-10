import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/track.dart';
import 'deezer_service.dart';

/// Service for fetching lyrics from LRCLIB.
class LyricsService {
  static const String _baseUrl = 'https://lrclib.net/api';
  final http.Client _client;

  LyricsService({http.Client? client}) : _client = client ?? http.Client();

  /// Fetch cached lyrics for a track.
  Future<Lyrics?> getLyrics({
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
        return null; // No lyrics found
      } else {
        throw Exception('LRCLIB API error: ${response.statusCode}');
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
