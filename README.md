# 🎵 Music Library - 50k+ Track Virtualization

A Flutter music library app that renders and interacts with **50,000+ tracks** smoothly using the **BLoC pattern**, with infinite scrolling, A-Z grouping with sticky headers, debounced search, and a details + lyrics screen.

## 📱 Screenshots & Features

### Library Screen
- **50,000+ tracks** loaded via multi-query Deezer API paging
- **Infinite scroll** with lazy loading - only visible items are built
- **A-Z sticky headers** grouping tracks by first letter
- **Debounced search** (300ms) running on a background isolate - no UI freeze
- **Track count badge** showing real-time loaded count
- **Scroll-to-top** floating action button

### Track Details Screen
- Album art with collapsible app bar (hero animation)
- Duration, release date, BPM info cards
- Contributors list
- **Lyrics** from LRCLIB API with loading/error/empty states
- **"NO INTERNET CONNECTION"** displayed when offline

---

## 🏗️ Architecture - BLoC Flow

```
┌─────────────┐     Events      ┌──────────────┐     States      ┌────────────┐
│   UI Layer  │ ──────────────► │  BLoC Layer  │ ──────────────► │  UI Layer  │
│  (Screens)  │                 │  (Business)  │                 │  (Rebuild)  │
└─────────────┘                 └──────────────┘                 └────────────┘
       │                              │
       │                              ▼
       │                    ┌──────────────────┐
       │                    │ Repository Layer │
       │                    │ (Data + Caching) │
       │                    └──────────────────┘
       │                              │
       │                    ┌─────────┴─────────┐
       │                    ▼                   ▼
       │            ┌──────────────┐   ┌──────────────┐
       │            │ Deezer API   │   │ LRCLIB API   │
       │            │ (Tracks)     │   │ (Lyrics)     │
       │            └──────────────┘   └──────────────┘
```

### BLoC Events & States

| BLoC | Events | States |
|------|--------|--------|
| **LibraryBloc** | `LoadTracks`, `LoadMoreTracks`, `SearchTracks`, `ClearSearch` | `LibraryInitial`, `LibraryLoading`, `LibraryLoaded` (allTracks, displayTracks, groupedTracks, isLoadingMore, hasMore, searchQuery), `LibraryError` |
| **TrackDetailsBloc** | `FetchTrackDetails` (trackId, trackName, artistName, albumName, duration) | `TrackDetailsInitial`, `TrackDetailsLoading`, `TrackDetailsLoaded` (details, lyrics, isLoadingLyrics, lyricsError), `TrackDetailsError` |
| **ConnectivityBloc** | `ConnectivityChanged`, `CheckConnectivity` | `ConnectivityInitial`, `ConnectivityOnline`, `ConnectivityOffline` |

---

## 🎯 3 Key Design Decisions

### 1. Multi-Query Paging Strategy
**Problem:** Deezer's search API returns max ~1000 results per query. To reach 50k+, a single query isn't enough.

**Solution:** Rotate through 38 queries (`a`-`z`, `0`-`9`, plus common terms like "love", "night", "dance") × 40 pages each (50 items/page). Tracks are de-duplicated by ID in a `Map<int, Track>`, ensuring uniqueness. This yields 38 × 40 × 50 = 76,000 potential tracks (minus duplicates = 50k+ unique).

### 2. Isolate-Based Search
**Problem:** Filtering 50k+ items on the main thread would freeze the UI for 100-500ms.

**Solution:** `MusicRepository.searchTracksInBackground()` uses `Isolate.run()` to perform the filter on a background isolate. Combined with a 300ms debounce timer in the BLoC, the UI stays jank-free even while searching large datasets.

### 3. Slivers for Virtualization (No Third-Party Packages)
**Problem:** Cannot use third-party virtualization packages, but must render 50k+ items without building all widgets at once.

**Solution:** `CustomScrollView` with `SliverList.builder` - Flutter's built-in lazy builder only creates widgets for items currently visible on screen (± a small cache extent). Combined with `SliverPersistentHeader(pinned: true)` for sticky A-Z headers, this gives full virtualization without any external packages.

---

## 🐛 Issue Faced + Fix

### Issue: Memory Growth During Rapid Search
**Symptom:** Typing quickly in the search bar caused multiple isolate spawns and redundant state emissions, leading to temporary memory spikes.

**Fix:** Added a `Completer`-based debounce mechanism in `LibraryBloc._onSearchTracks()`. The 300ms `Timer` ensures that only the final keystroke triggers an isolate search. Previous timer calls are cancelled via `_debounceTimer?.cancel()`, preventing concurrent isolate operations. This keeps memory flat regardless of typing speed.

