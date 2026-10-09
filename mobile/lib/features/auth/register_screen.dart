import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_service.dart';
import 'auth_form.dart';
import 'auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.auth});
  final AuthService auth;
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;
  Map<String, String> _fieldErrors = {};

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_busy) return;
    setState(() {
      _fieldErrors = {};
      _error = null;
    });
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await widget.auth.register(
        firstName: _firstName.text,
        lastName: _lastName.text,
        email: _email.text,
        password: _password.text,
      );
      TextInput.finishAutofillContext(shouldSave: false);
      if (mounted) Navigator.of(context).pop(_email.text.trim());
    } on ApiException catch (failure) {
      if (mounted) {
        setState(() {
          _error = failure.message;
          _fieldErrors = failure.fieldErrors;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(
    String key,
    String label,
    TextEditingController controller, {
    bool email = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      enabled: !_busy,
      decoration: InputDecoration(labelText: label),
      textCapitalization: email
          ? TextCapitalization.none
          : TextCapitalization.words,
      keyboardType: email ? TextInputType.emailAddress : TextInputType.name,
      textInputAction: TextInputAction.next,
      autocorrect: false,
      autofillHints: [
        switch (key) {
          'firstName' => AutofillHints.givenName,
          'lastName' => AutofillHints.familyName,
          _ => AutofillHints.email,
        },
      ],
      validator: email ? AuthValidation.email : AuthValidation.name,
      forceErrorText: _fieldErrors[key],
      onChanged: (_) => setState(() {
        _fieldErrors.remove(key);
        _error = null;
      }),
    ),
  );

  @override
  Widget build(BuildContext context) => AuthFormLayout(
    title: 'Kayıt Ol',
    busy: _busy,
    children: [
      Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error case final String error)
              AuthMessage(error, isError: true),
            _field('firstName', 'Ad', _firstName),
            _field('lastName', 'Soyad', _lastName),
            _field('email', 'E-posta', _email, email: true),
            PasswordField(
              controller: _password,
              enabled: !_busy,
              registration: true,
              onSubmit: _register,
              errorText: _fieldErrors['password'],
              onChanged: (_) => setState(() {
                _fieldErrors.remove('password');
                _error = null;
              }),
            ),
            const SizedBox(height: 24),
            AuthSubmitButton(
              label: 'Hesap Oluştur',
              busy: _busy,
              onPressed: _register,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              child: const Text('Giriş Yap'),
            ),
          ],
        ),
      ),
    ],
  );
}
