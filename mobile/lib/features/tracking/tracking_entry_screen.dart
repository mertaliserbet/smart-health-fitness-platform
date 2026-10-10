import 'package:flutter/material.dart';

import '../../core/api_service.dart';
import '../auth/auth_form.dart' show AuthMessage;
import 'tracking_models.dart';
import 'tracking_service.dart';

enum TrackingEntryType { weight, measurements }

class TrackingEntryScreen extends StatefulWidget {
  const TrackingEntryScreen({
    super.key,
    required this.service,
    required this.type,
  });
  final TrackingService service;
  final TrackingEntryType type;
  @override
  State<TrackingEntryScreen> createState() => _TrackingEntryScreenState();
}

class _TrackingEntryScreenState extends State<TrackingEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _controllers = {
    for (final key in _labels.keys) key: TextEditingController(),
  };
  DateTime _recordedAt = DateTime.now();
  bool _saving = false;
  String? _error;
  Map<String, String> _fieldErrors = {};
  bool get _isWeight => widget.type == TrackingEntryType.weight;
  Map<String, String> get _labels =>
      _isWeight ? const {'weightKg': 'Kilo'} : measurementLabels;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  double? _number(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  String? _validate(String? text, String key) {
    final value = (text ?? '').trim();
    if (value.isEmpty) return _isWeight ? 'Kilo zorunludur.' : null;
    final number = _number(value);
    final isFat = key == 'bodyFatPercentage';
    if (!RegExp(r'^\d+(?:[.,]\d{1,2})?$').hasMatch(value) ||
        number == null ||
        !number.isFinite ||
        number < (isFat ? 0 : 0.01) ||
        number > (isFat ? 100 : 1000)) {
      return isFat
          ? '0–100 arasında, en fazla iki ondalık basamak girin.'
          : '0,01–1000 arasında, en fazla iki ondalık basamak girin.';
    }
    return null;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _error = null;
      _fieldErrors = {};
    });
    if (!_formKey.currentState!.validate()) return;
    if (!_isWeight && _controllers.values.every((c) => c.text.trim().isEmpty)) {
      setState(() => _error = 'En az bir vücut ölçümü girin.');
      return;
    }
    if (_recordedAt.isAfter(DateTime.now())) {
      setState(
        () => _fieldErrors = {'recordedAt': 'Kayıt zamanı gelecekte olamaz.'},
      );
      return;
    }
    setState(() => _saving = true);
    try {
      if (_isWeight) {
        await widget.service.createWeightRecord(
          _number(_controllers['weightKg']!.text)!,
          _recordedAt,
        );
      } else {
        await widget.service.createBodyMeasurement({
          for (final entry in _controllers.entries)
            entry.key: _number(entry.value.text),
        }, _recordedAt);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _fieldErrors = error.fieldErrors;
          _error = error.fieldErrors['measurements'] ?? error.message;
        });
      }
    } on Object {
      if (mounted) {
        setState(() => _error = 'Kayıt tamamlanamadı. Tekrar deneyin.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _recordedAt,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() {
        _recordedAt = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _recordedAt.hour,
          _recordedAt.minute,
        );
        _fieldErrors = {};
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_recordedAt),
    );
    if (picked != null && mounted) {
      setState(() {
        _recordedAt = DateTime(
          _recordedAt.year,
          _recordedAt.month,
          _recordedAt.day,
          picked.hour,
          picked.minute,
        );
        _fieldErrors = {};
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_isWeight ? 'Kilo Ekle' : 'Vücut Ölçümü Ekle')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _isWeight
                        ? 'Kilonu ve ölçüm zamanını kaydet.'
                        : 'En az bir ölçüm gir. Diğer alanları boş bırakabilirsin.',
                  ),
                  const SizedBox(height: 20),
                  for (final field in _labels.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: TextFormField(
                        key: ValueKey(field.key),
                        controller: _controllers[field.key],
                        enabled: !_saving,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText:
                              '${field.value} (${field.key == 'bodyFatPercentage'
                                  ? '%'
                                  : _isWeight
                                  ? 'kg'
                                  : 'cm'})',
                          errorText: _fieldErrors[field.key],
                        ),
                        validator: (value) => _validate(value, field.key),
                        onChanged: (_) {
                          if (_fieldErrors.isNotEmpty || _error != null) {
                            setState(() {
                              _fieldErrors = {};
                              _error = null;
                            });
                          }
                        },
                      ),
                    ),
                  Text(
                    'Kayıt zamanı',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(trackingDate(_recordedAt)),
                  Wrap(
                    spacing: 12,
                    children: [
                      TextButton.icon(
                        onPressed: _saving ? null : _pickDate,
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: const Text('Tarih seç'),
                      ),
                      TextButton.icon(
                        onPressed: _saving ? null : _pickTime,
                        icon: const Icon(Icons.schedule),
                        label: const Text('Saat seç'),
                      ),
                    ],
                  ),
                  if (_fieldErrors['recordedAt'] != null)
                    AuthMessage(_fieldErrors['recordedAt']!, isError: true),
                  if (_error != null) AuthMessage(_error!, isError: true),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(_saving ? 'Kaydediliyor…' : 'Kaydet'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
