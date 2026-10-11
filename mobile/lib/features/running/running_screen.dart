import 'package:flutter/material.dart';

import '../../core/api_service.dart';
import '../tracking/tracking_models.dart' show trackingDate;
import 'running_models.dart';
import 'running_service.dart';
import 'running_tracking_screen.dart';
import 'running_widgets.dart';

class RunningScreen extends StatefulWidget {
  const RunningScreen({super.key, required this.service});
  final RunningService service;
  @override
  State<RunningScreen> createState() => _RunningScreenState();
}

class _RunningScreenState extends State<RunningScreen> {
  List<RunningActivity> _runs = [];
  RunningDraft? _draft;
  bool _loading = true, _loaded = false, _draftChecked = false;
  int _request = 0;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _draftChecked = false;
      _error = null;
    });
    try {
      final draft = await widget.service.readDraft();
      if (!mounted || request != _request) return;
      setState(() {
        _draft = draft;
        _draftChecked = true;
      });
      final runs = await widget.service.getActivities();
      if (mounted && request == _request) {
        setState(() {
          _runs = runs;
          _loaded = true;
        });
      }
    } on ApiException catch (error) {
      if (mounted && request == _request) {
        setState(() => _error = error.message);
      }
    } on Object {
      if (mounted && request == _request) {
        setState(() => _error = 'Koşu geçmişi yüklenemedi. Tekrar deneyin.');
      }
    } finally {
      if (mounted && request == _request) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openRun() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            RunningTrackingScreen(service: widget.service, draft: _draft),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Koşu')),
    body: SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Koşu geçmişi',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    if (_loading) ...[
                      const LinearProgressIndicator(),
                      const Text('Koşular yükleniyor…'),
                    ],
                    if (_error != null)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_error!),
                              if (_loaded)
                                const Text(
                                  'Son yüklenen kayıtlar gösteriliyor.',
                                ),
                              TextButton(
                                onPressed: _loading ? null : _load,
                                child: const Text('Tekrar dene'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    if (_draft != null)
                      const Text(
                        'Kaydedilmeyi bekleyen koşun var. Önce bu kaydı tamamla.',
                      ),
                    FilledButton.icon(
                      onPressed: !_draftChecked ? null : _openRun,
                      icon: const Icon(Icons.directions_run),
                      label: Text(
                        _draft == null
                            ? 'Koşuyu Başlat'
                            : 'Kaydedilmemiş Koşuyu Aç',
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_loaded && _runs.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('Henüz koşu kaydı yok.'),
                        ),
                      ),
                    for (final run in _runs)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(trackingDate(run.startedAt)),
                              RunningStats(
                                durationSeconds: run.durationSeconds,
                                distanceMeters: run.distanceMeters,
                                pace: run.pace,
                                speed: run.speed,
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).push<void>(
                                      MaterialPageRoute(
                                        builder: (_) => RunningDetailScreen(
                                          service: widget.service,
                                          id: run.id,
                                        ),
                                      ),
                                    ),
                                child: const Text('Koşu Detayını Gör'),
                              ),
                            ],
                          ),
                        ),
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

class RunningDetailScreen extends StatefulWidget {
  const RunningDetailScreen({
    super.key,
    required this.service,
    required this.id,
  });
  final RunningService service;
  final String id;
  @override
  State<RunningDetailScreen> createState() => _RunningDetailScreenState();
}

class _RunningDetailScreenState extends State<RunningDetailScreen> {
  RunningActivity? _run;
  String? _error;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final run = await widget.service.getActivity(widget.id);
      if (mounted) setState(() => _run = run);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Object {
      if (mounted) {
        setState(() => _error = 'Koşu detayı yüklenemedi. Tekrar deneyin.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Koşu Detayı')),
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
                  if (_loading) const LinearProgressIndicator(),
                  if (_error != null) ...[
                    Text(_error!),
                    TextButton(
                      onPressed: _loading ? null : _load,
                      child: const Text('Tekrar dene'),
                    ),
                  ],
                  if (_run case final run?) ...[
                    Text('Başlangıç: ${trackingDate(run.startedAt)}'),
                    Text('Bitiş: ${trackingDate(run.endedAt)}'),
                    RunningStats(
                      durationSeconds: run.durationSeconds,
                      distanceMeters: run.distanceMeters,
                      pace: run.pace,
                      speed: run.speed,
                    ),
                    RunningRouteView(segments: run.segments ?? []),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