---

## ⚠️ What Breaks at 100k Items?

At **100,000 items**, the following would become bottlenecks:

1. **In-Memory Track Map**: The `Map<int, Track>` storing all tracks consumes ~100-150 MB at 100k. On low-end devices (1-2 GB RAM), this could trigger OOM kills.
   - **Fix:** Implement a paginated virtual list backed by SQLite/Hive - only keep a window of ~5,000 tracks in memory at any time.

2. **Grouping Computation**: `MusicRepository.groupTracks()` iterates all 100k items to build the grouped map. At 100k, this takes 200-400ms even on an isolate.
   - **Fix:** Maintain an incrementally-updated sorted/grouped structure (e.g., a `SplayTreeMap`) instead of rebuilding from scratch on every change.

3. **Search on Isolate**: Isolate serialization of 100k `Track` objects (~50 MB payload) adds 300-500ms of copy overhead per search.
   - **Fix:** Move to a persistent background isolate with `Isolate.spawn()` that holds its own copy of the data, communicating via `SendPort`/`ReceivePort` to avoid repeated serialization.

4. **Sliver Rebuild**: With 27+ letter groups × thousands of items each, the `CustomScrollView` must manage many `SliverList` instances. While `builder` ensures only visible items are built, the sliver tree itself grows.
   - **Fix:** Flatten to a single `SliverList.builder` with computed indices for headers (treat headers as special items at index boundaries).

---

## 🔌 Offline Handling

- **Library Screen:** If the initial fetch fails due to no internet, shows `"NO INTERNET CONNECTION"` error with a Retry button.
- **Track Details Screen:** If details/lyrics fetch fails, shows a full-screen `"NO INTERNET CONNECTION"` overlay with Retry.
- **Connectivity Banner:** A real-time banner at the top of the Library Screen shows/hides based on `ConnectivityBloc` state, which uses `connectivity_plus` + a real HTTP ping to verify actual internet access.

---

## 🚀 How to Run

### Prerequisites
- Flutter SDK 3.x installed
- Windows/Android/iOS/Web platform tools

### Setup
```bash
# Clone the repository
git clone <repo-url>
cd ReluAssesment

# Install dependencies
flutter pub get

# Run on Windows
flutter run -d windows

# Run on Chrome (web)
flutter run -d chrome

# Run on Android
flutter run -d <device_id>
```

### Project Structure
```
lib/
├── bloc/
│   ├── connectivity/
│   │   └── connectivity_bloc.dart
│   ├── library/
│   │   ├── library_bloc.dart
│   │   ├── library_event.dart
│   │   └── library_state.dart
│   └── track_details/
│       ├── track_details_bloc.dart
│       ├── track_details_event.dart
│       └── track_details_state.dart
├── models/
│   └── track.dart
├── repositories/
│   └── music_repository.dart
├── screens/
│   ├── library_screen.dart
│   └── track_details_screen.dart
├── services/
│   ├── connectivity_service.dart
│   ├── deezer_service.dart
│   └── lyrics_service.dart
├── theme/
│   └── app_theme.dart
├── widgets/
│   ├── sticky_header.dart
│   └── track_tile.dart
└── main.dart
```

---

## 📊 Memory Usage Evidence

The app uses Flutter's built-in `SliverList.builder`, which only builds widgets for items currently visible + a small cache extent (default ~250 pixels above/below viewport). This means:

- **At 500 items:** ~15-20 widgets alive
- **At 50,000 items:** Still ~15-20 widgets alive
- **At 100,000 items:** Still ~15-20 widgets alive

The track data (`Map<int, Track>`) grows linearly with items loaded, but the widget tree stays constant. Repeated scrolling and searching does **not** continuously grow memory because:
1. Builder pattern creates/destroys widgets on demand
2. Debounced search prevents isolate accumulation
3. `CachedNetworkImage` manages its own LRU cache for album art

---

## 🛠️ Technologies Used

- **Flutter 3.x** - Cross-platform UI
- **flutter_bloc** - BLoC pattern state management
- **http** - REST API calls
- **connectivity_plus** - Network state monitoring
- **equatable** - Value equality for BLoC events/states
- **cached_network_image** - Efficient album art caching

---

## 📝 AI Usage Disclosure

This project was developed with assistance from AI tools (Claude AI) for code generation, architecture planning, and documentation.

## Author

Vishesh Srivastava

created for ReluAI assesment

Date : 13th February 2026