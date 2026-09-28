import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';

class AuthForm extends StatefulWidget {
  const AuthForm({
    super.key,
    required this.expectedRole,
    required this.successRoute,
    this.registerRoute,
  });
  final UserRole expectedRole;
  final String successRoute;
  final String? registerRoute;

  @override
  State<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<AuthForm> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
  bool hidden = true;
  String? error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!SupabaseConfig.isConfigured) {
      setState(() => error = 'Faltan las credenciales de Supabase al iniciar Flutter.');
      return;
    }
    setState(() { loading = true; error = null; });
    try {
      final service = AuthService(Supabase.instance.client);
      final user = await service.signIn(email.text.trim(), password.text);
      if (user.role != widget.expectedRole) {
        await service.signOut();
        throw const AuthException('Esta cuenta corresponde a otro portal. Usa el acceso de tu rol.');
      }
      if (user.role == UserRole.member) await Supabase.instance.client.rpc('spae_link_member');
      if (mounted) context.go(widget.successRoute);
    } on AuthException catch (e) {
      if(mounted) setState(() => error = e.message);
    } catch (_) {
      if(mounted) setState(() => error = 'No se pudo iniciar sesión. Verifica tus datos.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Correo electrónico', prefixIcon: Icon(Icons.email_outlined))),
    const SizedBox(height: 16),
    TextField(controller: password, obscureText: hidden, onSubmitted: (_) => submit(), decoration: InputDecoration(labelText: 'Contraseña', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed: () => setState(() => hidden = !hidden), icon: Icon(hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined)))),
    if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
    Align(alignment: Alignment.centerRight, child: TextButton(onPressed:()=>context.go('/recuperar'), child:const Text('Recuperar contraseña'))),
    FilledButton(onPressed: loading ? null : submit, child: loading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Iniciar sesión')),

    if (widget.registerRoute != null) ...[
      const SizedBox(height: 10),
      OutlinedButton(onPressed: () => context.go(widget.registerRoute!), child: const Text('Crear una cuenta')),
    ],
  ]);
}

