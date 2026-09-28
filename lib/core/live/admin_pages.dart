import 'individual_indicators.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../navigation/nav_items.dart';
import '../widgets/page_frame.dart';
import '../widgets/metric_card.dart';
import '../widgets/responsive_grid.dart';
import 'api.dart';
import 'components.dart';
import 'download.dart';
import 'business_pages.dart';

class TrainingManager extends StatelessWidget{
 const TrainingManager({super.key});
 @override Widget build(BuildContext context)=>PageFrame(title:'Gestión de capacitaciones',subtitle:'Publicación, sesiones y cupos',items:AppNavigation.admin,child:LoadData(load:()=>Api.data('trainings'),builder:(context,data,reload)=>Column(children:[Align(alignment:Alignment.centerRight,child:FilledButton.icon(onPressed:()=>context.go('/admin/capacitaciones/nueva'),icon:const Icon(Icons.add),label:const Text('Nueva capacitación'))),const SizedBox(height:16),Records(rows:Api.rows(data).where((r)=>r['archived_at']==null).toList(),columns:const {'title':'Capacitación','start_date':'Inicio','price':'S/','max_capacity':'Cupos','registered':'Inscritos','status':'Estado'},actions:(r)=>Wrap(children:[TextButton(onPressed:()=>context.go('/admin/capacitaciones/editar/${r['id']}'),child:const Text('Editar')),ActionButton(label:'Eliminar',confirm:true,run:()async{await Api.client.rpc('spae_delete_training',params:{'p_id':r['id']});reload();})]))])));
}
class TrainingEditor extends StatefulWidget{
 const TrainingEditor({super.key,this.id});final String? id;
 @override State<TrainingEditor> createState()=>_TrainingEditorState();
}
class _TrainingEditorState extends State<TrainingEditor>{
 List<RowData>? sessions;RowData? flyer;
 @override Widget build(BuildContext context)=>PageFrame(title:widget.id==null?'Nueva capacitación':'Editar capacitación',subtitle:'Las fechas incluyen hora local. Programa las sesiones para calcular asistencia.',items:AppNavigation.admin,child:LoadData(load:()async=>widget.id==null?<String,dynamic>{'status':'draft','modality':'virtual','price':0,'max_capacity':40,'total_hours':1}:Api.rows(await Api.data('trainings')).firstWhere((r)=>r['id']==widget.id),builder:(context,data,reload){
 sessions??=Api.rows(data['sessions']??[]);
 return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
 EditForm(initial:Map<String,dynamic>.from(data),fields:const [FieldSpec('title','Nombre de la capacitación'),FieldSpec('speaker','Expositor',required:false),FieldSpec('description','Descripción',lines:3),FieldSpec('objectives','Objetivos',lines:3,required:false),FieldSpec('syllabus','Temario',lines:4,required:false),FieldSpec('modality','Modalidad',options:{'virtual':'Virtual','hybrid':'Híbrida','in_person':'Presencial'}),FieldSpec('start_date','Fecha y hora de inicio',dateTime:true),FieldSpec('end_date','Fecha y hora de fin',required:false,dateTime:true),FieldSpec('total_hours','Horas',number:true),FieldSpec('max_capacity','Cupo máximo',number:true),FieldSpec('price','Costo S/',number:true),FieldSpec('image_url','URL de imagen HTTPS (opcional)',required:false),FieldSpec('status','Publicación',options:{'draft':'Borrador','active':'Publicada','completed':'Finalizada','cancelled':'Cancelada'})],extra:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[ActionButton(label:'Subir flyer JPG o PNG',icon:Icons.image,run:()async{final selected=await Api.pickFlyer();if(selected!=null)setState(()=>flyer=selected);}),Text(flyer?['file_name']??'También puedes usar una URL HTTPS')]),save:(v)async{
 final start=DateTime.tryParse(v['start_date']);final end=DateTime.tryParse(v['end_date']??'');
 if(start==null)throw Exception('Fecha de inicio no válida: usa AAAA-MM-DD HH:MM');
 if(end!=null&&end.isBefore(start))throw Exception('La fecha final debe ser posterior al inicio');
 if(sessions!.isEmpty)throw Exception('Agrega al menos una sesión');
 if(flyer!=null){final uploaded=await Api.edge('upload_flyer',flyer!);v['image_url']=uploaded['url'];}
 await Api.action('save_training',{...v,'start_date':peruWallClockToUtcIso(v['start_date']),'end_date':(v['end_date']??'').toString().trim().isEmpty?null:peruWallClockToUtcIso(v['end_date']),'sessions':sessions});if(context.mounted)context.go('/admin/capacitaciones');}),
 const SizedBox(height:20),Text('Sesiones programadas',style:Theme.of(context).textTheme.titleLarge),
 for(final s in sessions!)Card(child:ListTile(title:Text(s['title']),subtitle:Text(display(s['starts_at'])),trailing:Wrap(children:[IconButton(icon:const Icon(Icons.edit),onPressed:()=>editSession(s)),IconButton(icon:const Icon(Icons.delete_outline),onPressed:()=>setState(()=>sessions!.remove(s)))]))),
 Align(alignment:Alignment.centerLeft,child:OutlinedButton.icon(onPressed:()=>editSession(null),icon:const Icon(Icons.add),label:const Text('Agregar sesión')))]);
 }));
 Future<void> editSession(RowData? s) async{
 await showDialog<void>(context:context,builder:(ctx)=>Dialog(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:650),child:SingleChildScrollView(child:EditForm(initial:s??{},fields:const [FieldSpec('title','Nombre de la sesión'),FieldSpec('starts_at','Fecha y hora de sesión',dateTime:true)],save:(v)async{final date=DateTime.tryParse(v['starts_at']);if(date==null)throw Exception('Fecha no válida');setState((){if(s!=null)sessions!.remove(s);sessions!.add({...v,'starts_at':peruWallClockToUtcIso(v['starts_at'])});});if(ctx.mounted)Navigator.pop(ctx);})))));
 }
}
class AssistantManager extends StatelessWidget{
 const AssistantManager({super.key});
 @override Widget build(BuildContext context)=>PageFrame(title:'Cuentas de asistentes',subtitle:'Usuarios de Supabase Authentication',items:AppNavigation.admin,child:LoadData(load:()=>Api.data('assistants'),builder:(context,data,reload)=>Column(children:[Align(alignment:Alignment.centerRight,child:FilledButton(onPressed:()=>context.go('/admin/asistentes/nueva'),child:const Text('Nueva asistente'))),const SizedBox(height:16),Records(rows:Api.rows(data),columns:const {'full_name':'Nombre','email':'Correo','enabled':'Habilitada','created_at':'Creación'},actions:(r)=>Wrap(children:[TextButton(onPressed:()=>context.go('/admin/asistentes/editar/${r['id']}'),child:const Text('Editar')),ActionButton(label:r['enabled']==true?'Desactivar':'Activar',confirm:true,run:()async{await Api.action('assistant_state',{'id':r['id'],'enabled':r['enabled']!=true});reload();}),ActionButton(label:'Eliminar',confirm:true,run:()async{await Api.edge('assistant_delete',{'id':r['id']});reload();})]))])));
}
class AssistantEditor extends StatelessWidget{
 const AssistantEditor({super.key,this.id});final String? id;
 @override Widget build(BuildContext context)=>PageFrame(title:id==null?'Nueva asistente':'Editar asistente',subtitle:'La cuenta se crea en Authentication y su perfil se guarda en la base de datos',items:AppNavigation.admin,child:LoadData(load:()async=>id==null?<String,dynamic>{}:Api.rows(await Api.data('assistants')).firstWhere((r)=>r['id']==id),builder:(context,data,reload)=>EditForm(initial:Map<String,dynamic>.from(data),fields:[const FieldSpec('full_name','Nombres y apellidos'),const FieldSpec('email','Correo electrónico'),FieldSpec('password',id==null?'Contraseña inicial (10 caracteres)':'Nueva contraseña (opcional)',secret:true,required:id==null)],save:(v)async{await Api.edge('assistant_save',v);if(context.mounted)context.go('/admin/asistentes');})));
}
class SettingsEditor extends StatelessWidget{
 const SettingsEditor({super.key});
 @override Widget build(BuildContext context)=>PageFrame(title:'Configuración del sistema',subtitle:'Los valores se aplican a nuevas operaciones',items:AppNavigation.admin,child:LoadData(load:()=>Api.data('settings'),builder:(context,data,reload)=>EditForm(key:ValueKey(data.toString()),initial:{for(final r in Api.rows(data))if(r['key']!='team_hourly_cost')r['key']:r['value']},fields:const [FieldSpec('minimum_attendance_percent','Asistencia mínima %',number:true),FieldSpec('annual_membership_amount','Membresía anual S/',number:true),FieldSpec('certificate_surcharge_amount','Adicional por certificado S/',number:true),FieldSpec('receipt_max_mb','Tamaño comprobantes MB (máximo 5)',number:true),FieldSpec('contact_email','Correo institucional',required:false),FieldSpec('contact_phone','Teléfono',required:false),FieldSpec('contact_address','Dirección',required:false),FieldSpec('contact_facebook','Enlace de Facebook',required:false),FieldSpec('contact_whatsapp','Enlace de WhatsApp empresa',required:false)],save:(v)async{await Api.action('save_settings',{'items':[for(final e in v.entries){'key':e.key,'value':e.value}]});reload();if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Parámetros guardados')));}))); 
}
class ReportsView extends StatefulWidget{
 const ReportsView({super.key});@override State<ReportsView> createState()=>_ReportsViewState();
}
class _ReportsViewState extends State<ReportsView>{
 String scope='enrollments',training='';DateTime? from,to;
 @override Widget build(BuildContext context)=>PageFrame(title:'Centro de reportes',subtitle:'Reportes independientes con descarga Excel',items:AppNavigation.admin,child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
 DropdownButtonFormField<String>(initialValue:scope,decoration:const InputDecoration(labelText:'Reporte'),items:const [DropdownMenuItem(value:'enrollments',child:Text('Inscritos')),DropdownMenuItem(value:'payments',child:Text('Pagos de capacitaciones')),DropdownMenuItem(value:'attendance',child:Text('Asistencia')),DropdownMenuItem(value:'certificates',child:Text('Certificados')),DropdownMenuItem(value:'memberships',child:Text('Miembros')),DropdownMenuItem(value:'membership_payments',child:Text('Cuotas anuales')),DropdownMenuItem(value:'indicators',child:Text('Fichas NAA / TRC / TEC'))],onChanged:(v)=>setState((){scope=v!;training='';})),
 Wrap(spacing:12,children:[TextButton(onPressed:()async{final d=await showDatePicker(context:context,initialDate:from??DateTime.now(),firstDate:DateTime(2000),lastDate:DateTime(2100));if(d!=null)setState(()=>from=d);},child:Text(from==null?'Desde':'Desde ${from.toString().substring(0,10)}')),TextButton(onPressed:()async{final d=await showDatePicker(context:context,initialDate:to??DateTime.now(),firstDate:DateTime(2000),lastDate:DateTime(2100));if(d!=null)setState(()=>to=d);},child:Text(to==null?'Hasta':'Hasta ${to.toString().substring(0,10)}')),TextButton(onPressed:()=>setState((){from=null;to=null;training='';}),child:const Text('Limpiar fechas'))]),
 if(scope=='indicators')const IndividualIndicators() else LoadData(key:ValueKey(scope),load:()=>Api.data(scope=='membership_payments'?'memberships':scope),builder:(context,data,reload){
 var rows=Api.rows(data);if(scope=='membership_payments')rows=[for(final m in rows)for(final p in Api.rows(m['payments'])){...p,'full_name':m['full_name']}];
 if(scope=='certificates')rows=rows.where((r)=>r['certificate_number']!=null).toList();
 if(scope=='attendance')rows=[for(final r in rows)for(final s in Api.rows(r['sessions'])){...r,'session':s['title'],'session_date':s['starts_at'],'attendance_status':s['status']}];
 rows=rows.where((r){final d=DateTime.tryParse((r[scope=='certificates'?'issued_at':'created_at']??'').toString());return (from==null||d!=null&&!d.isBefore(from!))&&(to==null||d!=null&&d.isBefore(to!.add(const Duration(days:1))))&&(training.isEmpty||r['training']==training);}).toList();
 final columns=scope=='memberships'?memberColumns:scope=='membership_payments'?paymentColumns:scope=='certificates'?certificateColumns:scope=='payments'?{'full_name':'Participante','training':'Capacitación','amount':'Monto S/','operation_number':'Operación','payment_status':'Estado','created_at':'Registro'}:scope=='attendance'?{'full_name':'Participante','training':'Capacitación','session':'Sesión','session_date':'Fecha sesión','attendance_status':'Asistencia','attendance_percent':'Acumulado %'}:enrollmentColumns;
 return Records(rows:rows,columns:columns,export:(filtered)=>exportExcel(filtered,columns,'SPAE_$scope'));
 })]));
}
class DashboardView extends StatelessWidget{
 const DashboardView({super.key,required this.role});final String role;
 @override Widget build(BuildContext context)=>PageFrame(title:role=='admin'?'Dashboard general':role=='member'?'Mi panel':'Panel operativo',subtitle:'Valores calculados a partir de registros reales',items:role=='admin'?AppNavigation.admin:role=='member'?AppNavigation.member:AppNavigation.assistant,child:LoadData(load:()async{
 if(role=='admin')return <String,dynamic>{};
 return {'profile':await Api.data('profile'),'enrollments':await Api.data('enrollments'),'memberships':await Api.data('memberships')};
 },builder:(context,data,reload){
 if(role=='admin')return const IndividualIndicators();
 final enrollments=Api.rows(data['enrollments']);final members=Api.rows(data['memberships']);final profile=data['profile'];
 return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[if(role=='member')Card(child:Padding(padding:const EdgeInsets.all(16),child:Text('Solicitud de miembro: ${display(profile['registration_status'])}${profile['registration_reason']==null?'':' · ${profile['registration_reason']}'}'))),Text('Hola, ${profile['full_name']}',style:Theme.of(context).textTheme.headlineSmall),const SizedBox(height:20),ResponsiveGrid(children:[MetricCard(label:'Inscripciones',value:'${enrollments.length}',icon:Icons.school),MetricCard(label:'Pendientes',value:'${enrollments.where((r)=>r['status']=='pending').length}',icon:Icons.pending_actions),MetricCard(label:'Certificados',value:'${enrollments.where((r)=>r['certificate_number']!=null).length}',icon:Icons.verified),MetricCard(label:role=='member'?'Membresía':'Miembros activos',value:role=='member'?(members.isEmpty?'Sin membresía':display(members.first['effective_status'])):'${members.where((r)=>r['effective_status']=='active').length}',icon:Icons.badge)]),const SizedBox(height:24),Records(rows:enrollments,columns:enrollmentColumns),if(role=='member')FilledButton(onPressed:()=>context.go('/miembro/membresia/pago'),child:const Text('Registrar o renovar membresía'))]);
 }));
}
