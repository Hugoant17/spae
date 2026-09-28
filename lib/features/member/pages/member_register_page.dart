import 'package:flutter/material.dart';
import '../../../core/widgets/member_registration_form.dart';
import '../../../core/widgets/page_frame.dart';

class MemberRegisterPage extends StatelessWidget {
  const MemberRegisterPage({super.key});
  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'Crea tu cuenta de miembro', subtitle: 'Regístrate para gestionar tu membresía y certificados.', publicHeader: true,
    child: const MemberRegistrationForm(),
  );
}
