import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../bloc/track_details/track_details_bloc.dart';
import '../bloc/track_details/track_details_event.dart';
import '../bloc/track_details/track_details_state.dart';
import '../models/track.dart';
import '../repositories/music_repository.dart';
import '../theme/app_theme.dart';

/// Track Details Screen showing full details + lyrics.
class TrackDetailsScreen extends StatelessWidget {
  final Track track;

  const TrackDetailsScreen({super.key, required this.track});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => TrackDetailsBloc(
        repository: context.read<MusicRepository>(),
      )..add(FetchTrackDetails(
          trackId: track.id,
          trackName: track.title,
          artistName: track.artistName,
          albumName: track.albumTitle,
          duration: track.duration,
          albumCoverUrl: track.albumCoverMedium,
        )),
      child: _TrackDetailsBody(track: track),
    );
  }
}

class _TrackDetailsBody extends StatelessWidget {
  final Track track;

  const _TrackDetailsBody({required this.track});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<TrackDetailsBloc, TrackDetailsState>(
        builder: (context, state) {
          if (state is TrackDetailsLoading) {
            return _buildLoading(context);
          }
          if (state is TrackDetailsError) {
            return _buildError(context, state);
          }
          if (state is TrackDetailsLoaded) {
            return _buildLoaded(context, state);
          }
          return _buildLoading(context);
        },
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    return CustomScrollView(
      slivers: [
        _buildAppBar(context, null),
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: AppTheme.primaryColor,
                  strokeWidth: 3,
                ),
                SizedBox(height: 20),
                Text(
                  'Loading track details...',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError(BuildContext context, TrackDetailsError state) {
    return CustomScrollView(
      slivers: [
        _buildAppBar(context, null),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    state.isOffline
                        ? Icons.wifi_off_rounded
                        : Icons.error_outline_rounded,
                    size: 72,
                    color: AppTheme.errorColor,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    state.message,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      context.read<TrackDetailsBloc>().add(
                            FetchTrackDetails(
                              trackId: track.id,
                              trackName: track.title,
                              artistName: track.artistName,
                              albumName: track.albumTitle,
                              duration: track.duration,
                              albumCoverUrl: track.albumCoverMedium,
                            ),
                          );
                    },
                    icon:
                        const Icon(Icons.refresh_rounded, color: Colors.white),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoaded(BuildContext context, TrackDetailsLoaded state) {
    final details = state.details;

    return CustomScrollView(
      slivers: [
        _buildAppBar(context, details.albumCoverBig),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Track title
                Text(
                  details.title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                // Artist
                Text(
                  details.artistName,
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                // Album
                Text(
                  details.albumTitle,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 20),

                // Info cards
                _buildInfoRow(details),
                const SizedBox(height: 20),

                // Contributors
                if (details.contributors.isNotEmpty) ...[
                  const Text(
                    'Contributors',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: details.contributors.map((name) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.cardColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppTheme.primaryColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          name,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                ],

                // Lyrics section
                _buildLyricsSection(state),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar(BuildContext context, String? imageUrl) {
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      backgroundColor: AppTheme.surfaceColor,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: CircleAvatar(
          backgroundColor: Colors.black38,
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: imageUrl != null && imageUrl.isNotEmpty
            ? Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: AppTheme.cardColor,
                      child: const Center(
                        child: Icon(
                          Icons.album_rounded,
                          size: 80,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: AppTheme.cardColor,
                      child: const Center(
                        child: Icon(
                          Icons.album_rounded,
                          size: 80,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  // Gradient overlay
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.transparent,
                          AppTheme.backgroundColor,
                        ],
                        stops: [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ],
              )
            : Container(
                decoration: const BoxDecoration(
                  gradient: AppTheme.headerGradient,
                ),
                child: const Center(
                  child: Icon(
                    Icons.album_rounded,
                    size: 80,
                    color: Colors.white24,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildInfoRow(TrackDetails details) {
    return Row(
      children: [
        _buildInfoCard(
          icon: Icons.timer_outlined,
          label: 'Duration',
          value: details.formattedDuration,
        ),
        const SizedBox(width: 10),
        if (details.releaseDate.isNotEmpty)
          _buildInfoCard(
            icon: Icons.calendar_today_outlined,
            label: 'Released',
            value: details.releaseDate,
          ),
        if (details.bpm > 0) ...[
          const SizedBox(width: 10),
          _buildInfoCard(
            icon: Icons.speed_outlined,
            label: 'BPM',
            value: details.bpm.toString(),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppTheme.primaryColor, size: 20),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLyricsSection(TrackDetailsLoaded state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.lyrics_outlined,
              color: AppTheme.primaryColor,
              size: 22,
            ),
            const SizedBox(width: 8),
            const Text(
              'Lyrics',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (state.isLoadingLyrics) ...[
              const SizedBox(width: 12),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  color: AppTheme.primaryColor,
                  strokeWidth: 2,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        if (state.isLoadingLyrics)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: Text(
                'Loading lyrics...',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
          )
        else if (state.lyricsError != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.lyrics_outlined,
                  color: AppTheme.textSecondary,
                  size: 32,
                ),
                const SizedBox(height: 10),
                Text(
                  state.lyricsError!,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else if (state.lyrics != null && state.lyrics!.hasLyrics)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.2),
              ),
            ),
            child: Text(
              state.lyrics!.displayLyrics,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                height: 1.8,
              ),
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.music_off_rounded,
                  color: AppTheme.textSecondary,
                  size: 32,
                ),
                SizedBox(height: 10),
                Text(
                  'No lyrics available for this track',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
