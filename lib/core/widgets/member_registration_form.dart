import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../services/auth_service.dart';

class MemberRegistrationForm extends StatefulWidget {
  const MemberRegistrationForm({super.key});
  @override
  State<MemberRegistrationForm> createState() => _MemberRegistrationFormState();
}

class _MemberRegistrationFormState extends State<MemberRegistrationForm> {
  final formKey = GlobalKey<FormState>();
  final names = TextEditingController();
  final surnames = TextEditingController();
  final dni = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirmation = TextEditingController();
  bool accepted = false;
  bool loading = false;
  String? error;

  @override
  void dispose() {
    for (final controller in [names, surnames, dni, phone, email, password, confirmation]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (!(formKey.currentState?.validate() ?? false) || !accepted) {
      setState(() => error = accepted ? null : 'Debes aceptar los términos.');
      return;
    }
    if (!SupabaseConfig.isConfigured) {
      setState(() => error = 'Inicia Flutter con las credenciales de Supabase.');
      return;
    }
    setState(() { loading = true; error = null; });
    try {
      await AuthService(Supabase.instance.client).signUpMember(
        email: email.text.trim(), password: password.text,
        fullName: '${names.text.trim()} ${surnames.text.trim()}', dni: dni.text.trim(), phone: phone.text.trim(),
      );
      if (mounted) {
        await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
          title:const Text('Cuenta creada'),
          content:const Text('Revisa el buzón de tu correo registrado para activar tu cuenta. Después de confirmar el correo podrás iniciar sesión; la solicitud de miembro quedará pendiente de aprobación.'),
          actions:[FilledButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Entendido'))],
        ));
        if(mounted)context.go('/miembro/login');
      }
    } on AuthException catch (e) {
      final message=e.message.toLowerCase().contains('rate limit')
        ? 'Supabase alcanzó el límite del servidor de correo para activaciones. La cuenta no se duplicó. Espera y vuelve a intentar; para producción configura SMTP propio en Supabase y aumenta el límite de envío.'
        : e.message;
      if(mounted) setState(() => error = message);
    } catch (_) {
      if(mounted) setState(() => error = 'No se pudo crear la cuenta. Revisa los datos.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fields = [
      _field(names, 'Nombres', Icons.person_outline), _field(surnames, 'Apellidos', Icons.person_outline),
      _field(dni, 'DNI', Icons.badge_outlined, digits: 8), _field(phone, 'Teléfono', Icons.phone_outlined, digits: 9),
      _field(email, 'Correo electrónico', Icons.email_outlined), _field(password, 'Contraseña', Icons.lock_outline, secret: true),
      _field(confirmation, 'Confirmar contraseña', Icons.lock_outline, secret: true),
    ];
    return Form(key: formKey, child: Card(child: Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        return Wrap(spacing: 16, runSpacing: 16, children: fields.map((field) => SizedBox(width: wide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth, child: field)).toList());
      }),
      CheckboxListTile(value: accepted, onChanged: (value) => setState(() => accepted = value ?? false), contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading, title: const Text('Acepto los términos y el tratamiento de mis datos personales.')),
      if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      const SizedBox(height: 14),
      Align(alignment: Alignment.centerRight, child: FilledButton(onPressed: loading ? null : submit, child: Text(loading ? 'Creando cuenta...' : 'Crear cuenta'))),
    ]))));
  }

  Widget _field(TextEditingController controller, String label, IconData icon, {int? digits, bool secret = false}) => TextFormField(
    controller: controller, obscureText: secret, keyboardType: digits == null ? TextInputType.text : TextInputType.number,
    maxLength: digits,
    inputFormatters: digits == null ? null : [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(digits)],
    decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
    validator: (value) {
      final text = value?.trim() ?? '';
      if (text.isEmpty) return 'Campo obligatorio';
      if (digits != null && (text.length != digits || int.tryParse(text) == null)) return 'Debe contener $digits dígitos';
      if (controller == phone && !text.startsWith('9')) return 'El celular debe comenzar con 9';
      if (controller == email && !text.contains('@')) return 'Correo no válido';
      if (controller == confirmation && text != password.text) return 'Las contraseñas no coinciden';
      if (controller == password && text.length < 8) return 'Utiliza al menos 8 caracteres';
      return null;
    },
  );
}

