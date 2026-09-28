import 'indicator_values.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../navigation/nav_items.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../widgets/page_frame.dart';
import '../widgets/responsive_grid.dart';
import 'api.dart';
import 'components.dart';
import 'download.dart';

class CatalogueView extends StatelessWidget{
 const CatalogueView({super.key,this.landing=false,this.member=false});final bool landing,member;
 @override Widget build(BuildContext context)=>PageFrame(title:landing?'Capacitación especializada para profesionales de enfermería':'Capacitaciones disponibles',subtitle:'Sociedad Peruana de Auditoría en Enfermería',publicHeader:!member,items:member?AppNavigation.member:const [],child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
 if(landing)...[Container(padding:const EdgeInsets.all(32),decoration:BoxDecoration(color:AppColors.primary,borderRadius:BorderRadius.circular(16)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Icon(Icons.health_and_safety_outlined,size:64,color:Colors.white),const SizedBox(height:16),const Text('Formación, participación y certificación en un solo lugar',style:TextStyle(fontSize:26,fontWeight:FontWeight.bold,color:Colors.white)),const SizedBox(height:20),Wrap(spacing:12,runSpacing:12,children:[FilledButton.tonal(onPressed:()=>context.go('/capacitaciones'),child:const Text('Ver capacitaciones')),FilledButton.tonal(onPressed:()=>context.go('/miembro/registro'),child:const Text('Ser miembro'))])])),const SizedBox(height:28),Text('Próximas capacitaciones',style:Theme.of(context).textTheme.headlineSmall),const SizedBox(height:16)],
 LoadData(load:()async=>{'trainings':await Api.trainings(),'settings':member?await Api.settings():<String,dynamic>{}},builder:(context,data,reload)=>CatalogueGrid(rows:Api.rows(data['trainings']),limit:landing?3:null,member:member,certificateSurcharge:num.tryParse('${data['settings']['certificate_surcharge_amount']??50}')??50)),
 if(landing)...[const SizedBox(height:32),const Card(child:Padding(padding:EdgeInsets.all(28),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Nosotros',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),SizedBox(height:12),Text('SPAE promueve la formación profesional en auditoría en enfermería, la calidad de los registros y la mejora de la gestión sanitaria.')]))),const SizedBox(height:24),const ExpansionTile(title:Text('¿Necesito una cuenta para inscribirme?'),children:[Padding(padding:EdgeInsets.all(16),child:Text('Puedes inscribirte sin cuenta. Conserva el código privado que se entrega al finalizar para consultar tu historial.'))]),const ExpansionTile(title:Text('¿Cuándo puedo descargar mi certificado?'),children:[Padding(padding:EdgeInsets.all(16),child:Text('Después de aprobarse el pago, alcanzar la asistencia mínima y emitirse el certificado por la asistente.'))]),LoadData(load:Api.settings,builder:(context,data,reload)=>Card(child:Padding(padding:const EdgeInsets.all(24),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Contacto',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),for(final k in ['contact_email','contact_phone','contact_address'])if((data[k]??'').toString().isNotEmpty)SelectableText(data[k].toString()),for(final link in {'contact_facebook':'Facebook','contact_whatsapp':'WhatsApp'}.entries)if((data[link.key]??'').toString().startsWith('https://'))TextButton(onPressed:()=>launchUrl(Uri.parse(data[link.key].toString()),mode:LaunchMode.externalApplication),child:Text(link.value)),if(['contact_email','contact_phone','contact_address','contact_facebook','contact_whatsapp'].every((k)=>(data[k]??'').toString().isEmpty))const Text('La institución aún no ha publicado sus datos de contacto.')]))))]
 ]));
}
class CatalogueGrid extends StatefulWidget{
 const CatalogueGrid({super.key,required this.rows,this.limit,this.member=false,this.certificateSurcharge=50});final List<RowData> rows;final int? limit;final bool member;final num certificateSurcharge;
 @override State<CatalogueGrid> createState()=>_CatalogueGridState();
}
class _CatalogueGridState extends State<CatalogueGrid>{
 String search='',mode='';
 @override Widget build(BuildContext context){
 final rows=widget.rows.where((r)=>r['title'].toString().toLowerCase().contains(search.toLowerCase())&&(mode.isEmpty||r['modality']==mode)).take(widget.limit??widget.rows.length).toList();
 return Column(children:[if(widget.limit==null)...[Wrap(spacing:12,runSpacing:12,children:[SizedBox(width:320,child:TextField(onChanged:(v)=>setState(()=>search=v),decoration:const InputDecoration(labelText:'Buscar capacitación',prefixIcon:Icon(Icons.search)))),SizedBox(width:220,child:DropdownButtonFormField<String>(initialValue:mode,decoration:const InputDecoration(labelText:'Modalidad'),items:const [DropdownMenuItem(value:'',child:Text('Todas')),DropdownMenuItem(value:'virtual',child:Text('Virtual')),DropdownMenuItem(value:'hybrid',child:Text('Híbrida')),DropdownMenuItem(value:'in_person',child:Text('Presencial'))],onChanged:(v)=>setState(()=>mode=v??'')))]),const SizedBox(height:20)],
 if(rows.isEmpty)const Padding(padding:EdgeInsets.all(24),child:Text('No hay capacitaciones publicadas para esta búsqueda.')),
 ResponsiveGrid(minWidth:300,children:rows.map((r)=>Card(clipBehavior:Clip.antiAlias,child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
 if((r['image_url']??'').toString().startsWith('https://'))Image.network(r['image_url'],height:150,fit:BoxFit.cover,errorBuilder:(_,e,s)=>const SizedBox(height:100,child:Icon(Icons.school,size:50)))else Container(height:110,color:AppColors.primary,child:const Icon(Icons.school_outlined,color:Colors.white,size:48)),
 Padding(padding:const EdgeInsets.all(22),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(display(r['modality']),style:const TextStyle(color:AppColors.secondary)),const SizedBox(height:8),Text(r['title'],style:const TextStyle(fontWeight:FontWeight.bold,fontSize:20)),const SizedBox(height:12),Text('Inicio: ${display(r['start_date'])}'),Text(widget.member?'${r['total_hours']} horas · Curso: Exonerado · Certificado: S/ ${widget.certificateSurcharge} · ${r['available_capacity']} cupos':'${r['total_hours']} horas · S/ ${r['price']} · ${r['available_capacity']} cupos'),const SizedBox(height:16),FilledButton(onPressed:()=>context.go(widget.member?'/miembro/inscripcion/${r['id']}':'/capacitaciones/${r['id']}'),child:const Text('Ver detalles'))]))]))).toList())]);
 }
}
class TrainingDetailView extends StatelessWidget{
 const TrainingDetailView({super.key,required this.id});final String id;
 @override Widget build(BuildContext context)=>PageFrame(title:'Detalle de capacitación',subtitle:'Información académica e inscripción',publicHeader:true,child:LoadData(load:()=>Api.training(id),builder:(context,t,reload)=>Card(child:Padding(padding:const EdgeInsets.all(28),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
 if((t['image_url']??'').toString().startsWith('https://'))Image.network(t['image_url'],height:360,width:double.infinity,fit:BoxFit.contain,errorBuilder:(_,e,s)=>const Icon(Icons.image_not_supported)),const SizedBox(height:18),Text(t['title'],style:Theme.of(context).textTheme.headlineMedium),const SizedBox(height:20),Text(t['description']??''),const SizedBox(height:16),Text('${display(t['modality'])} · ${t['total_hours']} horas · S/ ${t['price']}'),Text('Inicio: ${display(t['start_date'])} · Cupos disponibles: ${t['available_capacity']}'),
 for(final key in ['objectives','syllabus','speaker'])if((t[key]??'').toString().isNotEmpty)Padding(padding:const EdgeInsets.symmetric(vertical:10),child:Text('${{'objectives':'Objetivos','syllabus':'Temario','speaker':'Expositor'}[key]}\n${t[key]}')),
 for(final s in Api.rows(t['sessions']))ListTile(leading:const Icon(Icons.calendar_today),title:Text(s['title']),subtitle:Text(display(s['starts_at']))),const SizedBox(height:20),FilledButton(onPressed:t['status']=='active'&&(t['available_capacity'] as num)>0?()=>context.go('/inscripcion/$id'):null,child:const Text('Inscribirme'))])))));
}
class PublicEnrollmentView extends StatefulWidget{
 const PublicEnrollmentView({super.key,required this.id,this.member=false});final String id;final bool member;
 @override State<PublicEnrollmentView> createState()=>_PublicEnrollmentViewState();
}
class _PublicEnrollmentViewState extends State<PublicEnrollmentView>{
 RowData? receipt;bool consent=false;
 @override Widget build(BuildContext context)=>PageFrame(title:widget.member?'Inscribirme a capacitación':'Inscripción pública',subtitle:'Completa tus datos y selecciona si deseas certificado',publicHeader:!widget.member,items:widget.member?AppNavigation.member:const [],child:LoadData(load:()async{final t=await Api.training(widget.id);t['settings']=await Api.settings();if(widget.member)t['member_profile']=await Api.data('profile');return t;},builder:(context,t,reload)=>Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[Text('${t['title']} · ${widget.member?'Curso: Exonerado · Certificado: S/ ${t['settings']['certificate_surcharge_amount']??50}':'Costo del curso S/ ${t['price']}'}',style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:16),EditForm(initial:{'payment_method':'transferencia',if(widget.member)...Map<String,dynamic>.from(t['member_profile'])},fields:[FieldSpec('full_name','Apellidos y nombres completos'),FieldSpec('dni','DNI (8 dígitos)',readOnly:widget.member&&(t['member_profile']?['dni']??'').toString().trim().isNotEmpty,help:widget.member&&(t['member_profile']?['dni']??'').toString().trim().isEmpty?'Completa tu DNI aquí; se guardará también en tu perfil.':null),FieldSpec('phone','Celular peruano (9 dígitos)'),FieldSpec('email','Correo electrónico',readOnly:widget.member),FieldSpec('nurse_auditor_registry','¿Registro de enfermera auditora?',options:{'true':'Sí','false':'No'}),FieldSpec('hospital','Hospital o institución donde labora'),FieldSpec('region','Región',options:{for(final region in peruRegions)region:region}),FieldSpec('wants_certificate','¿Desea certificado?',options:{'true':'Sí','false':'No'}),FieldSpec('payment_method','Medio de pago',required:!widget.member,options:{'transferencia':'Transferencia','deposito':'Depósito','yape':'Yape','plin':'Plin'}),FieldSpec('operation_number','Número de operación',required:!widget.member),if(!widget.member)const FieldSpec('previous_code','Código privado anterior (opcional)',required:false,secret:true,help:'Déjalo vacío en tu primera inscripción. Si ya tienes historial, usa el código recibido antes. Protege tus certificados; la asistente puede restablecerlo tras verificar tu identidad.')],extra:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('NOTA: Se adicionan S/ ${t['settings']['certificate_surcharge_amount']??50} al monto del curso si seleccionas Sí en «¿Desea certificado?».${widget.member?' Sin certificado, el miembro activo se inscribe gratis y no adjunta comprobante.':''}',style:const TextStyle(color:Colors.red,fontWeight:FontWeight.w600)),const SizedBox(height:12),ActionButton(label:'Adjuntar comprobante',icon:Icons.upload_file,run:()async{final f=await Api.pickReceipt();if(f!=null)setState(()=>receipt=f);}),Text(receipt?['file_name']??'PDF, JPG o PNG hasta 5 MB'),CheckboxListTile(value:consent,contentPadding:EdgeInsets.zero,controlAffinity:ListTileControlAffinity.leading,title:const Text('Autorizo el uso de mis datos para gestionar esta inscripción y certificación.'),onChanged:(v)=>setState(()=>consent=v??false))]),label:'Enviar inscripción',save:(v)async{
 if(!consent)throw Exception('Debes autorizar el uso de tus datos.');if((!widget.member||v['wants_certificate']=='true')&&(receipt==null||(v['operation_number']??'').toString().trim().isEmpty))throw Exception('Para este registro indica número de operación y adjunta el comprobante.');
 if(widget.member&&(t['member_profile']?['dni']??'').toString().trim().isEmpty){
  await Api.action('save_profile',{...v,'nurse_auditor_registry':v['nurse_auditor_registry']=='true'});
 }
 final result=await Api.edge(widget.member?'member_enroll':'enroll',{...v,'nurse_auditor_registry':v['nurse_auditor_registry']=='true','wants_certificate':v['wants_certificate']=='true','training_id':widget.id,...?receipt});
 if(context.mounted){if(widget.member){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Inscripción guardada y pendiente de revisión.')));context.go('/miembro/historial');}else{context.go('/inscripcion/confirmacion',extra:Map<String,dynamic>.from(result));}}})])));
}
class ConfirmationView extends StatelessWidget{
 const ConfirmationView({super.key,this.receipt});final RowData? receipt;
 @override Widget build(BuildContext context)=>PageFrame(title:'Confirmación de inscripción',subtitle:'',publicHeader:true,child:Card(child:Padding(padding:const EdgeInsets.all(32),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:receipt==null?[const Text('Consulta el estado con tu código privado. La confirmación se muestra después de enviar una inscripción.'),TextButton(onPressed:()=>context.go('/consulta'),child:const Text('Consultar inscripción'))]:[
 const Icon(Icons.check_circle,color:Colors.green,size:56),const SizedBox(height:16),const Text('Tu inscripción se guardó y está pendiente de revisión.',style:TextStyle(fontSize:22)),const SizedBox(height:20),SelectableText('Inscripción: ${receipt!['code']}'),const SizedBox(height:16),const Text('Conserva este código privado para consultar tu historial y certificados:'),SelectableText(receipt!['private_code']??'',style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold)),TextButton.icon(onPressed:()async{await Clipboard.setData(ClipboardData(text:receipt!['private_code']??''));if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Código copiado')));},icon:const Icon(Icons.copy),label:const Text('Copiar código')), const SizedBox(height:20),FilledButton(onPressed:()=>context.go('/consulta'),child:const Text('Consultar estado'))]))));
}
class PublicLookupView extends StatefulWidget{
 const PublicLookupView({super.key,this.certificates=false});final bool certificates;
 @override State<PublicLookupView> createState()=>_PublicLookupViewState();
}
class _PublicLookupViewState extends State<PublicLookupView>{
 List<RowData>? rows;RowData credentials={};
 Future<void> _openWhatsApp(BuildContext context,String raw)async{
  final uri=Uri.tryParse(raw);
  if(uri==null||!uri.hasScheme){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('El WhatsApp de contacto aún no está configurado.')));return;}
  final ok=await launchUrl(uri,mode:LaunchMode.externalApplication);
  if(!ok&&context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('No se pudo abrir WhatsApp.')));
 }
 @override Widget build(BuildContext context)=>PageFrame(
  title:widget.certificates?'Historial y certificados':'Estado de inscripción',
  subtitle:'Usa tu DNI o correo y el código privado recibido al inscribirte',
  publicHeader:true,
  child:LoadData(load:Api.settings,builder:(context,cfg,reload){
   final whatsapp=(cfg['contact_whatsapp']??'').toString().trim();
   return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:780),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
     EditForm(initial:const {},fields:const [
      FieldSpec('term','DNI o correo'),
      FieldSpec('code','Código privado',secret:true,help:'Este código se genera al crear la inscripción'),
     ],label:'Consultar',save:(v)async{final result=await Api.edge('lookup',v);setState((){credentials=v;rows=Api.rows(result);});}),
     const SizedBox(height:10),
     Align(alignment:Alignment.centerLeft,child:OutlinedButton.icon(onPressed:whatsapp.isEmpty?null:()=>_openWhatsApp(context,whatsapp),icon:const Icon(Icons.chat_outlined),label:const Text('Olvidé mi código'))),
     if(whatsapp.isEmpty)const Padding(padding:EdgeInsets.only(top:6),child:Text('El WhatsApp de contacto aún no está configurado.',style:TextStyle(fontSize:12,color:Colors.black54))),
    ]))),
    const SizedBox(height:24),
    if(rows!=null)Records(rows:rows!,columns:const {'code':'Inscripción','training':'Capacitación','status':'Estado','rejection_reason':'Observación','payment_status':'Pago','attendance_percent':'Asistencia %'},actions:(r)=>Wrap(children:[
     if(r['certificate_number']!=null)ActionButton(label:'Descargar PDF',icon:Icons.download,run:()async{final result=await Api.edge('public_certificate',{...credentials,'id':r['id']});await downloadUrl(result['signedUrl'],'${r['certificate_number']}.pdf');}),
     if(r['status']=='rejected')ActionButton(label:'Corregir comprobante',run:()async{final operation=await askText(context,'Número de operación corregido');if(operation==null)return;final f=await Api.pickReceipt();if(f==null)return;await Api.edge('resubmit',{...credentials,...f,'id':r['id'],'operation_number':operation});final result=await Api.edge('lookup',credentials);if(mounted)setState(()=>rows=Api.rows(result));}),
    ])),
   ]);
  }),
 );
}
