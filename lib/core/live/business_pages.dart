import 'indicator_values.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../navigation/nav_items.dart';
import '../widgets/page_frame.dart';
import 'api.dart';
import 'components.dart';
import 'download.dart';

const enrollmentColumns={'code':'Código','full_name':'Participante','training':'Capacitación','created_at':'Registro','status':'Estado','attendance_percent':'Asistencia %'};
const paymentColumns={'full_name':'Miembro','period':'Periodo','amount':'Monto S/','created_at':'Registro','operation_number':'Operación','status':'Estado','rejection_reason':'Motivo del rechazo'};
const memberColumns={'full_name':'Miembro','email':'Correo','starts_on':'Inicio','ends_on':'Vencimiento','effective_status':'Membresía','enabled':'Cuenta habilitada'};
const certificateColumns={'full_name':'Participante','training':'Capacitación','attendance_percent':'Asistencia %','certificate_number':'Certificado','issued_at':'Emisión','tec_hours':'TEC horas'};
const memberCertificateColumns={'full_name':'Participante','training':'Capacitación','attendance_percent':'Asistencia %','certificate_number':'Certificado','issued_at':'Emisión'};

class BusinessList extends StatelessWidget{
 const BusinessList({super.key,required this.scope,required this.title,required this.role,this.id});
 final String scope,title,role;final String? id;
 List<NavItem> get nav=>role=='admin'?AppNavigation.admin:role=='member'?AppNavigation.member:AppNavigation.assistant;
 @override Widget build(BuildContext context)=>PageFrame(title:title,subtitle:'Información registrada en Supabase',items:nav,child:LoadData(load:()=>scope=='members'?Api.memberAccounts():Api.data(scope=='membership_payments'?'memberships':scope),builder:(context,data,reload){
 var rows=Api.rows(data);
 if(scope=='membership_payments')rows=[for(final m in rows)for(final p in Api.rows(m['payments'])){...p,'full_name':m['full_name'],'email':m['email'],'starts_on':m['starts_on'],'ends_on':m['ends_on']}];
 if(id!=null)rows=rows.where((r)=>r['id']==id).toList();
 final columns=scope=='memberships'||scope=='members'?memberColumns:scope=='membership_payments'?paymentColumns:scope=='certificates'?(role=='member'?memberCertificateColumns:certificateColumns):scope=='participants'?{'full_name':'Nombre','dni':'DNI','email':'Correo','phone':'Celular','hospital':'Hospital','region':'Región'}:enrollmentColumns;
 return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
 Align(alignment:Alignment.centerRight,child:IconButton(tooltip:'Actualizar',onPressed:reload,icon:const Icon(Icons.refresh))),
 Records(rows:rows,columns:columns,bulk:scope=='certificates'&&role!='member'?(filtered)async{
 final ids=filtered.where((r)=>r['certificate_number']==null&&r['status']=='approved'&&r['wants_certificate']==true).map((r)=>r['id']).toList();
 if(ids.isEmpty)throw Exception('No hay certificados pendientes en esta selección.');
 final results=<RowData>[];for(var i=0;i<ids.length;i+=20){final response=await Api.edge('bulk_certificates',{'ids':ids.skip(i).take(20).toList()});results.addAll(Api.rows(response['results']));}
 if(context.mounted)await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Resultado de emisión'),content:SizedBox(width:650,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Emitidos: ${results.where((r)=>r['ok']==true).length} de ${results.length}'),for(final r in results.where((r)=>r['ok']!=true))Text('${r['name']??r['id']}: ${r['error']}')]))),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cerrar'))]));
 reload();
 }:null,actions:(r)=>Wrap(spacing:12,runSpacing:12,children:[
 if((scope=='memberships'||scope=='members')&&role!='member')ActionButton(label:'Activar membresía',icon:Icons.workspace_premium,run:()async{await activateMembership(context,r);reload();}),
 if(scope=='members'&&role!='member'&&r['member_id']!=null)...[
 ActionButton(label:r['enabled']==true?'Inactivar cuenta':'Activar cuenta',icon:r['enabled']==true?Icons.person_off_outlined:Icons.person_outline,confirm:true,run:()async{await Api.memberState(r['member_id'].toString(),r['enabled']!=true);reload();}),
 ActionButton(label:'Eliminar miembro',icon:Icons.delete_outline,confirm:true,run:()async{await Api.edge('member_delete',{'id':r['member_id']});reload();}),
 ],
 if(scope=='memberships'||scope=='members')TextButton(onPressed:()=>showDialog<void>(context:context,builder:(ctx)=>Dialog(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:950),child:SingleChildScrollView(padding:const EdgeInsets.all(20),child:Column(children:[Text('Historial de ${r['full_name']}'),Records(rows:Api.rows(r['payments']),columns:const {'period':'Periodo','amount':'S/','created_at':'Registro','status':'Estado'}),TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cerrar'))]))))),child:const Text('Historial de pagos')),
 if(scope=='enrollments'&&role!='member')TextButton(onPressed:()=>context.go('/asistente/inscripciones/${r['id']}'),child:const Text('Detalle')),
 if((scope=='enrollments'||scope=='membership_payments')&&role!='member'&&r['status']=='pending')...[
 ActionButton(label:scope=='membership_payments'?'Activar membresía':'Aprobar',confirm:true,run:()async{if(scope=='enrollments'){await Api.reviewEnrollment(r['id'].toString());if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Inscripción aprobada correctamente')));}else{await Api.action('review_membership',{'id':r['id'],'status':'approved'});}reload();}),
 ActionButton(label:'Rechazar',run:()async{final reason=await askText(context,'Motivo del rechazo');if(reason==null)return;if(scope=='enrollments'){await Api.reviewEnrollment(r['id'].toString(),status:'rejected',reason:reason);}else{await Api.action('review_membership',{'id':r['id'],'status':'rejected','reason':reason});}reload();})],
 if(r['receipt_path']!=null)ActionButton(label:'Comprobante',icon:Icons.download,run:()async{final result=await Api.edge('receipt',{'path':r['receipt_path']});await downloadUrl(result['signedUrl'],'comprobante.${r['receipt_path'].toString().split('.').last}');}),
 if(r['certificate_number']!=null)ActionButton(label:role=='member'?'Descargar Certificado':'Descargar Certificado',icon:Icons.download,run:()async{final result=await Api.edge('certificate',{'id':r['id']});await downloadUrl(result['signedUrl'],'${r['certificate_number']}.pdf');}),
 if(scope=='certificates'&&role!='member'&&r['certificate_number']==null&&r['status']=='approved')ActionButton(label:'Emitir Certificado',confirm:true,run:()async{final result=await Api.edge('issue_certificate',{'id':r['id']});await downloadUrl(result['signedUrl'],'certificado.pdf');reload();}),
 if(scope=='participants')ActionButton(label:'Restablecer código',confirm:true,run:()async{
 // El código final se genera criptográficamente en la función de servidor.
 final result=await Api.edge('recover_code',{'id':r['id']});
 if(context.mounted)await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Código privado del participante'),content:SelectableText('${result['code']}'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cerrar'))]));
 }),
 if(scope=='participants')ActionButton(label:'Eliminar',icon:Icons.delete_outline,confirm:true,confirmationMessage:'Se eliminará a ${r['full_name']} y todas sus inscripciones, pagos registrados y asistencias, incluidas las aprobadas. Esta acción no se puede deshacer. Si tiene certificados emitidos, se conservará el participante.',run:()async{await Api.deleteParticipant(r['id'].toString());if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Participante eliminado correctamente')));reload();})])),
 if(id!=null&&rows.isNotEmpty)Card(child:Padding(padding:const EdgeInsets.all(24),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[for(final k in ['full_name','dni','email','phone','hospital','region','operation_number','amount','rejection_reason'])Padding(padding:const EdgeInsets.symmetric(vertical:5),child:SelectableText('$k: ${display(rows.first[k])}'))]))),
 if(role=='member'&&(scope=='memberships'||scope=='membership_payments'))Align(alignment:Alignment.centerRight,child:FilledButton(onPressed:()=>context.go('/miembro/membresia/pago'),child:const Text('Registrar o renovar membresía')))
 ]);
 }));
}
class ProfileEditor extends StatelessWidget{
 const ProfileEditor({super.key});
 @override Widget build(BuildContext context)=>PageFrame(title:'Mi perfil',subtitle:'Actualiza tus datos de contacto',items:AppNavigation.member,child:LoadData(load:()=>Api.data('profile'),builder:(context,data,reload)=>EditForm(key:ValueKey(data.toString()),initial:Map<String,dynamic>.from(data),fields:[const FieldSpec('full_name','Nombres y apellidos'),FieldSpec('dni','DNI',readOnly:(data['dni']??'').toString().trim().isNotEmpty),const FieldSpec('email','Correo verificado',readOnly:true),const FieldSpec('phone','Celular'),const FieldSpec('hospital','Hospital / institución'),FieldSpec('region','Región',options:{for(final region in peruRegions)region:region}),const FieldSpec('nurse_auditor_registry','¿Registro de enfermera auditora?',options:{'true':'Sí','false':'No'})],save:(v)async{await Api.action('save_profile',v);reload();if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Perfil guardado en Supabase')));}))); 
}
class MembershipPaymentEditor extends StatefulWidget{
 const MembershipPaymentEditor({super.key});
 @override State<MembershipPaymentEditor> createState()=>_MembershipPaymentEditorState();
}
class _MembershipPaymentEditorState extends State<MembershipPaymentEditor>{
 RowData? receipt;
 @override Widget build(BuildContext context)=>PageFrame(title:'Pago anual de membresía',subtitle:'El monto y el periodo se calculan en el servidor',items:AppNavigation.member,child:LoadData(load:Api.settings,builder:(context,cfg,reload)=>Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
 Text('Cuota anual vigente: S/ ${cfg['annual_membership_amount']??0}',style:Theme.of(context).textTheme.headlineSmall),const SizedBox(height:16),
 EditForm(initial:const {'payment_method':'transferencia'},fields:const [FieldSpec('payment_method','Medio de pago',options:{'transferencia':'Transferencia','deposito':'Depósito','yape':'Yape','plin':'Plin'}),FieldSpec('operation_number','Número de operación')],label:'Registrar pago',extra:Column(children:[ActionButton(label:'Adjuntar comprobante',icon:Icons.upload_file,run:()async{final f=await Api.pickReceipt();if(f!=null)setState(()=>receipt=f);}),Text(receipt?['file_name']??'PDF / JPG / PNG, hasta 5 MB')]),save:(v)async{
 if(receipt==null)throw Exception('Adjunta el comprobante de pago.');await Api.edge('membership_payment',{...v,...receipt!});if(context.mounted)context.go('/miembro/pagos');})
 ])));
}
class AttendanceEditor extends StatefulWidget{
 const AttendanceEditor({super.key});
 @override State<AttendanceEditor> createState()=>_AttendanceEditorState();
}
class _AttendanceEditorState extends State<AttendanceEditor>{
 String? selected;final changes=<String,String>{};
 @override Widget build(BuildContext context)=>PageFrame(title:'Control de asistencia',subtitle:'Selecciona una sesión para registrar presentes y ausentes',items:AppNavigation.assistant,child:LoadData(load:()=>Api.data('attendance'),builder:(context,data,reload){
 final rows=Api.rows(data).where((r)=>r['status']=='approved').toList();final sessions=<String,RowData>{};
 for(final r in rows){for(final s in Api.rows(r['sessions'])){sessions[s['id']]={...s,'training':r['training']};}}
 final matching=rows.where((r)=>Api.rows(r['sessions']).any((s)=>s['id']==selected)).toList();
 return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[DropdownButtonFormField<String>(isExpanded:true,initialValue:selected,decoration:const InputDecoration(labelText:'Capacitación / sesión'),items:sessions.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text('${e.value['training']} · ${e.value['title']} · ${display(e.value['starts_at'])}',overflow:TextOverflow.ellipsis))).toList(),onChanged:(v)=>setState((){selected=v;changes.clear();})),const SizedBox(height:20),
 if(sessions.isEmpty)const Text('No hay sesiones con participantes aprobados.'),
 for(final r in matching)Card(child:ListTile(title:Text(r['full_name']),subtitle:Text('Asistencia acumulada: ${r['attendance_percent']} %'),trailing:DropdownButton<String>(value:changes[r['id']]??Api.rows(r['sessions']).firstWhere((s)=>s['id']==selected)['status'],hint:const Text('Sin registrar'),items:const [DropdownMenuItem(value:'present',child:Text('Presente')),DropdownMenuItem(value:'absent',child:Text('Ausente'))],onChanged:r['certificate_number']!=null?null:(v)=>setState(()=>changes[r['id']]=v!)))),
 const SizedBox(height:20),ActionButton(label:'Guardar asistencia',run:()async{if(selected==null||changes.isEmpty)throw Exception('Selecciona una sesión y registra asistencia.');await Api.action('save_attendance',{'rows':[for(final e in changes.entries){'session_id':selected,'enrollment_id':e.key,'status':e.value}]});changes.clear();reload();if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Asistencia guardada')));})]);
 }));
}

Future<void> reviewRegistration(BuildContext context,RowData r) async {
 final source=Map<String,dynamic>.from(r['registration_snapshot']??r);
 final checks=registrationChecks(r);
 await showDialog<void>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setDialog)=>AlertDialog(title:const Text('Validación de campos TRC'),content:SizedBox(width:620,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[const Text('Marca cada campo correcto y completo. En las preguntas Sí/No se valida que exista respuesta, no que la respuesta sea afirmativa.'),for(final field in trcFields.entries)CheckboxListTile(title:Text(field.value.replaceAll('\n',' ')),subtitle:Text(display(source[field.key])),value:checks[field.key],onChanged:(v){setDialog((){checks[field.key]=v??false;});})]))),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancelar')),ActionButton(label:'Guardar validación',run:()async{await Api.client.rpc('spae_review_fields',params:{'p_id':r['id'],'p_checks':checks});if(ctx.mounted)Navigator.pop(ctx);})])));
}

Future<void> activateMembership(BuildContext context,RowData member) async {
 final pending=Api.rows(member['payments']??[]).where((p)=>p['status']=='pending').toList();
 if(pending.isEmpty){throw Exception('No hay un pago anual pendiente. El miembro debe adjuntar su comprobante desde su portal antes de activar o renovar.');}
 await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(title:Text('Activar membresía · ${member['full_name']}'),content:SizedBox(width:620,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[const Text('Revisa el comprobante. Aprobar el pago activa o renueva la membresía por 12 meses.'),for(final p in pending)Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(children:[Text('S/ ${p['amount']} · Operación: ${p['operation_number']}'),Wrap(spacing:12,runSpacing:12,children:[ActionButton(label:'Ver comprobante',run:()async{final result=await Api.edge('receipt',{'path':p['receipt_path']});await downloadUrl(result['signedUrl'],'comprobante.${p['receipt_path'].toString().split('.').last}');}),ActionButton(label:'Confirmar activación',confirm:true,run:()async{await Api.action('review_membership',{'id':p['id'],'status':'approved'});if(ctx.mounted)Navigator.pop(ctx);})])])))]))),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cerrar'))]));
}
