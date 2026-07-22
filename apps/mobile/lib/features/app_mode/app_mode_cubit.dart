import 'package:flutter_bloc/flutter_bloc.dart';

/// The two faces of the super-app. Passenger mode is booking-focused; driver
/// mode is earning-focused. A user with a driver role can switch between them;
/// the whole shell (tabs, home, actions) changes with the mode.
enum AppMode { passenger, driver }

class AppModeState {
  const AppModeState({this.mode = AppMode.passenger, this.online = false});

  /// Current experience.
  final AppMode mode;

  /// Driver online/offline availability (client-side for now; drives the
  /// dashboard toggle and later feeds request matching).
  final bool online;

  AppModeState copyWith({AppMode? mode, bool? online}) =>
      AppModeState(mode: mode ?? this.mode, online: online ?? this.online);
}

class AppModeCubit extends Cubit<AppModeState> {
  AppModeCubit() : super(const AppModeState());

  void toPassenger() => emit(state.copyWith(mode: AppMode.passenger));
  void toDriver() => emit(state.copyWith(mode: AppMode.driver));
  void setOnline(bool value) => emit(state.copyWith(online: value));

  /// Drop back to passenger mode (e.g. on logout or role loss).
  void reset() => emit(const AppModeState());
}
