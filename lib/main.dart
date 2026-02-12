import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'bloc/connectivity/connectivity_bloc.dart';
import 'bloc/library/library_bloc.dart';
import 'repositories/music_repository.dart';
import 'screens/library_screen.dart';
import 'services/connectivity_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MusicLibraryApp());
}

class MusicLibraryApp extends StatefulWidget {
  const MusicLibraryApp({super.key});

  @override
  State<MusicLibraryApp> createState() => _MusicLibraryAppState();
}

class _MusicLibraryAppState extends State<MusicLibraryApp> {
  late final MusicRepository _repository;
  late final ConnectivityService _connectivityService;

  @override
  void initState() {
    super.initState();
    _repository = MusicRepository();
    _connectivityService = ConnectivityService();
  }

  @override
  void dispose() {
    _repository.dispose();
    _connectivityService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<MusicRepository>.value(value: _repository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<ConnectivityBloc>(
            create: (_) =>
                ConnectivityBloc(service: _connectivityService),
          ),
          BlocProvider<LibraryBloc>(
            create: (_) => LibraryBloc(repository: _repository),
          ),
        ],
        child: MaterialApp(
          title: 'Music Library',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          home: const LibraryScreen(),
        ),
      ),
    );
  }
}
