import 'package:flutter/material.dart';

import '../widgets/page_frame.dart';

abstract final class AppNavigation {
  static const member = [
    NavItem('Inicio', '/miembro', Icons.dashboard_outlined),
    NavItem('Capacitaciones', '/miembro/capacitaciones', Icons.school_outlined),
    NavItem('Mi membresía', '/miembro/membresia', Icons.workspace_premium_outlined),
    NavItem('Mis pagos', '/miembro/pagos', Icons.receipt_long_outlined),
    NavItem('Mis inscripciones', '/miembro/historial', Icons.school_outlined),
    NavItem('Mi perfil', '/miembro/perfil', Icons.person_outline),
  ];

  static const assistant = [
    NavItem('Inicio', '/asistente', Icons.dashboard_outlined),
    NavItem('Inscripciones', '/asistente/inscripciones', Icons.app_registration_outlined),
    NavItem('Solicitudes de miembros', '/asistente/solicitudes', Icons.person_add_outlined),
    NavItem('Membresías', '/asistente/membresias', Icons.workspace_premium_outlined),
    NavItem('Asistencia', '/asistente/asistencia', Icons.fact_check_outlined),
    NavItem('Participantes', '/asistente/participantes', Icons.groups_outlined),
    NavItem('Miembros', '/asistente/miembros', Icons.badge_outlined),
    NavItem('Certificados', '/asistente/certificados', Icons.verified_outlined),
  ];

  static const admin = [
    NavItem('Dashboard', '/admin', Icons.dashboard_outlined),
    NavItem('Miembros', '/admin/miembros', Icons.badge_outlined),
    NavItem('Membresías', '/admin/membresias', Icons.workspace_premium_outlined),
    NavItem('Asistentes', '/admin/asistentes', Icons.manage_accounts_outlined),
    NavItem('Capacitaciones', '/admin/capacitaciones', Icons.school_outlined),
    NavItem('Reportes', '/admin/reportes', Icons.analytics_outlined),
    NavItem('Configuración', '/admin/configuracion', Icons.settings_outlined),
  ];
}

