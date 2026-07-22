import 'package:flutter_test/flutter_test.dart';
import 'package:rideshare_mobile/features/trust/bloc/verifications_cubit.dart';

import 'fakes.dart';

void main() {
  group('VerificationsCubit.uploadAndSubmit', () {
    test('uploads the photo, then submits the returned storage key', () async {
      final repo = FakeTrustRepository();
      final cubit = VerificationsCubit(repo);
      await cubit.load();

      await cubit.uploadAndSubmit(
        type: 'cnic',
        bytes: List.filled(1024, 0),
        contentType: 'image/jpeg',
      );

      // The document went to storage, and its key — not a URL — was submitted.
      expect(repo.uploadedKeys, hasLength(1));
      expect(repo.submittedDocKeys.single, repo.uploadedKeys.single);
      expect(repo.submissions.single.type, 'cnic');

      final state = cubit.state as VerificationsLoaded;
      expect(state.items, hasLength(1));
      expect(state.submitting, isFalse);
      expect(state.uploadProgress, isNull); // cleared once finished
      await cubit.close();
    });

    test('reports upload progress while the photo is in flight', () async {
      final repo = FakeTrustRepository();
      final cubit = VerificationsCubit(repo);
      await cubit.load();

      final seen = <double>[];
      final sub = cubit.stream.listen((s) {
        if (s is VerificationsLoaded && s.uploadProgress != null) {
          seen.add(s.uploadProgress!);
        }
      });

      await cubit.uploadAndSubmit(
        type: 'cnic',
        bytes: List.filled(1024, 0),
        contentType: 'image/jpeg',
      );
      await Future<void>.delayed(Duration.zero);

      expect(seen, isNotEmpty);
      expect(seen.last, 1.0); // reaches 100%
      expect(seen.every((p) => p >= 0 && p <= 1), isTrue);
      await sub.cancel();
      await cubit.close();
    });
  });
}
