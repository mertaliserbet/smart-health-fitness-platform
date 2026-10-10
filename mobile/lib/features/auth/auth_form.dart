import 'package:flutter/material.dart';

import '../../core/app_config.dart';

class AuthValidation {
  // Unicode letters and combining marks; separators must be between name parts.
  static final _namePattern = RegExp(
    r"^ *\p{L}[\p{L}\p{M}]*(?:(?: +|[-'’])\p{L}[\p{L}\p{M}]*)* *$",
    unicode: true,
  );

  static String? name(String? value) {
    if (value == null || value.trim().isEmpty) return 'Bu alanı doldurun.';
    if (value.length > 100) return 'En fazla 100 karakter girin.';
    final match = _namePattern.firstMatch(value);
    if (match == null || match.end != value.length) {
      return 'Yalnızca harf, boşluk, tire ve apostrof kullanın.';
    }
    return null;
  }

  static String? email(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'E-posta adresinizi girin.';
    if (email.length > 254 ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Geçerli bir e-posta adresi girin.';
    }
    return null;
  }

  static String? password(String? value, {bool registration = false}) {
    if (value == null || value.trim().isEmpty) return 'Şifrenizi girin.';
    if (value.length > 128) return 'Şifre en fazla 128 karakter olabilir.';
    if (registration && value.length < 12) {
      return 'Şifre en az 12 karakter olmalıdır.';
    }
    return null;
  }
}

class AuthFormLayout extends StatelessWidget {
  const AuthFormLayout({
    super.key,
    required this.title,
    required this.children,
    required this.busy,
  });
  final String title;
  final List<Widget> children;
  final bool busy;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      AppConfig.appName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 24),
                    ...children,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.enabled,
    required this.onSubmit,
    this.registration = false,
    this.errorText,
    required this.onChanged,
  });
  final TextEditingController controller;
  final bool enabled;
  final bool registration;
  final String? errorText;
  final VoidCallback onSubmit;
  final ValueChanged<String> onChanged;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hidden = true;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    enabled: widget.enabled,
    obscureText: _hidden,
    autocorrect: false,
    enableSuggestions: false,
    autofillHints: [
      widget.registration ? AutofillHints.newPassword : AutofillHints.password,
    ],
    textInputAction: TextInputAction.done,
    validator: (value) =>
        AuthValidation.password(value, registration: widget.registration),
    forceErrorText: widget.errorText,
    onChanged: widget.onChanged,
    onFieldSubmitted: (_) {
      if (widget.enabled) widget.onSubmit();
    },
    decoration: InputDecoration(
      labelText: 'Şifre',
      helperText: widget.registration ? '12–128 karakter' : null,
      suffixIcon: IconButton(
        onPressed: widget.enabled
            ? () => setState(() => _hidden = !_hidden)
            : null,
        tooltip: _hidden ? 'Şifreyi göster' : 'Şifreyi gizle',
        icon: Icon(
          _hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
      ),
    ),
  );
}

class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({
    super.key,
    required this.label,
    required this.busy,
    required this.onPressed,
  });
  final String label;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: busy ? null : onPressed,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (busy) ...[
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
          ],
          Flexible(child: Text(label)),
        ],
      ),
    ),
  );
}

class AuthMessage extends StatelessWidget {
  const AuthMessage(this.message, {super.key, this.isError = false});
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        message,
        style: TextStyle(
          color: isError
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.onSurface,
        ),
      ),
    ),
  );
}
