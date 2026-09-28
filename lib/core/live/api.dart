import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

typedef RowData = Map<String, dynamic>;
class Api {
 static SupabaseClient get client {
  if (!SupabaseConfig.isConfigured) throw StateError('Faltan SUPABASE_URL y SUPABASE_PUBLISHABLE_KEY.');
  return Supabase.instance.client;
 }
 static Future<dynamic> data(String scope) async {
  if(scope=='enrollments'||scope=='certificates')await client.rpc('spae_link_member');
  return client.rpc('spae_data',params:{'p_scope':scope});
 }
 static Future<RowData> action(String action, RowData values) async => Map<String,dynamic>.from(await client.rpc('spae_action',params:{'p_action':action,'p':values}));
 // Estas operaciones no dependen del despliegue de la Edge Function.
 static Future<dynamic> reviewEnrollment(String id, {String status='approved',String? reason}) => _participantRpc(
  'spae_review_enrollment_v2', {'p_id':id,'p_status':status,'p_reason':reason});
 static Future<dynamic> deleteParticipant(String id) => _participantRpc(
  'spae_delete_participant', {'p_id':id});
 static Future<dynamic> memberState(String id,bool enabled) => _participantRpc(
  'spae_member_state', {'p_id':id,'p_enabled':enabled});
 static Future<dynamic> _participantRpc(String name, RowData params) async {
  try {return await client.rpc(name,params:params);}
  on PostgrestException catch(e) {
   if(e.code=='PGRST202'||e.code=='42883') {
    throw Exception('Falta actualizar la base de datos. Ejecuta las migraciones 202609270001 y 202609270002 en Supabase SQL Editor y vuelve a intentar.');
   }
   throw Exception(e.message);
  }
 }
 static Future<dynamic> edge(String action,RowData values) async {
  try {
   final response=await client.functions.invoke('spae-api',body:{'action':action,'payload':values});
   final result=response.data;
   if(result is Map && result['error']!=null) throw Exception(result['error']);
   return result;
  } on FunctionException catch(e) {
   final message=e.details is Map?(e.details['error']??e.details['message']??e.details).toString():e.details.toString();
   if(message.contains('no admitida')||message.contains('no soportada')) {
    throw Exception('El servidor tiene una versión anterior de spae-api. Ejecuta scripts/ACTUALIZAR_BACKEND_2709.ps1 desde este proyecto y vuelve a iniciar sesión.');
   }
   throw Exception(message);
  }
 }
 static Future<List<RowData>> trainings() async => rows(await client.rpc('spae_catalogue'));
 static Future<RowData> training(String id) async {
  final list=await trainings();
  final t=list.firstWhere((r)=>r['id']==id,orElse:()=>throw Exception('Capacitación no disponible.'));
  t['sessions']=await client.from('training_sessions').select().eq('training_id',id).order('starts_at');
  return t;
 }
 static Future<RowData> settings() async => Map<String,dynamic>.from(await client.rpc('spae_public_settings'));
 static Future<dynamic> memberAccounts() async => client.rpc('spae_member_accounts');
 static List<RowData> rows(dynamic data) => (data as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList();
 static Future<RowData?> pickReceipt() async {
  final r=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:['pdf','jpg','jpeg','png'],withData:true);
  if(r==null) return null;
  final f=r.files.single;
  if(f.bytes==null||f.size>5*1024*1024) throw Exception('Selecciona un PDF, JPG o PNG de hasta 5 MB.');
  return {'file_name':f.name,'file_base64':base64Encode(f.bytes!)};
 }
 static Future<RowData?> pickFlyer() async {
  final result=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:['jpg','jpeg','png'],withData:true);
  if(result==null)return null;
  final file=result.files.single;
  if(file.bytes==null||file.size>3*1024*1024)throw Exception('Selecciona una imagen JPG o PNG de hasta 3 MB.');
  return {'file_name':file.name,'file_base64':base64Encode(file.bytes!)};
 }
}

const Duration _peruOffset=Duration(hours:5); // Perú = UTC-5, sin horario de verano.
String _two(int n)=>n.toString().padLeft(2,'0');
bool _hasExplicitZone(String value)=>value.endsWith('Z')||RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(value);

/// Convierte un timestamptz del servidor a los componentes de hora civil de Perú.
/// Si el texto no trae zona horaria, se interpreta como una fecha/hora ya escrita en hora local.
DateTime? peruWallDateTime(dynamic value){
 final raw=(value??'').toString().trim();
 if(raw.isEmpty)return null;
 final parsed=DateTime.tryParse(raw);
 if(parsed==null)return null;
 if(_hasExplicitZone(raw)||parsed.isUtc)return parsed.toUtc().subtract(_peruOffset);
 return parsed;
}

String editablePeruDateTime(dynamic value){
 final dt=peruWallDateTime(value);
 if(dt==null)return (value??'').toString();
 return '${dt.year.toString().padLeft(4,'0')}-${_two(dt.month)}-${_two(dt.day)} ${_two(dt.hour)}:${_two(dt.minute)}';
}

String formatPeruDateTime(dynamic value,{bool dateOnly=false}){
 final raw=(value??'').toString().trim();
 if(raw.isEmpty)return '—';
 if(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)){
  final p=raw.split('-');return '${p[2]}/${p[1]}/${p[0]}';
 }
 final dt=peruWallDateTime(raw);
 if(dt==null)return raw;
 final date='${_two(dt.day)}/${_two(dt.month)}/${dt.year.toString().padLeft(4,'0')}';
 return dateOnly?date:'$date ${_two(dt.hour)}:${_two(dt.minute)}';
}

/// Toma los componentes elegidos en el formulario como hora de Perú y los guarda en UTC.
/// Esto evita que la zona horaria del navegador cambie el día seleccionado.
String peruWallClockToUtcIso(dynamic value){
 final raw=(value??'').toString().trim();
 final parsed=DateTime.tryParse(raw);
 if(parsed==null)throw FormatException('Fecha no válida');
 if(_hasExplicitZone(raw)||parsed.isUtc)return parsed.toUtc().toIso8601String();
 final utc=DateTime.utc(parsed.year,parsed.month,parsed.day,parsed.hour+5,parsed.minute,parsed.second,parsed.millisecond,parsed.microsecond);
 return utc.toIso8601String();
}

String display(dynamic value) {
 if(value==null) return '—';
 if(value is bool)return value?'Sí':'No';
 const names={'pending':'Pendiente','approved':'Aprobado','rejected':'Rechazado','active':'Activo','expired':'Vencido','inactive':'Inactiva','draft':'Borrador','cancelled':'Cancelado','completed':'Finalizado','present':'Presente','absent':'Ausente','virtual':'Virtual','hybrid':'Híbrida','in_person':'Presencial'};
 final raw=value.toString();
 if(names.containsKey(raw))return names[raw]!;
 if(RegExp(r'^\d{4}-\d{2}-\d{2}(?:T|\s|$)').hasMatch(raw))return formatPeruDateTime(raw,dateOnly:!raw.contains('T')&&!raw.contains(' '));
 return raw;
}
