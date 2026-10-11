import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/api_service.dart';
import '../../core/app_config.dart';
import 'running_models.dart';

class RunningService {
  RunningService(this.api, String userId, {FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage(),
      _draftKey =
          'running_draft_${base64Url.encode(utf8.encode('${api.config.apiBaseUrl}|$userId'))}';
  final ApiService api;
  final FlutterSecureStorage _storage;
  final String _draftKey;
  Future<void> _pending = Future.value();
  static const path = '/api/users/me/running-activities';

  Future<List<RunningActivity>> getActivities() async {
    final json = await api.getList(path);
    try {
      return json
          .map((item) => RunningActivity.fromJson(item as Map<String, dynamic>))
          .toList();
    } on Object {
      throw const ApiException('Koşu geçmişi okunamadı. Tekrar deneyin.');
    }
  }

  Future<RunningActivity> getActivity(String id) async {
    final json = await api.get('/api/running-activities/$id');
    try {
      return RunningActivity.fromJson(json);
    } on Object {
      throw const ApiException('Koşu detayı okunamadı. Tekrar deneyin.');
    }
  }

  Future<RunningActivity> save(RunningDraft draft) async {
    final json = await api.post(path, draft.toJson(), authenticated: true);
    final RunningActivity run;
    try {
      run = RunningActivity.fromJson(json);
    } on Object {
      throw const ApiException(
        'Koşu yanıtı okunamadı. Aynı kaydı tekrar deneyin.',
      );
    }
    await clearDraft();
    return run;
  }

  Future<RunningDraft?> readDraft() async {
    try {
      final value = await _read().timeout(AppConfig.storageTimeout);
      return value == null
          ? null
          : RunningDraft.fromJson(jsonDecode(value) as Map<String, dynamic>);
    } on Object {
      throw const ApiException(
        'Kaydedilmemiş koşu cihazdan okunamadı. Tekrar deneyin.',
      );
    }
  }

  Future<String?> _read() async {
    await _pending;
    return _storage.read(key: _draftKey);
  }

  Future<void> storeDraft(RunningDraft draft) => _enqueue(
    () => _storage.write(key: _draftKey, value: jsonEncode(draft.toJson())),
  );
  Future<void> clearDraft() => _enqueue(() => _storage.delete(key: _draftKey));

  // Native writes remain ordered even if their caller times out.
  Future<void> _enqueue(Future<void> Function() operation) {
    final result = _pending.then((_) => operation());
    _pending = result.then((_) {}, onError: (Object _, StackTrace _) {});
    return result.timeout(AppConfig.storageTimeout);
  }
}
