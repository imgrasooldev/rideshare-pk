import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App language, persisted across launches. English default; Urdu supported.
class LocaleCubit extends Cubit<Locale> {
  LocaleCubit() : super(const Locale('en')) {
    _load();
  }

  static const _key = 'app_locale';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key);
    if (code != null && code.isNotEmpty) emit(Locale(code));
  }

  Future<void> setLocale(String code) async {
    emit(Locale(code));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, code);
  }
}
