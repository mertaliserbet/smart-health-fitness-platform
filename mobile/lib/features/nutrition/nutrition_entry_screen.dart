import 'package:flutter/material.dart';

import '../../core/api_service.dart';
import '../auth/auth_form.dart' show AuthMessage;
import '../tracking/tracking_models.dart' show trackingDate;
import 'nutrition_models.dart';
import 'nutrition_service.dart';

class NutritionEntryScreen extends StatefulWidget {
  const NutritionEntryScreen({
    super.key,
    required this.service,
    required this.day,
  });
  final NutritionService service;
  final DateTime day;
  @override
  State<NutritionEntryScreen> createState() => _NutritionEntryScreenState();
}

class _NutritionEntryScreenState extends State<NutritionEntryScreen> {
  final _form = GlobalKey<FormState>();
  final _fields = {
    for (final key in ['name', 'portionDescription', ...nutrientLabels.keys])
      key: TextEditingController(),
  };
  String _meal = 'Breakfast';
  late DateTime _consumedAt;
  bool _saving = false;
  String? _error;
  Map<String, String> _fieldErrors = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _consumedAt = DateUtils.isSameDay(now, widget.day)
        ? now
        : DateTime(widget.day.year, widget.day.month, widget.day.day, 12);
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  double? _number(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));
  String? _validateNumber(String? text) {
    final value = (text ?? '').trim();
    final number = _number(value);
    if (value.isEmpty) return 'Bu değer zorunludur; sıfır girebilirsin.';
    if (!RegExp(r'^\d+(?:[.,]\d{1,2})?$').hasMatch(value) ||
        number == null ||
        !number.isFinite ||
        number < 0 ||
        number > 9999999999.99) {
      return '0–9999999999,99 arasında, en fazla iki ondalık basamak girin.';
    }
    return null;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _error = null;
      _fieldErrors = {};
    });
    if (!_form.currentState!.validate()) return;
    if (_consumedAt.isAfter(DateTime.now())) {
      setState(
        () => _fieldErrors = {'consumedAt': 'Tüketim zamanı gelecekte olamaz.'},
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.service.createRecord(
        mealType: _meal,
        name: _fields['name']!.text,
        portionDescription: _fields['portionDescription']!.text,
        values: {
          for (final key in nutrientLabels.keys)
            key: _number(_fields[key]!.text)!,
        },
        consumedAt: _consumedAt,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _fieldErrors = error.fieldErrors;
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
      initialDate: _consumedAt,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() {
        _consumedAt = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _consumedAt.hour,
          _consumedAt.minute,
        );
        _fieldErrors = {};
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_consumedAt),
    );
    if (picked != null && mounted) {
      setState(() {
        _consumedAt = DateTime(
          _consumedAt.year,
          _consumedAt.month,
          _consumedAt.day,
          picked.hour,
          picked.minute,
        );
        _fieldErrors = {};
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Beslenme Kaydı Ekle')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Tükettiğin öğünün kalori ve makro değerlerini gir.',
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    initialValue: _meal,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Öğün',
                      errorText: _fieldErrors['mealType'],
                    ),
                    items: [
                      for (final meal in mealLabels.entries)
                        DropdownMenuItem(
                          value: meal.key,
                          child: Text(meal.value),
                        ),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _meal = value!),
                  ),
                  const SizedBox(height: 16),
                  for (final field in {
                    'name': 'Öğün / besin adı',
                    'portionDescription': 'Porsiyon (isteğe bağlı)',
                    ...nutrientLabels,
                  }.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: TextFormField(
                        key: ValueKey(field.key),
                        controller: _fields[field.key],
                        enabled: !_saving,
                        maxLength: field.key == 'name' ? 200 : null,
                        keyboardType: nutrientLabels.containsKey(field.key)
                            ? const TextInputType.numberWithOptions(
                                decimal: true,
                              )
                            : TextInputType.text,
                        decoration: InputDecoration(
                          labelText: field.value,
                          errorText: _fieldErrors[field.key],
                        ),
                        validator: nutrientLabels.containsKey(field.key)
                            ? _validateNumber
                            : (value) =>
                                  field.key == 'name' &&
                                      (value ?? '').trim().isEmpty
                                  ? 'Öğün / besin adı zorunludur.'
                                  : null,
                        onChanged: (_) {
                          if (_error != null || _fieldErrors.isNotEmpty) {
                            setState(() {
                              _error = null;
                              _fieldErrors = {};
                            });
                          }
                        },
                      ),
                    ),
                  const Text('Tüketim zamanı'),
                  Text(trackingDate(_consumedAt)),
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
                  if (_fieldErrors['consumedAt'] != null)
                    AuthMessage(_fieldErrors['consumedAt']!, isError: true),
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
