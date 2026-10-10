import 'package:flutter/material.dart';

import '../../core/api_service.dart';
import 'tracking_entry_screen.dart';
import 'tracking_models.dart';
import 'tracking_service.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key, required this.api, required this.active});
  final ApiService api;
  final bool active;
  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  List<WeightRecord> _weights = [];
  List<BodyMeasurement> _measurements = [];
  bool _loading = false;
  bool _requested = false;
  bool _hasData = false;
  String? _error;
  TrackingService get _service => TrackingService(widget.api);

  @override
  void initState() {
    super.initState();
    if (widget.active) _load();
  }

  @override
  void didUpdateWidget(covariant TrackingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_requested) _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _requested = true;
      _error = null;
    });
    try {
      final results = await Future.wait<Object>([
        _service.getWeightRecords(),
        _service.getBodyMeasurements(),
      ]);
      if (mounted) {
        setState(() {
          _weights = results[0] as List<WeightRecord>;
          _measurements = results[1] as List<BodyMeasurement>;
          _hasData = true;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Object {
      if (mounted) {
        setState(() => _error = 'Kayıtlar yüklenemedi. Tekrar deneyin.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add(TrackingEntryType type) async {
    // A previous save notice must not cover actions on the next form.
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
    await _load();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
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
                    'Kilo ve Vücut Ölçümleri',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text('Kayıtlarını ekle, geçmişini takip et.'),
                  const SizedBox(height: 20),
                  if (_loading) ...[
                    const LinearProgressIndicator(),
                    const SizedBox(height: 8),
                    const Text('Kayıtlar yükleniyor…'),
                    const SizedBox(height: 16),
                  ],
                  if (_error != null) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_error!),
                            if (_hasData)
                              const Text('Son yüklenen kayıtlar gösteriliyor.'),
                            TextButton.icon(
                              onPressed: _loading ? null : _load,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Tekrar dene'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
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
                  const SizedBox(height: 24),
                  if (_hasData) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Güncel kilo',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _weights.isEmpty
                                  ? 'Henüz kilo kaydı yok'
                                  : '${trackingNumber(_weights.first.weightKg)} kg',
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _weights.isEmpty
                                  ? 'İlk kilo kaydını ekleyebilirsin.'
                                  : trackingDate(_weights.first.recordedAt),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _history(
                      context,
                      title: 'Kilo geçmişi',
                      empty: 'Henüz kilo kaydı yok.',
                      items: [
                        for (final record in _weights)
                          ListTile(
                            title: Text(
                              '${trackingNumber(record.weightKg)} kg',
                            ),
                            subtitle: Text(trackingDate(record.recordedAt)),
                            leading: const Icon(Icons.monitor_weight_outlined),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _history(
                      context,
                      title: 'Ölçüm geçmişi',
                      empty: 'Henüz vücut ölçümü kaydı yok.',
                      items: [
                        for (final record in _measurements)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  trackingDate(record.recordedAt),
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 8),
                                for (final value in record.values.entries)
                                  if (value.value != null)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(
                                        '${measurementLabels[value.key]}: ${trackingNumber(value.value!)} ${value.key == 'bodyFatPercentage' ? '%' : 'cm'}',
                                      ),
                                    ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _history(
    BuildContext context, {
    required String title,
    required String empty,
    required List<Widget> items,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      if (items.isEmpty)
        Card(
          child: Padding(padding: const EdgeInsets.all(20), child: Text(empty)),
        )
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
