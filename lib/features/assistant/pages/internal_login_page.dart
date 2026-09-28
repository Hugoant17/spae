import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/app_user.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/auth_form.dart';

class InternalLoginPage extends StatelessWidget {
  const InternalLoginPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 460), child: Card(child: Padding(
      padding: const EdgeInsets.all(36),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Icon(Icons.admin_panel_settings_outlined, size: 60, color: AppColors.secondary),
        const SizedBox(height: 12),
        Text('Acceso interno SPAE', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w800)),
        const SizedBox(height: 28),
        const AuthForm(expectedRole: UserRole.assistant, successRoute: '/asistente'),
        const SizedBox(height: 10),
        TextButton(onPressed: () => context.go('/admin/login'), child: const Text('Acceso del administrador')),
      ]),
    ))),
  )));
}
