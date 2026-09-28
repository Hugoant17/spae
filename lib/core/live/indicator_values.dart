import 'api.dart';
const trcFields={'full_name':'Apellido y\nnombres','dni':'N.° DNI','phone':'N.° de\nteléfono','nurse_auditor_registry':'¿Registro de\nenfermera\nauditora?','hospital':'Hospital\ndonde labora','region':'Región','wants_certificate':'¿Desea\ncertificado?'};
const peruRegions=['Amazonas','Áncash','Apurímac','Arequipa','Ayacucho','Cajamarca','Callao','Cusco','Huancavelica','Huánuco','Ica','Junín','La Libertad','Lambayeque','Lima','Loreto','Madre de Dios','Moquegua','Pasco','Piura','Puno','San Martín','Tacna','Tumbes','Ucayali'];
String normalizeRegion(String value){var v=value.toLowerCase().trim();const chars={'á':'a','é':'e','í':'i','ó':'o','ú':'u'};chars.forEach((a,b){v=v.replaceAll(a,b);});return v=='cuzco'?'cusco':v;}
Map<String,bool> registrationChecks(RowData row){
 final s=Map<String,dynamic>.from(row['registration_snapshot']??row);
 final checks=<String,bool>{
 'full_name':(s['full_name']??'').toString().trim().split(RegExp(r'\s+')).length>=2,
 'dni':RegExp(r'^\d{8}$').hasMatch((s['dni']??'').toString()),
 'phone':RegExp(r'^9\d{8}$').hasMatch((s['phone']??'').toString()),
 'nurse_auditor_registry':s['nurse_auditor_registry'] is bool,
 'hospital':(s['hospital']??'').toString().trim().length>=3,
 'region':peruRegions.map(normalizeRegion).contains(normalizeRegion((s['region']??'').toString())),
 'wants_certificate':s['wants_certificate'] is bool,
 };
 return checks;
}
double trcValue(RowData row)=>double.parse((registrationChecks(row).values.where((v)=>v).length/7*100).toStringAsFixed(1));
double? naaValue(RowData row){final sessions=Api.rows(row['sessions']??[]);return sessions.isEmpty?null:double.parse((sessions.where((s)=>s['status']=='present').length/sessions.length*100).toStringAsFixed(1));}
double? tecValue(RowData row){final start=DateTime.tryParse('${row['requirement_met_at']}');final end=DateTime.tryParse('${row['issued_at']}');return start==null||end==null?null:double.parse((end.difference(start).inMilliseconds/3600000).clamp(0,double.infinity).toStringAsFixed(3));}
Map<String,String> indicatorColumns(String kind,int blocks)=>kind=='NAA'?{'number':'N.°','participant_code':'Código de\nparticipante',for(var i=1;i<=blocks;i++)'b$i':'B$i','value':'NAAi (%)'}:kind=='TEC'?{'number':'N.°','participant_code':'Código de participante','requirement_met_at':'Hora de cumplimiento','issued_at':'Hora de emisión','value':'TECi (horas)'}:{'number':'N.°','participant_code':'Código de\nparticipante',...trcFields,'value':'% de completitud\ndel registro'};
List<RowData> indicatorRows(List<RowData> source,String kind){
 final selected=kind=='TEC'?source.where((r)=>r['certificate_number']!=null||(r['wants_certificate']==true&&r['requirement_met_at']!=null)).toList():source;
 return [for(var n=0;n<selected.length;n++){
  'number':n+1,'participant_code':selected[n]['participant_code'],
  if(kind=='NAA')...{for(var i=0;i<Api.rows(selected[n]['sessions']).length;i++)'b${i+1}':display(Api.rows(selected[n]['sessions'])[i]['status']??'Sin registrar'),'value':naaValue(selected[n])},
  if(kind=='TRC')...{for(final e in registrationChecks(selected[n]).entries)e.key:e.value?'Sí':'No','value':trcValue(selected[n])},
  if(kind=='TEC')...{'requirement_met_at':selected[n]['requirement_met_at'],'issued_at':selected[n]['issued_at']??'Pendiente','value':tecValue(selected[n])??'Pendiente'},
 }];
}
