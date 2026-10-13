import 'package:flutter/material.dart';

import '../../core/api_service.dart';
import '../health/health_data_screen.dart';
import '../health/health_service.dart';
import '../nutrition/nutrition_models.dart';
import '../nutrition/nutrition_screen.dart';
import '../nutrition/nutrition_service.dart';
import '../nutrition/nutrition_summary_card.dart';
import '../running/running_models.dart';
import '../running/running_screen.dart';
import '../running/running_service.dart';
import 'tracking_entry_screen.dart';
import 'tracking_models.dart';
import 'tracking_progress.dart';
import 'tracking_service.dart';
import 'tracking_widgets.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({
    super.key,
    required this.api,
    required this.active,
    required this.userId,
  });
  final ApiService api;
  final String userId;
  final bool active;
  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen>
    with WidgetsBindingObserver {
  final _weights = _TrackingData<List<WeightRecord>>();
  final _measurements = _TrackingData<List<BodyMeasurement>>();
  final _nutrition = _TrackingData<NutritionDailySummary>();
  final _running = _TrackingData<List<RunningActivity>>();
  bool _requested = false;
  TrackingPeriod _period = TrackingPeriod.month;
  String _measurement = 'waistCm';
  DateTime _day = DateUtils.dateOnly(DateTime.now());
  TrackingService get _service => TrackingService(widget.api);
  NutritionService get _nutritionService => NutritionService(widget.api);
  RunningService get _runningService =>
      RunningService(widget.api, widget.userId);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.active) _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        widget.active &&
        !DateUtils.isSameDay(_day, DateTime.now())) {
      _loadNutrition();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TrackingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_requested) _load();
    // A preserved tab may be revisited after midnight.
    if (widget.active &&
        !oldWidget.active &&
        !DateUtils.isSameDay(_day, DateTime.now())) {
      _day = DateUtils.dateOnly(DateTime.now());
      _nutrition.data = null;
      _loadNutrition();
    }
  }

  Future<void> _loadData<T>(
    _TrackingData<T> state,
    Future<T> Function() load,
  ) async {
    final request = ++state.request;
    setState(() {
      state.loading = true;
      state.error = null;
    });
    try {
      final data = await load();
      if (mounted && request == state.request) {
        setState(() => state.data = data);
      }
    } on Object catch (error) {
      if (mounted && request == state.request) {
        setState(
          () => state.error = error is ApiException
              ? error.message
              : 'Kayıtlar yüklenemedi. Tekrar deneyin.',
        );
      }
    } finally {
      if (mounted && request == state.request) {
        setState(() => state.loading = false);
      }
    }
  }

  Future<void> _loadWeights() => _loadData(_weights, _service.getWeightRecords);
  Future<void> _loadMeasurements() =>
      _loadData(_measurements, _service.getBodyMeasurements);
  Future<void> _loadNutrition() {
    final today = DateUtils.dateOnly(DateTime.now());
    if (!DateUtils.isSameDay(_day, today)) {
      _day = today;
      _nutrition.data = null;
    }
    final day = _day;
    return _loadData(_nutrition, () => _nutritionService.getDailySummary(day));
  }

  Future<void> _loadRunning() =>
      _loadData(_running, _runningService.getActivities);
  Future<void> _load() async {
    _requested = true;
    await Future.wait([
      _loadWeights(),
      _loadMeasurements(),
      _loadNutrition(),
      _loadRunning(),
    ]);
  }

  Future<void> _add(TrackingEntryType type) async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TrackingEntryScreen(service: _service, type: type),
      ),
    );
    if (!mounted || saved != true) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Kayıt eklendi.')));
    if (type == TrackingEntryType.weight) {
      await _loadWeights();
    } else {
      await _loadMeasurements();
    }
  }

  Future<void> _openNutrition() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => NutritionScreen(service: _nutritionService),
      ),
    );
    if (mounted) await _loadNutrition();
  }

  Future<void> _openRunning() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => RunningScreen(service: _runningService),
      ),
    );
    if (mounted) await _loadRunning();
  }

  Widget _section<T>(
    String title,
    _TrackingData<T> data,
    VoidCallback retry,
    List<Widget> children,
  ) => TrackingSection(
    title: title,
    loading: data.loading,
    error: data.error,
    hasData: data.data != null,
    retry: retry,
    children: children,
  );

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weights = (_weights.data ?? [])
        .where((r) => _period.contains(r.recordedAt, now))
        .toList();
    final measurements = (_measurements.data ?? [])
        .where((r) => _period.contains(r.recordedAt, now))
        .toList();
    final runs = (_running.data ?? [])
        .where((r) => _period.contains(r.startedAt, now))
        .toList();
    final totals = runningTotals(runs);
    final latest = _weights.data?.firstOrNull;
    final measurementPoints = progressSeries([
      for (final record in measurements)
        if (record.values[_measurement] != null)
          (at: record.recordedAt, value: record.values[_measurement]!),
    ]);
    final unit = _measurement == 'bodyFatPercentage' ? '%' : 'cm';
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          key: const PageStorageKey('tracking-records'),
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
                      'Gelişimin',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Kilo, ölçüm, beslenme ve koşu kayıtlarını bir arada takip et.',
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _openNutrition,
                          icon: const Icon(Icons.restaurant_outlined),
                          label: const Text('Beslenme'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _openRunning,
                          icon: const Icon(Icons.directions_run),
                          label: const Text('Koşu'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) =>
                                  HealthDataScreen(service: HealthService()),
                            ),
                          ),
                          icon: const Icon(Icons.favorite_outline),
                          label: const Text('Sağlık Verileri'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: () => _add(TrackingEntryType.weight),
                          icon: const Icon(Icons.add),
                          label: const Text('Kilo Ekle'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _add(TrackingEntryType.measurements),
                          icon: const Icon(Icons.straighten),
                          label: const Text('Ölçüm Ekle'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text('Gelişim dönemi'),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final period in TrackingPeriod.values)
                          ChoiceChip(
                            label: Text(period.label),
                            selected: period == _period,
                            onSelected: (_) => setState(() => _period = period),
                          ),
                      ],
                    ),
                    const Text(
                      'Kilo, ölçüm ve koşu için; bugün dahil yerel takvim günleri.',
                    ),
                    const SizedBox(height: 24),
                    _section('Kilo gelişimi', _weights, _loadWeights, [
                      if (_weights.data != null) ...[
                        TrackingCard(
                          children: [
                            Text(
                              'Güncel kilo',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              latest == null
                                  ? 'Henüz kilo kaydı yok'
                                  : '${trackingNumber(latest.weightKg)} kg',
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                            ),
                            Text(
                              latest == null
                                  ? 'İlk kilo kaydını ekleyebilirsin.'
                                  : trackingDate(latest.recordedAt),
                            ),
                            const Divider(),
                            Text('${_period.label} • ${weights.length} kayıt'),
                            ProgressChart(
                              points: progressSeries([
                                for (final r in weights)
                                  (at: r.recordedAt, value: r.weightKg),
                              ]),
                              unit: 'kg',
                              empty: 'Bu dönemde kilo kaydı yok.',
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _history(
                          context,
                          'Kilo geçmişi',
                          'Bu dönemde kilo kaydı yok.',
                          [
                            for (final r in weights)
                              ListTile(
                                leading: const Icon(
                                  Icons.monitor_weight_outlined,
                                ),
                                title: Text('${trackingNumber(r.weightKg)} kg'),
                                subtitle: Text(trackingDate(r.recordedAt)),
                              ),
                          ],
                        ),
                      ],
                    ]),
                    const SizedBox(height: 24),
                    _section(
                      'Vücut ölçümü gelişimi',
                      _measurements,
                      _loadMeasurements,
                      [
                        if (_measurements.data != null) ...[
                          TrackingCard(
                            children: [
                              DropdownButtonFormField<String>(
                                key: const ValueKey('progress-measurement'),
                                initialValue: _measurement,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Ölçüm türü',
                                ),
                                items: [
                                  for (final entry in measurementLabels.entries)
                                    DropdownMenuItem(
                                      value: entry.key,
                                      child: Text(entry.value),
                                    ),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _measurement = value);
                                  }
                                },
                              ),
                              if (measurementPoints.isNotEmpty)
                                Text(
                                  'Son ölçüm: ${trackingNumber(measurementPoints.last.value)} $unit • ${trackingDate(measurementPoints.last.at)}',
                                ),
                              Text(
                                '${_period.label} • ${measurementPoints.length} ölçüm zamanı',
                              ),
                              ProgressChart(
                                points: measurementPoints,
                                unit: unit,
                                empty:
                                    'Bu dönemde seçili ölçüm için kayıt yok.',
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _history(
                            context,
                            'Ölçüm geçmişi',
                            _measurements.data!.isEmpty
                                ? 'Henüz vücut ölçümü kaydı yok.'
                                : 'Bu dönemde vücut ölçümü kaydı yok.',
                            [
                              for (final r in measurements)
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        trackingDate(r.recordedAt),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleSmall,
                                      ),
                                      for (final entry in r.values.entries)
                                        if (entry.value != null)
                                          Text(
                                            '${measurementLabels[entry.key]}: ${trackingNumber(entry.value!)} ${entry.key == 'bodyFatPercentage' ? '%' : 'cm'}',
                                          ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 24),
                    _section(
                      'Günlük kalori ve makrolar',
                      _nutrition,
                      _loadNutrition,
                      [
                        Text('${progressDay(_day)} • Bugün'),
                        const SizedBox(height: 12),
                        if (_nutrition.data != null)
                          NutritionSummaryCard(summary: _nutrition.data!),
                        TextButton.icon(
                          onPressed: _openNutrition,
                          icon: const Icon(Icons.restaurant_outlined),
                          label: const Text('Öğün ekle / gün seç / geçmiş'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _section('Koşu özeti', _running, _loadRunning, [
                      if (_running.data != null)
                        TrackingCard(
                          children: [
                            Text(
                              '${_period.label} • ${totals.count} koşu',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (runs.isEmpty)
                              Text(
                                _running.data!.isEmpty
                                    ? 'Henüz koşu kaydı yok.'
                                    : 'Bu dönemde koşu kaydı yok.',
                              )
                            else ...[
                              Text(
                                'Toplam mesafe: ${trackingNumber(totals.distanceMeters / 1000)} km',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                'Toplam aktif süre: ${runningDuration(totals.durationSeconds)}',
                              ),
                              const Text(
                                'Duraklama süreleri dahil değildir. Koşular başlangıç tarihine göre filtrelenir.',
                              ),
                            ],
                            OutlinedButton.icon(
                              onPressed: _openRunning,
                              icon: const Icon(Icons.directions_run),
                              label: const Text('Koşu geçmişini aç'),
                            ),
                          ],
                        ),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _history(
    BuildContext context,
    String title,
    String empty,
    List<Widget> items,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      if (items.isEmpty)
        TrackingCard(children: [Text(empty)])
      else
        Card(
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                items[i],
              ],
            ],
          ),
        ),
    ],
  );
}

// Screen-local state: each existing API can succeed, fail or retry independently.
class _TrackingData<T> {
  T? data;
  bool loading = false;
  String? error;
  int request = 0;
}
