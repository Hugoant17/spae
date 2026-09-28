import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/app_user.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/auth_form.dart';

class AdminLoginPage extends StatelessWidget {
  const AdminLoginPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 460), child: Card(child: Padding(
      padding: const EdgeInsets.all(36),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const CircleAvatar(radius: 34, backgroundColor: AppColors.primary, child: Icon(Icons.shield_outlined, size: 38, color: Colors.white)),
        const SizedBox(height: 18),
        Text('Administración SPAE', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w800)),
        const SizedBox(height: 28),
        const AuthForm(expectedRole: UserRole.administrator, successRoute: '/admin'),
        TextButton(onPressed: () => context.go('/'), child: const Text('Volver al sitio público')),
      ]),
    ))),
  )));
}
