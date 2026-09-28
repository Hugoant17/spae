import 'package:flutter_test/flutter_test.dart';
import 'package:spae_capacitaciones/core/live/indicator_values.dart';
void main(){
 final row=<String,dynamic>{'participant_code':'INS-001','sessions':[{'status':'present'},{'status':'absent'},{'status':'present'},{'status':null},{'status':'present'}], 'registration_snapshot':{'full_name':'Ana Torres','dni':'12345678','phone':'987654321','hospital':'Hospital Central','region':'Puno','nurse_auditor_registry':false,'wants_certificate':false},'requirement_met_at':'2026-09-10T12:00:00Z','issued_at':'2026-09-10T14:30:00Z'};
 test('NAA incluye bloques ausentes y sin registrar en el denominador',(){expect(naaValue(row),60);expect(naaValue({...row,'sessions':[]}),isNull);});
 test('TRC cuenta No como respuesta válida y valida campos incompletos',(){expect(trcValue(row),100);expect(trcValue({...row,'registration_snapshot':{...(row['registration_snapshot'] as Map<String,dynamic>),'hospital':''}}),85.7);});
 test('TEC se expresa en horas redondeadas; pendiente no vale cero',(){expect(tecValue(row),2.5);expect(tecValue({...row,'issued_at':null}),isNull);});
 test('TEC conserva tres decimales',(){expect(tecValue({...row,'issued_at':'2026-09-10T12:00:05Z'}),0.001);});
 test('cabeceras conservan los nombres de los formatos originales',(){expect(indicatorColumns('NAA',5).values.toList(),['N.°','Código de\nparticipante','B1','B2','B3','B4','B5','NAAi (%)']);expect(indicatorColumns('TEC',0).values.last,'TECi (horas)');expect(indicatorColumns('TRC',0).length,10);});
}
