import '../../../core/network/api_client.dart';
import 'models/verification.dart';

/// A signed slot to upload one document into private storage.
class UploadSlot {
  const UploadSlot({required this.uploadUrl, required this.key});

  factory UploadSlot.fromJson(Map<String, dynamic> json) => UploadSlot(
        uploadUrl: json['uploadUrl'] as String,
        key: json['key'] as String,
      );

  final String uploadUrl;
  final String key;
}

class TrustRepository {
  TrustRepository(this._api);

  final ApiClient _api;

  /// Uploads a document straight to private storage and returns the storage
  /// key to submit. The photo never passes through our API.
  Future<String> uploadDocument({
    required String purpose,
    required List<int> bytes,
    required String contentType,
    void Function(int sent, int total)? onProgress,
  }) async {
    final slot = UploadSlot.fromJson(
      await _api.post('/uploads/sign', body: {
        'purpose': purpose,
        'contentType': contentType,
      }),
    );
    await _api.putSigned(slot.uploadUrl, bytes, contentType, onProgress: onProgress);
    return slot.key;
  }

  /// Supply either [docKey] (uploaded) or [docUrl] (external link).
  Future<Verification> submit({
    required String type,
    String? docKey,
    String? docUrl,
    String? vehicleId,
  }) async {
    final res = await _api.post('/verifications', body: {
      'type': type,
      'docKey': ?docKey,
      'docUrl': ?docUrl,
      'vehicleId': ?vehicleId,
    });
    return Verification.fromJson(res);
  }

  Future<List<Verification>> mine() async {
    final list = await _api.getList('/verifications/mine');
    return list.map((e) => Verification.fromJson(e as Map<String, dynamic>)).toList();
  }
}
