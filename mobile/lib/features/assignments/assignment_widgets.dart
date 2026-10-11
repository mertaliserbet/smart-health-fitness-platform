import 'package:flutter/material.dart';

import '../../core/api_service.dart';

/// Independent loading/error state so one unavailable source cannot hide others.
class AssignmentSection<T> extends StatefulWidget {
  const AssignmentSection({
    super.key,
    required this.title,
    required this.active,
    required this.load,
    required this.builder,
  });
  final String title;
  final bool active;
  final Future<T> Function() load;
  final Widget Function(T) builder;

  @override
  State<AssignmentSection<T>> createState() => _AssignmentSectionState<T>();
}

class _AssignmentSectionState<T> extends State<AssignmentSection<T>> {
  bool _requested = false, _loading = false, _hasData = false;
  T? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.active) _load();
  }

  @override
  void didUpdateWidget(covariant AssignmentSection<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_requested) _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _requested = true;
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.load();
      if (mounted) {
        setState(() {
          _data = data;
          _hasData = true;
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(
          () => _error = error.statusCode == 404
              ? 'Bu bölümün servisi henüz hazır değil veya kullanılamıyor. Daha sonra tekrar dene.'
              : error.message,
        );
      }
    } on Object {
      if (mounted) {
        setState(() => _error = 'Veriler okunamadı. Tekrar deneyin.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
          label: Text(_error != null ? 'Tekrar dene' : 'Yenile'),
        ),
      ),
      if (_loading) ...[
        const LinearProgressIndicator(),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text('Yükleniyor…'),
        ),
      ],
      if (_error != null)
        AssignmentCard(
          children: [
            Text(_error!),
            if (_hasData) const Text('Son yüklenen veriler gösteriliyor.'),
          ],
        ),
      if (_hasData) widget.builder(_data as T),
    ],
  );
}

class AssignmentCard extends StatelessWidget {
  const AssignmentCard({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            children[i],
          ],
        ],
      ),
    ),
  );
}

class AssignmentPage extends StatelessWidget {
  const AssignmentPage({
    super.key,
    required this.storageKey,
    required this.children,
  });
  final String storageKey;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      key: PageStorageKey(storageKey),
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    ),
  );
}
