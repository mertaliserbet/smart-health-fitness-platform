import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_service.dart';
import 'auth_form.dart';
import 'auth_service.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.auth});
  final AuthService auth;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _notice;
  Map<String, String> _fieldErrors = {};

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_busy) return;
    setState(() {
      _fieldErrors = {};
      _error = null;
    });
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await widget.auth.login(_email.text, _password.text);
      TextInput.finishAutofillContext(shouldSave: true);
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

  Future<void> _register() async {
    final email = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => RegisterScreen(auth: widget.auth)),
    );
    if (!mounted || email == null) return;
    setState(() {
      _email.text = email;
      _password.clear();
      _error = null;
      _fieldErrors = {};
      _notice = 'Hesabınız oluşturuldu. Şimdi giriş yapabilirsiniz.';
    });
  }

  @override
  Widget build(BuildContext context) => AuthFormLayout(
    title: 'Giriş Yap',
    busy: _busy,
    children: [
      Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_notice ?? widget.auth.notice case final String notice)
              AuthMessage(notice),
            if (_error ?? widget.auth.error case final String error)
              AuthMessage(error, isError: true),
            TextFormField(
              controller: _email,
              enabled: !_busy,
              decoration: const InputDecoration(labelText: 'E-posta'),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [
                AutofillHints.username,
                AutofillHints.email,
              ],
              autocorrect: false,
              validator: AuthValidation.email,
              forceErrorText: _fieldErrors['email'],
              onChanged: (_) => setState(() {
                _fieldErrors.remove('email');
                _error = null;
              }),
            ),
            const SizedBox(height: 16),
            PasswordField(
              controller: _password,
              enabled: !_busy,
              onSubmit: _login,
              errorText: _fieldErrors['password'],
              onChanged: (_) => setState(() {
                _fieldErrors.remove('password');
                _error = null;
              }),
            ),
            const SizedBox(height: 24),
            AuthSubmitButton(
              label: 'Giriş Yap',
              busy: _busy,
              onPressed: _login,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : _register,
              child: const Text('Kayıt Ol'),
            ),
          ],
        ),
      ),
    ],
  );
}
