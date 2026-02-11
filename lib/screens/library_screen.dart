import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/library/library_bloc.dart';
import '../bloc/library/library_event.dart';
import '../bloc/library/library_state.dart';
import '../bloc/connectivity/connectivity_bloc.dart';
import '../models/track.dart';
import '../theme/app_theme.dart';
import '../widgets/sticky_header.dart';
import '../widgets/track_tile.dart';
import 'track_details_screen.dart';

/// Main library screen with 50k+ tracks, infinite scroll, grouping,
/// sticky headers, and search.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Trigger initial load
    context.read<LibraryBloc>().add(const LoadTracks());
  }

  void _onScroll() {
    // Show/hide scroll-to-top button
    final showButton = _scrollController.offset > 1000;
    if (showButton != _showScrollToTop) {
      setState(() => _showScrollToTop = showButton);
    }

    // Infinite scroll: load more when near bottom
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 500) {
      context.read<LibraryBloc>().add(const LoadMoreTracks());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    context.read<LibraryBloc>().add(SearchTracks(query));
  }

  void _clearSearch() {
    _searchController.clear();
    context.read<LibraryBloc>().add(const ClearSearch());
  }

  void _navigateToDetails(Track track) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TrackDetailsScreen(track: track),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Offline banner
          BlocBuilder<ConnectivityBloc, ConnectivityState>(
            builder: (context, state) {
              if (state is ConnectivityOffline) {
                return Container(
                  width: double.infinity,
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 8,
                    bottom: 8,
                    left: 16,
                    right: 16,
                  ),
                  decoration: const BoxDecoration(
                    color: AppTheme.errorColor,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'NO INTERNET CONNECTION',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          // Main content
          Expanded(
            child: BlocBuilder<LibraryBloc, LibraryState>(
              builder: (context, state) {
                if (state is LibraryInitial || state is LibraryLoading) {
                  return _buildLoadingState();
                }
                if (state is LibraryError) {
                  return _buildErrorState(state);
                }
                if (state is LibraryLoaded) {
                  return _buildLoadedState(state);
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _showScrollToTop
          ? FloatingActionButton(
              mini: true,
              backgroundColor: AppTheme.primaryColor,
              onPressed: () {
                _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                );
              },
              child: const Icon(Icons.arrow_upward_rounded, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              color: AppTheme.primaryColor,
              strokeWidth: 3,
            ),
          ),
          SizedBox(height: 20),
          Text(
            'Loading music library...',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Fetching tracks from Deezer',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(LibraryError state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              state.isOffline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
              size: 64,
              color: AppTheme.errorColor,
            ),
            const SizedBox(height: 20),
            Text(
              state.message,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                context.read<LibraryBloc>().add(const LoadTracks());
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadedState(LibraryLoaded state) {
    final groupedTracks = state.groupedTracks;
    final keys = groupedTracks.keys.toList();

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // App bar with title
        SliverToBoxAdapter(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.library_music_rounded,
                        color: AppTheme.primaryColor,
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Music Library',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: AppTheme.headerGradient,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_formatNumber(state.totalLoaded)} tracks',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Search bar
                  TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search tracks, artists, albums...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: _clearSearch,
                            )
                          : null,
                    ),
                  ),
                  if (state.searchQuery.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      '${_formatNumber(state.displayTracks.length)} results for "${state.searchQuery}"',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),

        // Grouped tracks with sticky headers
        if (groupedTracks.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    size: 48,
                    color: AppTheme.textSecondary,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No tracks found',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...keys.expand((key) {
            final tracks = groupedTracks[key]!;
            return [
              SliverPersistentHeader(
                pinned: true,
                delegate: StickyHeaderDelegate(
                  letter: key,
                  count: tracks.length,
                ),
              ),
              SliverList.builder(
                itemCount: tracks.length,
                itemBuilder: (context, index) {
                  final track = tracks[index];
                  return TrackTile(
                    track: track,
                    onTap: () => _navigateToDetails(track),
                  );
                },
              ),
            ];
          }),

        // Loading more indicator
        if (state.isLoadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryColor,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
          ),

        // Bottom padding
        const SliverToBoxAdapter(
          child: SizedBox(height: 80),
        ),
      ],
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}k';
    }
    return number.toString();
  }
}
