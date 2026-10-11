import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/api_service.dart';
import 'running_models.dart';
import 'running_service.dart';
import 'running_tracker.dart';
import 'running_widgets.dart';

class RunningTrackingScreen extends StatefulWidget {
  const RunningTrackingScreen({
    super.key,
    required this.service,
    this.draft,
    this.tracker,
  });
  final RunningService service;
  final RunningDraft? draft;
  final RunningTracker? tracker;
  @override
  State<RunningTrackingScreen> createState() => _RunningTrackingScreenState();
}

class _RunningTrackingScreenState extends State<RunningTrackingScreen>
    with WidgetsBindingObserver {
  late final RunningTracker _tracker;
  RunningDraft? _draft;
  RunningActivity? _saved;
  bool _saving = false, _stored = false, _discarded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tracker = widget.tracker ?? RunningTracker();
    _draft = widget.draft;
    _stored = _draft != null;
    _tracker.addListener(_changed);
    WidgetsBinding.instance.addObserver(this);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ([
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.detached,
    ].contains(state)) {
      _tracker.setForeground(false);
    } else if (state == AppLifecycleState.resumed) {
      _tracker.setForeground(true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tracker.removeListener(_changed);
    _tracker.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final draft = _tracker.finish();
    if (draft == null) return;
    setState(() => _draft = draft);
    await _save();
  }

  Future<void> _save() async {
    if (_saving || _draft == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.service.storeDraft(_draft!);
      if (mounted) setState(() => _stored = true);
      final saved = await widget.service.save(_draft!);
      if (mounted) setState(() => _saved = saved);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Object {
      if (mounted) {
        setState(
          () => _error =
              'Koşu kaydedilemedi. Özet bu ekranda korunuyor; tekrar deneyin.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _blockedBack() async {
    if (_saving) return;
    if (_draft == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Önce koşuyu bitir.')));
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kaydedilmeden çıkılsın mı?'),
        content: const Text(
          'Bu koşu cihazda korunamadı. Çıkarsan kayıt kaybolur.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Kal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Kaydı bırak'),
          ),
        ],
      ),
    );
    if (discard != true || !mounted) return;
    setState(() => _discarded = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _openSettings(LocationAction action) async {
    try {
      final opened = action == LocationAction.gps
          ? await Geolocator.openLocationSettings()
          : await Geolocator.openAppSettings();
      if (!opened && mounted) {
        setState(
          () => _error =
              'Ayarlar açılamadı. Telefon ayarlarından konum izni ve GPS durumunu kontrol et.',
        );
      }
    } on Object {
      if (mounted) {
        setState(
          () => _error =
              'Telefon ayarlarından konum izni ve GPS durumunu kontrol et.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canLeave =
        !_saving &&
        (_discarded ||
            _saved != null ||
            _stored ||
            _tracker.state == RunningState.ready && _draft == null);
    final run = _saved;
    return PopScope(
      canPop: canLeave,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _blockedBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_draft == null ? 'Canlı Koşu' : 'Koşu Özeti'),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _draft != null
                            ? run == null
                                  ? 'Koşu tamamlandı'
                                  : 'Koşu kaydedildi'
                            : switch (_tracker.state) {
                                RunningState.running => 'Koşu sürüyor',
                                RunningState.paused => 'Koşu duraklatıldı',
                                _ => 'Koşuya hazır',
                              },
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      RunningStats(
                        durationSeconds:
                            run?.durationSeconds ??
                            _draft?.durationSeconds ??
                            _tracker.durationSeconds,
                        distanceMeters:
                            run?.distanceMeters ??
                            _draft?.distanceMeters ??
                            _tracker.distanceMeters,
                        pace: run == null
                            ? _draft?.pace ?? _tracker.pace
                            : run.pace,
                        speed: run?.speed ?? _draft?.speed ?? _tracker.speed,
                      ),
                      RunningRouteView(
                        segments:
                            run?.segments ??
                            _draft?.segments ??
                            _tracker.segments,
                      ),
                      const SizedBox(height: 16),
                      if (_draft == null) ...[
                        const Text(
                          'Konum yalnız bu ekranda kullanılır. Duraklama süre ve mesafeye eklenmez. Uygulama arka plana geçtiğinde koşu duraklar.',
                        ),
                        const SizedBox(height: 12),
                        if (_tracker.message != null) Text(_tracker.message!),
                        if (_tracker.action != null)
                          TextButton.icon(
                            onPressed: () => _openSettings(_tracker.action!),
                            icon: const Icon(Icons.settings_outlined),
                            label: const Text('Konum Ayarlarını Aç'),
                          ),
                        if (_tracker.busy) const LinearProgressIndicator(),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            if (_tracker.state == RunningState.running)
                              OutlinedButton(
                                onPressed: _tracker.busy
                                    ? null
                                    : _tracker.pause,
                                child: const Text('Duraklat'),
                              )
                            else
                              FilledButton(
                                onPressed: _tracker.busy
                                    ? null
                                    : _tracker.startOrResume,
                                child: Text(
                                  _tracker.state == RunningState.paused
                                      ? 'Devam Et'
                                      : 'Başlat',
                                ),
                              ),
                            if (_tracker.state != RunningState.ready)
                              FilledButton(
                                onPressed: _tracker.busy ? null : _finish,
                                child: const Text('Bitir'),
                              ),
                          ],
                        ),
                      ],
                      if (_saving) ...[
                        const LinearProgressIndicator(),
                        const Text('Koşu kaydediliyor…'),
                      ],
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(_error!),
                        ),
                      if (_draft != null && run == null && !_saving) ...[
                        Text(
                          _stored
                              ? 'Özet bu cihazda saklandı. Ağ hatasında buradan veya Koşu geçmişinden yeniden kaydedebilirsin.'
                              : 'Bu ekrandan çıkmadan kaydı tekrar dene.',
                        ),
                        FilledButton.icon(
                          onPressed: _save,
                          icon: const Icon(Icons.cloud_upload_outlined),
                          label: const Text('Kaydı Tekrar Dene'),
                        ),
                      ],
                      if (run != null)
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Koşu Geçmişine Dön'),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
