import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/connectivity_service.dart';

/// Connectivity events.
abstract class ConnectivityEvent {}

class ConnectivityChanged extends ConnectivityEvent {
  final bool isConnected;
  ConnectivityChanged(this.isConnected);
}

class CheckConnectivity extends ConnectivityEvent {}

/// Connectivity states.
abstract class ConnectivityState {}

class ConnectivityInitial extends ConnectivityState {}
class ConnectivityOnline extends ConnectivityState {}
class ConnectivityOffline extends ConnectivityState {}

/// BLoC that tracks online/offline state.
class ConnectivityBloc extends Bloc<ConnectivityEvent, ConnectivityState> {
  final ConnectivityService _service;
  StreamSubscription<bool>? _subscription;

  ConnectivityBloc({required ConnectivityService service})
      : _service = service,
        super(ConnectivityInitial()) {
    on<ConnectivityChanged>(_onChanged);
    on<CheckConnectivity>(_onCheck);

    // Start listening
    _subscription = _service.onConnectivityChanged.listen((isConnected) {
      add(ConnectivityChanged(isConnected));
    });
    _service.initialize();

    // Check immediately
    add(CheckConnectivity());
  }

  void _onChanged(ConnectivityChanged event, Emitter<ConnectivityState> emit) {
    emit(event.isConnected ? ConnectivityOnline() : ConnectivityOffline());
  }

  Future<void> _onCheck(
    CheckConnectivity event,
    Emitter<ConnectivityState> emit,
  ) async {
    final isConnected = await _service.isConnected();
    emit(isConnected ? ConnectivityOnline() : ConnectivityOffline());
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
