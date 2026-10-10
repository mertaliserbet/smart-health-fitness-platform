import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../auth/user.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.auth, required this.user});
  final AuthService auth;
  final User user;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: auth,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Profil ve Ayarlar')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.fullName,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(user.email),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Profil ve ayar seçeneklerin burada yer alacak.'),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: auth.isBusy ? null : auth.logout,
                    icon: auth.isBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.logout),
                    label: Text(auth.isBusy ? 'Çıkış yapılıyor…' : 'Çıkış Yap'),
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
