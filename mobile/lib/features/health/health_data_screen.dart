import 'package:flutter/material.dart';

import '../tracking/tracking_models.dart' show trackingDate, trackingNumber;
import '../tracking/tracking_progress.dart' show progressDay;
import '../tracking/tracking_widgets.dart' show TrackingCard;
import 'health_models.dart';
import 'health_service.dart';

class HealthDataScreen extends StatefulWidget {
  const HealthDataScreen({super.key, required this.service});
  final HealthService service;
  @override
  State<HealthDataScreen> createState() => _HealthDataScreenState();
}

class _HealthDataScreenState extends State<HealthDataScreen>
    with WidgetsBindingObserver {
  final _selected = HealthMetric.values.toSet();
  HealthSnapshot? _snapshot;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _read(); // Check support/previous Android grants without displaying an OS prompt.
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_loading && _snapshot != null) {
      _read();
    }
  }

  Future<void> _read({bool requestPermissions = false}) async {
    if (_loading || _selected.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await widget.service.read(
        Set.of(_selected),
        requestPermissions: requestPermissions,
      );
      if (mounted) setState(() => _snapshot = snapshot);
    } on Object catch (error) {
      if (mounted) {
        // Do not retain health values after an unsuccessful access recheck.
        setState(() {
          _snapshot = null;
          _error = error is HealthReadException
              ? error.message
              : 'Sağlık platformuna erişilemedi. Cihaz açıkken tekrar deneyin.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _settings({bool install = false}) async {
    try {
      if (install) {
        await widget.service.installHealthConnect();
      } else {
        await widget.service.openSettings();
      }
    } on Object {
      if (mounted) {
        setState(
          () => _error =
              'Sağlık ayarları açılamadı. Cihaz ayarlarından Health Connect uygulama izinlerini açabilirsin.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final supported = snapshot?.availability == HealthAvailability.available;
    final ios = widget.service.platformName == 'HealthKit';
    return Scaffold(
      appBar: AppBar(title: const Text('Sağlık Verileri')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _read,
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
                        widget.service.platformName,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Seçtiğin sağlık verilerini yalnız okuma izninle cihazda gösteriyoruz. Veriler backend’e gönderilmez ve cihazda ayrıca saklanmaz.',
                      ),
                      const SizedBox(height: 16),
                      TrackingCard(
                        children: [
                          Text(
                            'Okunacak veriler',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          for (final metric in HealthMetric.values)
                            CheckboxListTile(
                              key: ValueKey('health-select-${metric.name}'),
                              contentPadding: EdgeInsets.zero,
                              title: Text(metric.label),
                              subtitle: Text(
                                metric == HealthMetric.heartRate
                                    ? 'Son 7 gündeki en son kayıt; canlı ölçüm değil.'
                                    : 'Bugünün toplamı',
                              ),
                              value: _selected.contains(metric),
                              onChanged: _loading
                                  ? null
                                  : (enabled) {
                                      setState(() {
                                        if (enabled == true) {
                                          _selected.add(metric);
                                        } else {
                                          _selected.remove(metric);
                                        }
                                        _snapshot = null;
                                        _error = null;
                                      });
                                    },
                            ),
                          if (_selected.isEmpty)
                            const Text('En az bir veri türü seç.'),
                          const Text(
                            'Yazma, arka plan veya eski geçmişe erişim izni istenmez.',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_loading) ...[
                        const LinearProgressIndicator(),
                        const SizedBox(height: 8),
                        const Text('Sağlık verileri kontrol ediliyor…'),
                        const SizedBox(height: 16),
                      ],
                      if (_error != null) ...[
                        TrackingCard(children: [Text(_error!)]),
                        const SizedBox(height: 16),
                      ],
                      if (snapshot?.availability ==
                          HealthAvailability.unsupported)
                        const TrackingCard(
                          children: [
                            Text(
                              'Bu cihazda sağlık platformu desteklenmiyor veya kullanılamıyor.',
                            ),
                          ],
                        )
                      else if (snapshot?.availability ==
                          HealthAvailability.installRequired)
                        TrackingCard(
                          children: [
                            const Text(
                              'Health Connect kurulmalı veya güncellenmeli.',
                            ),
                            OutlinedButton(
                              onPressed: _loading
                                  ? null
                                  : () => _settings(install: true),
                              child: const Text(
                                'Health Connect’i Kur / Güncelle',
                              ),
                            ),
                          ],
                        )
                      else ...[
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: _loading || _selected.isEmpty
                                  ? null
                                  : () => _read(requestPermissions: true),
                              icon: const Icon(
                                Icons.health_and_safety_outlined,
                              ),
                              label: const Text('İzin Ver ve Oku'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _loading || _selected.isEmpty
                                  ? null
                                  : _read,
                              icon: const Icon(Icons.refresh),
                              label: Text(
                                _error == null ? 'Yenile' : 'Tekrar dene',
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (ios)
                        const Text(
                          'Apple Sağlık, okuma izninin reddedilip reddedilmediğini uygulamayla paylaşmaz. Veri yoksa izin durumunu da Apple Sağlık’tan kontrol et.',
                        ),
                      if (supported) ...[
                        Text('Günlük özet: ${progressDay(snapshot!.day)}'),
                        Text(
                          'Son cihaz okuması: ${trackingDate(snapshot.readAt)}',
                        ),
                        const SizedBox(height: 16),
                        for (final metric in _selected) ...[
                          _metricCard(
                            context,
                            metric,
                            snapshot.readings[metric]!,
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (!ios)
                          OutlinedButton.icon(
                            onPressed: _loading ? null : () => _settings(),
                            icon: const Icon(Icons.settings_outlined),
                            label: const Text('Sağlık İzinlerini Aç'),
                          ),
                        const SizedBox(height: 12),
                        Text(
                          ios
                              ? 'İzinler: Apple Sağlık → profil → Uygulamalar ve Servisler → bu uygulama.'
                              : 'İzinler: Health Connect → Uygulama izinleri → bu uygulama.',
                        ),
                      ],
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

  Widget _metricCard(
    BuildContext context,
    HealthMetric metric,
    HealthMetricReading reading,
  ) => TrackingCard(
    children: [
      Text(metric.label, style: Theme.of(context).textTheme.titleMedium),
      if (reading.status == HealthReadStatus.data) ...[
        Text(
          '${trackingNumber(reading.value!)} ${metric.unit}',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        Text(
          metric == HealthMetric.heartRate
              ? 'Son 7 gündeki en son nabız kaydı'
              : 'Bugünün toplamı',
        ),
        if (reading.recordedAt != null)
          Text('Son kayıt: ${trackingDate(reading.recordedAt!)}'),
        if (reading.sources.isNotEmpty)
          Text('Okunan kayıt kaynakları: ${reading.sources.join(', ')}'),
      ] else
        Text(switch (reading.status) {
          HealthReadStatus.notRequested =>
            'Bu veri henüz okunmadı. İzin Ver ve Oku ile Apple Sağlık erişimini kontrol et.',
          HealthReadStatus.permissionRequired =>
            'Bu veri için okuma izni verilmedi. İzin Ver ve Oku ile erişimi seçebilirsin.',
          HealthReadStatus.noData =>
            'Bu zaman aralığında sağlık kaydı yok. Sağlık platformuna veri yazan bir uygulama veya cihaz gerekir.',
          HealthReadStatus.permissionUnknown =>
            'Bu zaman aralığında veri yok veya Apple Sağlık okuma izni paylaşılmadı.',
          HealthReadStatus.unsupported =>
            'Bu veri türü cihazda desteklenmiyor.',
          HealthReadStatus.failed =>
            'Bu veri okunamadı. İzinleri kontrol edip Yenile’ye dokun.',
          HealthReadStatus.data => '',
        }),
    ],
  );
}
