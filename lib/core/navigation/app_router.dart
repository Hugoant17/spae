import '../live/business_pages.dart';
import '../live/public_pages.dart';
import '../live/member_requests.dart';
import '../live/password_reset.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

import '../../features/admin/pages/admin_dashboard_page.dart';
import '../../features/admin/pages/admin_login_page.dart';
import '../../features/admin/pages/admin_trainings_page.dart';
import '../../features/admin/pages/assistant_accounts_page.dart';
import '../../features/admin/pages/assistant_form_page.dart';
import '../../features/admin/pages/reports_page.dart';
import '../../features/admin/pages/settings_page.dart';
import '../../features/admin/pages/training_form_page.dart';
import '../../features/assistant/pages/assistant_dashboard_page.dart';
import '../../features/assistant/pages/attendance_page.dart';
import '../../features/assistant/pages/certificate_issuance_page.dart';
import '../../features/assistant/pages/enrollment_review_page.dart';
import '../../features/assistant/pages/enrollments_page.dart';
import '../../features/assistant/pages/internal_login_page.dart';
import '../../features/assistant/pages/members_page.dart';
import '../../features/assistant/pages/membership_requests_page.dart';
import '../../features/assistant/pages/membership_review_page.dart';
import '../../features/assistant/pages/participants_page.dart';
import '../../features/member/pages/member_dashboard_page.dart';
import '../../features/member/pages/member_login_page.dart';
import '../../features/member/pages/member_profile_page.dart';
import '../../features/member/pages/member_register_page.dart';
import '../../features/member/pages/member_training_history_page.dart';
import '../../features/member/pages/membership_payment_page.dart';
import '../../features/member/pages/membership_status_page.dart';
import '../../features/member/pages/payment_history_page.dart';
import '../../features/public/pages/enrollment_confirmation_page.dart';
import '../../features/public/pages/enrollment_form_page.dart';
import '../../features/public/pages/enrollment_lookup_page.dart';
import '../../features/public/pages/landing_page.dart';
import '../../features/public/pages/public_certificates_page.dart';
import '../../features/public/pages/training_catalog_page.dart';
import '../../features/public/pages/training_detail_page.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) async {
    final path=state.uri.path;
    final publicAuth=['/miembro/login','/miembro/registro','/interno/login','/admin/login','/recuperar'];
    final protected=(path.startsWith('/miembro')||path.startsWith('/asistente')||path.startsWith('/admin'))&&!publicAuth.contains(path);
    if(!protected)return null;
    if(!SupabaseConfig.isConfigured)return '/miembro/login';
    final client=Supabase.instance.client;
    if(client.auth.currentUser==null)return path.startsWith('/admin')?'/admin/login':path.startsWith('/asistente')?'/interno/login':'/miembro/login';
    try {
      final profile=await client.from('profiles').select('role,enabled').eq('id',client.auth.currentUser!.id).single();
      if(profile['enabled']!=true){await client.auth.signOut();return '/miembro/login';}
      final home=profile['role']=='administrator'?'/admin':profile['role']=='assistant'?'/asistente':'/miembro';
      if(!(path==home||path.startsWith('$home/')))return home;
    }catch(_){await client.auth.signOut();return '/miembro/login';}
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (context, state) => const LandingPage()),
    GoRoute(path: '/capacitaciones', builder: (context, state) => const TrainingCatalogPage()),
    GoRoute(path: '/capacitaciones/:id', builder: (context, state) => TrainingDetailPage(id:state.pathParameters['id'])),
    GoRoute(path: '/inscripcion/confirmacion', builder: (context, state) => EnrollmentConfirmationPage(receipt:state.extra is Map<String,dynamic>?state.extra as Map<String,dynamic>:null)),
    GoRoute(path: '/inscripcion/:trainingId', builder: (context, state) => EnrollmentFormPage(id:state.pathParameters['trainingId'])),
    GoRoute(path: '/consulta', builder: (context, state) => const EnrollmentLookupPage()),
    GoRoute(path: '/certificados', builder: (context, state) => const PublicCertificatesPage()),
    GoRoute(path: '/miembro/registro', builder: (context, state) => const MemberRegisterPage()),
    GoRoute(path: '/miembro/login', builder: (context, state) => const MemberLoginPage()),
    GoRoute(path:'/miembro/capacitaciones',builder:(context,state)=>const CatalogueView(member:true)),
    GoRoute(path:'/miembro/inscripcion/:id',builder:(context,state)=>PublicEnrollmentView(id:state.pathParameters['id']!,member:true)),
    GoRoute(path:'/asistente/solicitudes',builder:(context,state)=>const MemberRequestsView()),
    GoRoute(path: '/miembro', builder: (context, state) => const MemberDashboardPage()),
    GoRoute(path: '/miembro/perfil', builder: (context, state) => const MemberProfilePage()),
    GoRoute(path: '/miembro/membresia/pago', builder: (context, state) => const MembershipPaymentPage()),
    GoRoute(path: '/miembro/membresia', builder: (context, state) => const MembershipStatusPage()),
    GoRoute(path: '/miembro/pagos', builder: (context, state) => const PaymentHistoryPage()),
    GoRoute(path: '/miembro/historial', builder: (context, state) => const MemberTrainingHistoryPage()),
    GoRoute(path: '/interno/login', builder: (context, state) => const InternalLoginPage()),
    GoRoute(path: '/asistente', builder: (context, state) => const AssistantDashboardPage()),
    GoRoute(path: '/asistente/inscripciones', builder: (context, state) => const EnrollmentsPage()),
    GoRoute(path: '/asistente/inscripciones/:id', builder: (context, state) => EnrollmentReviewPage(id:state.pathParameters['id'])),
    GoRoute(path: '/asistente/membresias', builder: (context, state) => const MembershipRequestsPage()),
    GoRoute(path: '/asistente/membresias/:id', builder: (context, state) => MembershipReviewPage(id:state.pathParameters['id'])),
    GoRoute(path: '/asistente/asistencia', builder: (context, state) => const AttendancePage()),
    GoRoute(path: '/asistente/participantes', builder: (context, state) => const ParticipantsPage()),
    GoRoute(path: '/asistente/miembros', builder: (context, state) => const MembersPage()),
    GoRoute(path: '/asistente/certificados', builder: (context, state) => const CertificateIssuancePage()),
    GoRoute(path: '/admin/login', builder: (context, state) => const AdminLoginPage()),
    GoRoute(path:'/admin/miembros',builder:(context,state)=>const BusinessList(scope:'members',title:'Miembros',role:'admin')),
    GoRoute(path:'/admin/membresias',builder:(context,state)=>const BusinessList(scope:'membership_payments',title:'Activar y renovar membresías',role:'admin')),
    GoRoute(path: '/admin', builder: (context, state) => const AdminDashboardPage()),
    GoRoute(path: '/admin/asistentes', builder: (context, state) => const AssistantAccountsPage()),
    GoRoute(path: '/admin/asistentes/nueva', builder: (context, state) => const AssistantFormPage()),
    GoRoute(path: '/admin/capacitaciones', builder: (context, state) => const AdminTrainingsPage()),
    GoRoute(path: '/admin/capacitaciones/nueva', builder: (context, state) => const TrainingFormPage()),
    GoRoute(path:'/admin/capacitaciones/editar/:id',builder:(context,state)=>TrainingFormPage(id:state.pathParameters['id'])),
    GoRoute(path:'/admin/asistentes/editar/:id',builder:(context,state)=>AssistantFormPage(id:state.pathParameters['id'])),
    GoRoute(path:'/recuperar',builder:(context,state)=>const PasswordResetPage()),
    GoRoute(path: '/admin/reportes', builder: (context, state) => const ReportsPage()),
    GoRoute(path: '/admin/configuracion', builder: (context, state) => const SettingsPage()),
  ],
);
