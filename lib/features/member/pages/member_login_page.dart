import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/app_user.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/auth_form.dart';

class MemberLoginPage extends StatelessWidget {
  const MemberLoginPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Card(child: Padding(padding: const EdgeInsets.all(36), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Icon(Icons.health_and_safety_outlined, size: 58, color: AppColors.secondary),
        const SizedBox(height: 12),
        Text('Portal del miembro', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w800)),
        const SizedBox(height: 28),
        const AuthForm(expectedRole: UserRole.member, successRoute: '/miembro', registerRoute: '/miembro/registro'),
        TextButton(onPressed: () => context.go('/'), child: const Text('Volver al sitio público')),
      ]))),
    ))),
  );
}
