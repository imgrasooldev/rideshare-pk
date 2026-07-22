import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/wallet_repository.dart';

sealed class WalletState extends Equatable {
  const WalletState();
  @override
  List<Object?> get props => [];
}

final class WalletLoading extends WalletState {
  const WalletLoading();
}

final class WalletLoaded extends WalletState {
  const WalletLoaded(this.wallet, this.history);
  final Wallet wallet;
  final List<Settlement> history;
  @override
  List<Object?> get props => [wallet, history];
}

final class WalletFailed extends WalletState {
  const WalletFailed();
}

class WalletCubit extends Cubit<WalletState> {
  WalletCubit(this._repo) : super(const WalletLoading());
  final WalletRepository _repo;

  Future<void> load() async {
    emit(const WalletLoading());
    try {
      final wallet = await _repo.fetch();
      final history = await _repo.history();
      emit(WalletLoaded(wallet, history));
    } catch (_) {
      emit(const WalletFailed());
    }
  }

  /// Returns null on success, or an error message.
  Future<String?> settle(int amount, {String? reference}) async {
    try {
      await _repo.settle(amount, reference: reference);
      await load();
      return null;
    } catch (e) {
      return 'Could not record settlement';
    }
  }
}
