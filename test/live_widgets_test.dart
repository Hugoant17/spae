import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spae_capacitaciones/core/live/components.dart';

void main(){
 testWidgets('DNI registrado es de solo lectura y tiene fondo gris',(tester)async{
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:EditForm(initial:const {'dni':'12345678'},fields:const [FieldSpec('dni','DNI',readOnly:true)],save:(v)async{}))));
  final field=tester.widget<TextField>(find.byType(TextField));
  expect(field.readOnly,isTrue);expect(field.decoration?.filled,isTrue);
  expect(field.decoration?.fillColor,Colors.grey.shade200);
 });
 testWidgets('eliminar explica el alcance y cancelar no ejecuta la operación',(tester)async{
  var calls=0;
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:ActionButton(
   label:'Eliminar',confirm:true,confirmationMessage:'Se eliminarán las inscripciones y pagos.',run:()async{calls++;}))));
  await tester.tap(find.text('Eliminar'));await tester.pumpAndSettle();
  expect(find.text('Se eliminarán las inscripciones y pagos.'),findsOneWidget);
  await tester.tap(find.text('Cancelar'));await tester.pumpAndSettle();expect(calls,0);
  await tester.tap(find.text('Eliminar'));await tester.pumpAndSettle();
  await tester.tap(find.text('Confirmar'));await tester.pumpAndSettle();expect(calls,1);
 });
 testWidgets('un error de guardado se muestra y no se simula éxito',(tester)async{
  final pending=Completer<void>();int calls=0;
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:ActionButton(label:'Guardar',run:(){calls++;return pending.future;}))));
  await tester.tap(find.text('Guardar'));await tester.pump();
  expect(calls,1);expect(find.byType(CircularProgressIndicator),findsOneWidget);
  await tester.tap(find.text('Guardar'));await tester.pump();expect(calls,1);
  pending.completeError(Exception('Fallo de escritura'));await tester.pumpAndSettle();
  expect(find.textContaining('Fallo de escritura'),findsOneWidget);
  expect(find.byType(CircularProgressIndicator),findsNothing);
 });
 testWidgets('exportación utiliza las filas filtradas',(tester)async{
  List<Map<String,dynamic>>? exported;
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:SingleChildScrollView(child:Records(
    rows:const [{'full_name':'Ana Torres'},{'full_name':'Rosa Medina'}],columns:const {'full_name':'Participante'},
    export:(rows)async{exported=rows;},
  )))));
  await tester.enterText(find.byType(TextField),'Rosa');await tester.pumpAndSettle();
  await tester.tap(find.text('Exportar 1 filas a Excel'));await tester.pumpAndSettle();
  expect(exported?.length,1);expect(exported?.first['full_name'],'Rosa Medina');
 });
 testWidgets('formulario vacío no ejecuta guardado',(tester)async{
  var saved=false;
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:SingleChildScrollView(child:EditForm(initial:const {},fields:const [FieldSpec('title','Nombre')],save:(value)async{saved=true;})))));
  await tester.tap(find.text('Guardar'));await tester.pumpAndSettle();
  expect(saved,false);expect(find.text('Completa nombre'),findsOneWidget);
 });
 testWidgets('recargar después de guardar no devuelve Future dentro de setState',(tester)async{
  var calls=0;
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:LoadData(load:()async{calls++;return calls;},builder:(context,value,reload)=>TextButton(onPressed:reload,child:Text('Recargar $value'))))));
  await tester.pumpAndSettle();expect(calls,1);
  await tester.tap(find.text('Recargar 1'));await tester.pumpAndSettle();
  expect(tester.takeException(),isNull);expect(calls,2);expect(find.text('Recargar 2'),findsOneWidget);
 });
 testWidgets('fecha abre calendario y no permite edición manual',(tester)async{
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:EditForm(initial:const {},fields:const [FieldSpec('starts_at','Fecha',dateTime:true)],save:(v)async{}))));
  expect(tester.widget<TextField>(find.byType(TextField)).readOnly,isTrue);
  await tester.tap(find.byIcon(Icons.calendar_month));await tester.pumpAndSettle();
  expect(find.byType(DatePickerDialog),findsOneWidget);
 });
}
