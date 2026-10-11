import 'package:flutter/material.dart';

import '../../core/api_service.dart';
import '../assignments/assignment_models.dart' show assignmentDate;
import '../tracking/tracking_models.dart' show trackingDate, trackingNumber;
import 'nutrition_entry_screen.dart';
import 'nutrition_models.dart';
import 'nutrition_service.dart';
import 'nutrition_summary_card.dart';

class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key, required this.service});
  final NutritionService service;
  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  DateTime _day = DateUtils.dateOnly(DateTime.now());
  NutritionDailySummary? _summary;
  List<NutritionRecord> _records = [];
  bool _loading = true;
  bool _loaded = false;
  String? _error;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await Future.wait<Object>([
        widget.service.getDailySummary(_day),
        widget.service.getRecords(),
      ]);
      if (mounted && request == _request) {
        setState(() {
          _summary = result[0] as NutritionDailySummary;
          _records = result[1] as List<NutritionRecord>;
          _loaded = true;
        });
      }
    } on ApiException catch (error) {
      if (mounted && request == _request) {
        setState(() => _error = error.message);
      }
    } on Object {
      if (mounted && request == _request) {
        setState(
          () => _error = 'Beslenme verileri yüklenemedi. Tekrar deneyin.',
        );
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked == null || !mounted || DateUtils.isSameDay(picked, _day)) return;
    setState(() {
      _day = picked;
      _summary = null;
    });
    await _load();
  }

  Future<void> _add() async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            NutritionEntryScreen(service: widget.service, day: _day),
      ),
    );
    if (!mounted || saved != true) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Beslenme kaydı eklendi.')));
    await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Beslenme')),
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
                      'Günlük beslenme özeti',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Wrap(
                      spacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          assignmentDate(
                            _day.toIso8601String().substring(0, 10),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _loading ? null : _pickDay,
                          icon: const Icon(Icons.calendar_today_outlined),
                          label: const Text('Gün seç'),
                        ),
                      ],
                    ),
                    if (_loading) ...[
                      const LinearProgressIndicator(),
                      const SizedBox(height: 8),
                      const Text('Beslenme verileri yükleniyor…'),
                      const SizedBox(height: 16),
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
                                  'Son yüklenen veriler gösteriliyor.',
                                ),
                              TextButton.icon(
                                onPressed: _loading ? null : _load,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Tekrar dene'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_summary != null)
                      NutritionSummaryCard(summary: _summary!),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _add,
                      icon: const Icon(Icons.add),
                      label: const Text('Beslenme Kaydı Ekle'),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Beslenme geçmişi (tüm günler)',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    if (_loaded && _records.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                            'Henüz beslenme kaydı yok. İlk öğününü ekleyebilirsin.',
                          ),
                        ),
                      ),
                    for (final record in _records)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                record.name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${mealLabels[record.mealType]} • ${trackingDate(record.consumedAt)}',
                              ),
                              if (record.portionDescription?.isNotEmpty == true)
                                Text(record.portionDescription!),
                              const SizedBox(height: 8),
                              for (final value in record.values.entries)
                                Text(
                                  '${nutrientLabels[value.key]}: ${trackingNumber(value.value)}',
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
