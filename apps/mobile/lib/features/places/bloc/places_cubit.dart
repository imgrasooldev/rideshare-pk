import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../rides/data/rides_repository.dart' show Hub;
import '../data/places_repository.dart';

class PlacesState extends Equatable {
  const PlacesState({
    this.city,
    this.hubs = const [],
    this.cities = const [],
    this.loading = false,
  });

  final String? city;
  final List<Hub> hubs;
  final List<City> cities;
  final bool loading;

  bool get ready => hubs.isNotEmpty;

  PlacesState copyWith({
    String? city,
    List<Hub>? hubs,
    List<City>? cities,
    bool? loading,
  }) =>
      PlacesState(
        city: city ?? this.city,
        hubs: hubs ?? this.hubs,
        cities: cities ?? this.cities,
        loading: loading ?? this.loading,
      );

  @override
  List<Object?> get props => [city, hubs, cities, loading];
}

/// Holds the selected city's hubs (for pickup/drop pickers) and the list of
/// available cities (for the location switcher). Everything comes from the DB.
class PlacesCubit extends Cubit<PlacesState> {
  PlacesCubit(this._repo) : super(const PlacesState());
  final PlacesRepository _repo;

  Future<void> load(String city) async {
    final slug = city.trim().isEmpty ? 'lahore' : city.trim().toLowerCase();
    if (state.city == slug && state.hubs.isNotEmpty) return;
    emit(state.copyWith(loading: true, city: slug));
    try {
      final hubs = await _repo.hubs(slug);
      emit(state.copyWith(hubs: hubs, city: slug, loading: false));
    } catch (_) {
      emit(state.copyWith(hubs: const [], loading: false));
    }
    if (state.cities.isEmpty) {
      try {
        emit(state.copyWith(cities: await _repo.cities()));
      } catch (_) {}
    }
  }
}
