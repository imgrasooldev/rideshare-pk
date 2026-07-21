import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/categories_repository.dart';

sealed class CategoriesState extends Equatable {
  const CategoriesState();
  @override
  List<Object?> get props => [];
}

final class CategoriesLoading extends CategoriesState {
  const CategoriesLoading();
}

final class CategoriesLoaded extends CategoriesState {
  const CategoriesLoaded(this.items);
  final List<Category> items;
  @override
  List<Object?> get props => [items];
}

final class CategoriesFailed extends CategoriesState {
  const CategoriesFailed();
}

class CategoriesCubit extends Cubit<CategoriesState> {
  CategoriesCubit(this._repo) : super(const CategoriesLoading());
  final CategoriesRepository _repo;

  Future<void> load() async {
    try {
      emit(CategoriesLoaded(await _repo.list()));
    } catch (_) {
      emit(const CategoriesFailed());
    }
  }
}
