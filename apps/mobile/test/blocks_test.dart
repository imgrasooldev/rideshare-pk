import 'package:flutter_test/flutter_test.dart';
import 'package:rideshare_mobile/core/network/api_exception.dart';
import 'package:rideshare_mobile/features/safety/bloc/blocks_cubit.dart';
import 'package:rideshare_mobile/features/safety/data/blocks_repository.dart';

class FakeBlocksRepository implements BlocksRepository {
  final List<BlockedUser> people = [];
  bool failNext = false;

  @override
  Future<List<BlockedUser>> mine() async => List.of(people);

  @override
  Future<void> block(String userId, {String? reason}) async {
    if (failNext) throw const ApiException('nope', statusCode: 500);
    people.add(BlockedUser(userId: userId, createdAt: DateTime.now(), reason: reason));
  }

  @override
  Future<void> unblock(String userId) async {
    people.removeWhere((p) => p.userId == userId);
  }
}

void main() {
  group('BlocksCubit', () {
    test('loads the blocklist', () async {
      final repo = FakeBlocksRepository()
        ..people.add(BlockedUser(userId: 'u9', createdAt: DateTime.now(), name: 'Ali'));
      final cubit = BlocksCubit(repo);

      await cubit.load();
      final state = cubit.state as BlocksLoaded;
      expect(state.people.single.userId, 'u9');
      expect(state.people.single.label, 'Ali');
      await cubit.close();
    });

    test('blocking adds the person and refreshes the loaded list', () async {
      final repo = FakeBlocksRepository();
      final cubit = BlocksCubit(repo);
      await cubit.load();

      final ok = await cubit.block('u9', reason: 'Safety concern');
      expect(ok, isTrue);
      final state = cubit.state as BlocksLoaded;
      expect(state.people.single.userId, 'u9');
      expect(state.people.single.reason, 'Safety concern');
      await cubit.close();
    });

    test('reports failure without throwing, so callers can show a message', () async {
      final repo = FakeBlocksRepository()..failNext = true;
      final cubit = BlocksCubit(repo);
      await cubit.load();

      expect(await cubit.block('u9'), isFalse);
      expect((cubit.state as BlocksLoaded).people, isEmpty);
      await cubit.close();
    });

    test('unblocking removes the person from the list', () async {
      final repo = FakeBlocksRepository()
        ..people.add(BlockedUser(userId: 'u9', createdAt: DateTime.now()));
      final cubit = BlocksCubit(repo);
      await cubit.load();

      await cubit.unblock('u9');
      expect((cubit.state as BlocksLoaded).people, isEmpty);
      expect(repo.people, isEmpty);
      await cubit.close();
    });

    test('label falls back to a short id when the name is unknown', () {
      final anon = BlockedUser(userId: 'abcdef1234567890', createdAt: DateTime.now());
      expect(anon.label, 'User abcdef12');
    });
  });
}
