import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

class NavItem {
  const NavItem(this.label, this.route, this.icon);
  final String label;
  final String route;
  final IconData icon;
}

class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.items = const [],
    this.publicHeader = false,
    this.actions = const [],
  });

  final String title;
  final String subtitle;
  final Widget child;
  final List<NavItem> items;
  final bool publicHeader;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    if (publicHeader) return _PublicFrame(title: title, subtitle: subtitle, actions: actions, child: child);
    final desktop = MediaQuery.sizeOf(context).width >= 950;
    final rail = Container(
      width: 260,
      color: AppColors.primaryDark,
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Image.asset('assets/brand_logo.png',height:72),const SizedBox(height:8),const Text('Sociedad Peruana de Auditoría en Enfermería',style:TextStyle(color:Colors.white,fontSize:12)),const SizedBox(height:7),Text(items.isEmpty?'':items.first.route.startsWith('/admin')?'Usuario administrador':items.first.route.startsWith('/asistente')?'Usuario asistente':'Usuario miembro',style:const TextStyle(color:Colors.white70,fontSize:12))]),
          ),
          ListTile(leading:const Icon(Icons.logout,color:Colors.white),title:const Text('Cerrar sesión',style:TextStyle(color:Colors.white)),onTap:()async{await Supabase.instance.client.auth.signOut();if(context.mounted)context.go('/');}),
          Expanded(child: ListView(children: items.map((item) => ListTile(
            leading: Icon(item.icon, color: Colors.white70),
            title: Text(item.label, style: const TextStyle(color: Colors.white)),
            onTap: () { if (!desktop) Navigator.pop(context); context.go(item.route); },
          )).toList())),
        ]),
      ),
    );
    return Scaffold(
      drawer: desktop ? null : Drawer(child: rail),
      appBar: AppBar(
        automaticallyImplyLeading: !desktop,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          if (subtitle.isNotEmpty) Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ]),
        actions: actions,
      ),
      body: Row(children: [
        if (desktop) rail,
        Expanded(child: SingleChildScrollView(
          padding: EdgeInsets.all(desktop ? 32 : 16),
          child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1280), child: child)),
        )),
      ]),
    );
  }
}

class _PublicFrame extends StatelessWidget {
  const _PublicFrame({required this.title, required this.subtitle, required this.actions, required this.child});
  final String title;
  final String subtitle;
  final List<Widget> actions;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 850;
    return Scaffold(
      appBar: AppBar(
        title: Image.asset('assets/brand_logo.png',height:48),
        actions: compact
            ? [PopupMenuButton<String>(
                onSelected: context.go,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: '/', child: Text('Inicio')),
                  PopupMenuItem(value: '/capacitaciones', child: Text('Capacitaciones')),
                  PopupMenuItem(value: '/consulta', child: Text('Consultar inscripción')),
                  PopupMenuItem(value: '/certificados', child: Text('Certificados')),
                  PopupMenuItem(value: '/miembro/registro', child: Text('Registrarme como miembro')),
                  PopupMenuItem(value: '/miembro/login', child: Text('Acceder · Miembros')),
                  PopupMenuItem(value: '/interno/login', child: Text('Administrativo · Asistente')),
                  PopupMenuItem(value: '/admin/login', child: Text('Administrativo · Administrador')),
                ],
              )]
            : [
                TextButton(onPressed: () => context.go('/'), child: const Text('Inicio')),
                TextButton(onPressed: () => context.go('/capacitaciones'), child: const Text('Capacitaciones')),
                TextButton(onPressed: () => context.go('/consulta'), child: const Text('Consultar')),
                TextButton(onPressed: () => context.go('/certificados'), child: const Text('Certificados')),
                TextButton(onPressed: () => context.go('/miembro/registro'), child: const Text('Registrarme')),
                TextButton(onPressed: () => context.go('/miembro/login'), child: const Text('Acceder')),
                PopupMenuButton<String>(tooltip:'Administrativo',onSelected:context.go,itemBuilder:(_)=>const [PopupMenuItem(value:'/interno/login',child:Text('Acceso Asistente')),PopupMenuItem(value:'/admin/login',child:Text('Acceso Administrador'))],child:const Padding(padding:EdgeInsets.all(12),child:Text('Administrativo'))),
                ...actions,
                const SizedBox(width: 12),
              ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(compact ? 16 : 24),
        child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (title.isNotEmpty) Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: AppColors.primary)),
            if (subtitle.isNotEmpty) ...[const SizedBox(height: 8), Text(subtitle, style: Theme.of(context).textTheme.bodyLarge)],
            if (title.isNotEmpty) const SizedBox(height: 24),
            child,
          ]),
        )),
      ),
    );
  }
}
