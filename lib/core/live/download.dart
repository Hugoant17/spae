import 'indicator_templates.dart';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:http/http.dart' as http;
import 'api.dart';
import 'download_native.dart' if (dart.library.html) 'download_web.dart' as platform;
Future<void> downloadUrl(String url,String name) async {
 final response=await http.get(Uri.parse(url));
 if(response.statusCode!=200)throw Exception('No se pudo descargar el archivo');
 await platform.saveBytes(response.bodyBytes,name,response.headers['content-type']??'application/octet-stream');
}
Future<void> exportExcel(List<RowData> rows,Map<String,String> columns,String name) async {
 final excel=Excel.createExcel();final sheet=excel['Reporte'];excel.delete('Sheet1');
 sheet.appendRow(columns.values.map((e)=>TextCellValue(e)).toList());
 for(final row in rows){sheet.appendRow(columns.keys.map((key){final v=row[key];return v is int?IntCellValue(v):v is num?DoubleCellValue(v.toDouble()):TextCellValue(display(v));}).toList());}
 final bytes=excel.encode();if(bytes==null)throw Exception('No se pudo crear Excel');
 await platform.saveBytes(Uint8List.fromList(bytes),'$name.xlsx','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
}

String excelColumn(int zero){var n=zero+1;var result='';while(n>0){n--;result=String.fromCharCode(65+n%26)+result;n=n~/26;}return result;}
Future<void> exportIndicator(List<RowData> rows,Map<String,String> columns,String kind,String training,int blocks,{List<RowData> sessions=const [],String? trainingDate}) async {
 final excel=Excel.createExcel();final sheet=excel[kind];excel.delete('Sheet1');
 final header=kind=='NAA'?14:kind=='TRC'?20:13;
 void write(int row,int col,CellValue? value){sheet.cell(CellIndex.indexByColumnRow(columnIndex:col,rowIndex:row)).value=value;}
 for(final cell in indicatorTemplateCells[kind]!){write(cell[0] as int,cell[1] as int,TextCellValue(cell[2].toString()));}
 write(7,1,TextCellValue(training));
 write(3,kind=='TEC'?4:5,TextCellValue('Postest'));
 write(7,kind=='TEC'?4:5,TextCellValue(trainingDate??''));
 if(kind=='NAA'){
  write(8,1,IntCellValue(blocks));
  write(11,0,TextCellValue(sessions.asMap().entries.map((e)=>'Bloque ${e.key+1}: ${e.value['title']} (${display(e.value['starts_at'])})').join(' | ')));
 }
 for(var c=0;c<columns.length;c++){write(header,c,TextCellValue(columns.values.elementAt(c)));}
 final lastCol=columns.length-1;
 void mergeRow(int row,int from,int to){if(to>from)sheet.merge(CellIndex.indexByColumnRow(columnIndex:from,rowIndex:row),CellIndex.indexByColumnRow(columnIndex:to,rowIndex:row));}
 for(final row in [0,1]){mergeRow(row,0,lastCol);sheet.setRowHeight(row,28);}
 for(final row in [4,5,6]){mergeRow(row,1,lastCol);sheet.setRowHeight(row,row==6?110:44);}
 mergeRow(7,1,kind=='TEC'?2:3);sheet.setRowHeight(7,60);
 if(kind=='TRC'){for(var row=10;row<=17;row++){mergeRow(row,1,lastCol);sheet.setRowHeight(row,55);}mergeRow(19,0,lastCol);sheet.setRowHeight(19,44);}
 if(kind=='NAA'){mergeRow(10,0,lastCol);mergeRow(11,0,lastCol);sheet.setRowHeight(11,120);mergeRow(13,0,lastCol);sheet.setRowHeight(13,44);}
 if(kind=='TEC'){mergeRow(10,0,lastCol);sheet.setRowHeight(10,160);mergeRow(12,0,lastCol);sheet.setRowHeight(12,44);}
 for(final cell in indicatorTemplateCells[kind]!){sheet.cell(CellIndex.indexByColumnRow(columnIndex:cell[1] as int,rowIndex:cell[0] as int)).cellStyle=CellStyle(textWrapping:TextWrapping.WrapText,bold:(cell[0] as int)<2);}
 for(var i=0;i<rows.length;i++){
  final row=rows[i];final line=i+header+2;
  final cells=<CellValue?>[];
  for(final key in columns.keys){final v=row[key];
   if(key=='value'&&kind=='NAA'&&blocks>0){cells.add(FormulaCellValue('ROUND(COUNTIF(C$line:${excelColumn(blocks+1)}$line,"Presente")/$blocks*100,1)'));}
   else if(key=='value'&&kind=='TRC'){cells.add(FormulaCellValue('ROUND(COUNTIF(C$line:I$line,"Sí")/7*100,1)'));}
   else if(key=='value'&&kind=='TEC'&&v is num){cells.add(DoubleCellValue(v.toDouble()));}
   else if(kind=='TEC'&&(key=='requirement_met_at'||key=='issued_at')){cells.add(TextCellValue(display(v)));}
   else{cells.add(v is int?IntCellValue(v):v is num?DoubleCellValue(v.toDouble()):TextCellValue(display(v)));}
  }
  for(var col=0;col<cells.length;col++){write(line-1,col,cells[col]);}
 }
 for(var col=0;col<columns.length;col++){
  sheet.setColumnWidth(col,col==1?28:kind=='TRC'?24:22);
  sheet.cell(CellIndex.indexByColumnRow(columnIndex:col,rowIndex:header)).cellStyle=CellStyle(bold:true,textWrapping:TextWrapping.WrapText);
 }
 sheet.setRowHeight(header,64);
 final end=header+1+rows.length;
 write(end+2,0,TextCellValue('RESULTADO DEL TALLER (promedio de participantes exportados)'));
 if(rows.isNotEmpty){final column=excelColumn(columns.length-1);write(end+3,columns.length-1,FormulaCellValue('IFERROR(ROUND(AVERAGE($column${header+2}:$column$end),${kind=='TEC'?3:1}),"")'));}
 write(end+5,0,TextCellValue(kind=='NAA'?'NAAi = bloques presentes / N × 100; NAA = promedio(NAAi)':kind=='TRC'?'TRCi = campos válidos / 7 × 100; TRC = promedio(TRCi)':'TECi = hora de emisión del PDF − hora de cumplimiento, en horas con tres decimales; TEC = promedio(TECi)'));
 write(end+7,0,TextCellValue('Responsable del registro: ___________________________'));
 write(end+8,0,TextCellValue('Fechas y horas expresadas en hora de Perú (UTC-5). Datos reales del sistema; no incluye resultados Pretest de ejemplo.'));
 final bytes=excel.encode();if(bytes==null)throw Exception('No se pudo generar la ficha');
 await platform.saveBytes(Uint8List.fromList(bytes),'SPAE_${kind}_participantes.xlsx','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
}
