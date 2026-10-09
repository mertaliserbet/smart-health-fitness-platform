import 'package:flutter/material.dart';

import '../auth/auth_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.auth});
  final AuthService auth;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ana Sayfa')),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Hoş geldin, ${auth.user!.fullName}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(auth.user!.email, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: auth.isBusy ? null : auth.logout,
                child: Text(auth.isBusy ? 'Çıkış yapılıyor…' : 'Çıkış Yap'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
