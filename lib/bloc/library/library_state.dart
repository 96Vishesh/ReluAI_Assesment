import 'package:equatable/equatable.dart';
import '../../models/track.dart';

/// States for the Library BLoC.
abstract class LibraryState extends Equatable {
  const LibraryState();
  @override
  List<Object?> get props => [];
}

class LibraryInitial extends LibraryState {
  const LibraryInitial();
}

class LibraryLoading extends LibraryState {
  const LibraryLoading();
}

class LibraryLoaded extends LibraryState {
  final List<Track> allTracks;
  final List<Track> displayTracks;
  final Map<String, List<Track>> groupedTracks;
  final bool isLoadingMore;
  final bool hasMore;
  final String searchQuery;
  final int totalLoaded;

  const LibraryLoaded({
    required this.allTracks,
    required this.displayTracks,
    required this.groupedTracks,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.searchQuery = '',
    this.totalLoaded = 0,
  });

  LibraryLoaded copyWith({
    List<Track>? allTracks,
    List<Track>? displayTracks,
    Map<String, List<Track>>? groupedTracks,
    bool? isLoadingMore,
    bool? hasMore,
    String? searchQuery,
    int? totalLoaded,
  }) {
    return LibraryLoaded(
      allTracks: allTracks ?? this.allTracks,
      displayTracks: displayTracks ?? this.displayTracks,
      groupedTracks: groupedTracks ?? this.groupedTracks,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      searchQuery: searchQuery ?? this.searchQuery,
      totalLoaded: totalLoaded ?? this.totalLoaded,
    );
  }

  @override
  List<Object?> get props => [
        totalLoaded,
        isLoadingMore,
        hasMore,
        searchQuery,
        displayTracks.length,
      ];
}

class LibraryError extends LibraryState {
  final String message;
  final bool isOffline;

  const LibraryError({
    required this.message,
    this.isOffline = false,
  });

  @override
  List<Object?> get props => [message, isOffline];
}
