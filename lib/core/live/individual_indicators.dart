import 'package:flutter/material.dart';
import '../widgets/metric_card.dart';
import '../widgets/responsive_grid.dart';
import 'api.dart';
import 'components.dart';
import 'indicator_values.dart';
import 'download.dart';

class IndividualIndicators extends StatefulWidget {
 const IndividualIndicators({super.key});
 @override State<IndividualIndicators> createState()=>_IndividualIndicatorsState();
}
class _IndividualIndicatorsState extends State<IndividualIndicators>{
 String training='',kind='NAA';
 @override Widget build(BuildContext context)=>LoadData(load:()=>Api.client.rpc('spae_individual_indicators'),builder:(context,data,reload){
 final all=Api.rows(data);final courses=<String,String>{for(final r in all)r['training_id']:r['training']};
 final selected=all.where((r)=>r['training_id']==training).toList();
 final blocks=selected.isEmpty?0:Api.rows(selected.first['sessions']).length;
 final rows=indicatorRows(selected,kind);final columns=indicatorColumns(kind,blocks);
 String mean(String k){final nums=indicatorRows(selected,k).map((r)=>r['value']).whereType<num>().toList();return nums.isEmpty?'Sin datos':(nums.reduce((a,b)=>a+b)/nums.length).toStringAsFixed(k=='TEC'?3:1);}
 return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
 DropdownButtonFormField<String>(initialValue:training,isExpanded:true,decoration:const InputDecoration(labelText:'Selecciona la capacitación'),items:[const DropdownMenuItem(value:'',child:Text('Seleccionar')),...courses.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value)))],onChanged:(v){setState((){training=v??'';});}),
 const SizedBox(height:18),
 if(training.isEmpty)const Text('Selecciona un curso para ver sus participantes y exportar las fichas NAA, TRC y TEC.'),
 if(training.isNotEmpty)...[
 ResponsiveGrid(children:[MetricCard(label:'Participantes',value:'${selected.length}',icon:Icons.groups),MetricCard(label:'NAA promedio %',value:mean('NAA'),icon:Icons.fact_check),MetricCard(label:'TRC promedio %',value:mean('TRC'),icon:Icons.rule),MetricCard(label:'TEC promedio horas',value:mean('TEC'),icon:Icons.timer)]),
 const SizedBox(height:20),DropdownButtonFormField<String>(initialValue:kind,decoration:const InputDecoration(labelText:'Ficha por participante'),items:const [DropdownMenuItem(value:'NAA',child:Text('NAA · Nivel de asistencia acumulada')),DropdownMenuItem(value:'TRC',child:Text('TRC · Tasa de registros completos')),DropdownMenuItem(value:'TEC',child:Text('TEC · Tiempo de emisión de certificados'))],onChanged:(v){setState((){kind=v!;});}),
 const SizedBox(height:16),
 Text(kind=='NAA'?'NAAi = bloques presentes / $blocks bloques × 100. Incluye todas las inscripciones.':kind=='TRC'?'TRCi = campos válidos / 7 × 100. Sí indica que la respuesta es válida, incluso cuando la persona respondió No.':'TECi = emisión del PDF − cumplimiento, en horas con tres decimales. Los pendientes no entran en el promedio.'),
 if(kind=='TRC')const Text('Los campos se validan automáticamente con los datos del formulario de inscripción.'),
 const SizedBox(height:16),Records(key:ValueKey('$training-$kind'),rows:rows.map((r)=>kind=='TEC'&&r['value'] is num?{...r,'value':(r['value'] as num).toStringAsFixed(3)}:r).toList(),columns:columns,export:(filtered)=>exportIndicator(filtered.map((r)=>kind=='TEC'?{...r,'value':num.tryParse(r['value'].toString())??r['value']}:r).toList(),columns,kind,courses[training]!,blocks,sessions:Api.rows(selected.first['sessions']),trainingDate:display(selected.first['start_date']))),
 if(kind=='NAA')...Api.rows(selected.first['sessions']).asMap().entries.map((e)=>Text('B${e.key+1}: ${e.value['title']} · ${display(e.value['starts_at'])}')),
 const SizedBox(height:16),ExpansionTile(title:const Text('Identificación de participantes'),children:[Records(rows:selected,columns:const {'participant_code':'Código de participante','full_name':'Nombres y apellidos','dni':'DNI'})])]
 ]);
 });
}
