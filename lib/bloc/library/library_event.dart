import 'package:equatable/equatable.dart';

/// Events for the Library BLoC.
abstract class LibraryEvent extends Equatable {
  const LibraryEvent();
  @override
  List<Object?> get props => [];
}

/// Initial load of tracks.
class LoadTracks extends LibraryEvent {
  const LoadTracks();
}

/// Load more tracks (infinite scroll).
class LoadMoreTracks extends LibraryEvent {
  const LoadMoreTracks();
}

/// Search/filter tracks.
class SearchTracks extends LibraryEvent {
  final String query;
  const SearchTracks(this.query);
  @override
  List<Object?> get props => [query];
}

/// Clear search and show all tracks.
class ClearSearch extends LibraryEvent {
  const ClearSearch();
}
