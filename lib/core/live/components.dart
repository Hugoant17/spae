import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api.dart';

class LoadData extends StatefulWidget {
 const LoadData({super.key,required this.load,required this.builder});
 final Future<dynamic> Function() load;
 final Widget Function(BuildContext,dynamic,VoidCallback) builder;
 @override State<LoadData> createState()=>_LoadDataState();
}
class _LoadDataState extends State<LoadData>{
 late Future<dynamic> future;
 @override void initState(){super.initState();future=widget.load();}
 void reload(){if(!mounted)return;setState((){future=widget.load();});}
 @override Widget build(BuildContext context)=>FutureBuilder<dynamic>(future:future,builder:(context,s){
  if(s.connectionState!=ConnectionState.done)return const Padding(padding:EdgeInsets.all(40),child:Center(child:CircularProgressIndicator()));
  if(s.hasError)return Card(child:Padding(padding:const EdgeInsets.all(24),child:Column(children:[Text('No se pudieron cargar los datos.\n${s.error}'),const SizedBox(height:12),OutlinedButton(onPressed:reload,child:const Text('Reintentar'))])));
  return widget.builder(context,s.data,reload);
 });
}
class ActionButton extends StatefulWidget {
 const ActionButton({super.key,required this.label,required this.run,this.icon=Icons.check,this.confirm=false,this.confirmationMessage});
 final String label; final Future<void> Function() run;final IconData icon;final bool confirm;final String? confirmationMessage;
 @override State<ActionButton> createState()=>_ActionButtonState();
}
class _ActionButtonState extends State<ActionButton>{
 bool busy=false,confirming=false;
 @override Widget build(BuildContext context)=>OutlinedButton.icon(onPressed:busy||confirming?null:()async{
  if(!mounted||busy||confirming)return;
  if(widget.confirm){
   setState(()=>confirming=true);
   bool? ok;
   try{ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:Text(widget.label),content:Text(widget.confirmationMessage??'¿Confirmas esta operación?'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Confirmar'))]));}
   finally{if(mounted)setState(()=>confirming=false);}
   if(ok!=true||!mounted)return;
  }
  setState(()=>busy=true);
  try{await widget.run();}catch(e){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e'),duration:const Duration(seconds:8)));}
  finally{if(mounted)setState(()=>busy=false);}
 },icon:busy?const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2)):Icon(widget.icon,size:18),label:Text(widget.label));
}
Future<String?> askText(BuildContext context,String title) async {
 final input=TextEditingController();
 final result=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(title:Text(title),content:TextField(controller:input,maxLines:3),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancelar')),FilledButton(onPressed:(){if(input.text.trim().length>=3)Navigator.pop(ctx,input.text.trim());},child:const Text('Aceptar'))]));
 // El controlador se libera una vez termina la transición del diálogo.
 Future.delayed(const Duration(milliseconds:400),input.dispose);return result;
}
class Records extends StatefulWidget {
 const Records({super.key,required this.rows,required this.columns,this.actions,this.export,this.bulk});
 final List<RowData> rows;final Map<String,String> columns;
 final Widget Function(RowData)? actions;
 final Future<void> Function(List<RowData>)? export;
 final Future<void> Function(List<RowData>)? bulk;
 @override State<Records> createState()=>_RecordsState();
}
class _RecordsState extends State<Records>{
 String search='',status='',training='';int page=0;
 final ScrollController horizontal=ScrollController();
 @override void dispose(){horizontal.dispose();super.dispose();}
 Widget value(String key,dynamic raw){
  final text=display(raw);
  if(key!='status'&&key!='payment_status'&&key!='effective_status')return Text(text,maxLines:3,overflow:TextOverflow.ellipsis);
  final color=raw=='approved'||raw=='active'?Colors.green:raw=='rejected'||raw=='expired'||raw=='cancelled'?Colors.red:Colors.amber.shade800;
  return Row(mainAxisSize:MainAxisSize.min,children:[Icon(Icons.circle,size:12,color:color),const SizedBox(width:7),Flexible(child:Text(text,maxLines:2,overflow:TextOverflow.ellipsis))]);
 }
 @override Widget build(BuildContext context){
 final statuses=widget.rows.map((r)=>r['effective_status']??r['status']).where((x)=>x!=null).map((x)=>x.toString()).toSet().toList()..sort();
 final trainings=widget.rows.map((r)=>r['training']).where((x)=>x!=null).map((x)=>x.toString()).toSet().toList()..sort();
 final filtered=widget.rows.where((r)=>(status.isEmpty||display(r['effective_status']??r['status'])==status)&&(training.isEmpty||r['training']==training)&&widget.columns.keys.map((k)=>display(r[k])).join(' ').toLowerCase().contains(search.toLowerCase())).toList();
 final pages=(filtered.length/15).ceil().clamp(1,999999).toInt();if(page>=pages)page=pages-1;
 return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
 Wrap(spacing:12,runSpacing:12,children:[SizedBox(width:280,child:TextField(decoration:const InputDecoration(labelText:'Buscar',prefixIcon:Icon(Icons.search)),onChanged:(v)=>setState((){search=v;page=0;}))),
 if(statuses.isNotEmpty)SizedBox(width:200,child:DropdownButtonFormField<String>(initialValue:status,decoration:const InputDecoration(labelText:'Estado'),items:[const DropdownMenuItem(value:'',child:Text('Todos')),...statuses.map((s)=>DropdownMenuItem(value:display(s),child:Text(display(s))))],onChanged:(v)=>setState((){status=v??'';page=0;}))),
 if(trainings.isNotEmpty)SizedBox(width:300,child:DropdownButtonFormField<String>(isExpanded:true,initialValue:training,decoration:const InputDecoration(labelText:'Capacitación'),items:[const DropdownMenuItem(value:'',child:Text('Todas')),...trainings.map((s)=>DropdownMenuItem(value:s,child:Text(s,overflow:TextOverflow.ellipsis)))],onChanged:(v)=>setState((){training=v??'';page=0;})))]),
 const SizedBox(height:16),
 if(widget.bulk!=null)Align(alignment:Alignment.centerLeft,child:ActionButton(label:'Emitir certificados elegibles de esta selección',icon:Icons.verified,confirm:true,run:()=>widget.bulk!(filtered))),
 if(widget.export!=null)Align(alignment:Alignment.centerRight,child:ActionButton(label:'Exportar ${filtered.length} filas a Excel',icon:Icons.download,run:()=>widget.export!(filtered))),
 if(filtered.isEmpty)const Card(child:Padding(padding:EdgeInsets.all(32),child:Text('No hay registros para mostrar.')))
 else if(widget.actions!=null)...filtered.skip(page*15).take(15).map((r)=>Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
 Wrap(spacing:24,runSpacing:12,children:widget.columns.entries.map((e)=>SizedBox(width:230,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(e.value,style:Theme.of(context).textTheme.labelMedium),value(e.key,r[e.key])]))).toList()),
 const Divider(height:28),widget.actions!(r)]))))
 else Card(child:Scrollbar(controller:horizontal,thumbVisibility:true,trackVisibility:true,scrollbarOrientation:ScrollbarOrientation.bottom,child:SingleChildScrollView(controller:horizontal,scrollDirection:Axis.horizontal,child:Padding(padding:const EdgeInsets.only(bottom:12),child:DataTable(columns:widget.columns.values.map((v)=>DataColumn(label:Text(v))).toList(),rows:filtered.skip(page*15).take(15).map((r)=>DataRow(cells:widget.columns.keys.map((k)=>DataCell(ConstrainedBox(constraints:const BoxConstraints(maxWidth:260),child:value(k,r[k])))).toList())).toList()))))),
 Row(mainAxisAlignment:MainAxisAlignment.end,children:[Text('${filtered.length} registros · Página ${page+1} de $pages'),IconButton(onPressed:page>0?()=>setState(()=>page--):null,icon:const Icon(Icons.chevron_left)),IconButton(onPressed:page+1<pages?()=>setState(()=>page++):null,icon:const Icon(Icons.chevron_right))])]);
 }
}
class FieldSpec {
 const FieldSpec(this.key,this.label,{this.required=true,this.options,this.number=false,this.lines=1,this.secret=false,this.readOnly=false,this.dateTime=false,this.help});
 final String key,label;final bool required,number,secret,readOnly,dateTime;final String? help;final Map<String,String>? options;final int lines;
}
class EditForm extends StatefulWidget{
 const EditForm({super.key,required this.fields,required this.initial,required this.save,this.label='Guardar',this.extra});
 final List<FieldSpec> fields;final RowData initial;final Future<void> Function(RowData) save;final String label;final Widget? extra;
 @override State<EditForm> createState()=>_EditFormState();
}
class _EditFormState extends State<EditForm>{
 final key=GlobalKey<FormState>();late Map<String,TextEditingController> inputs;
 @override void initState(){super.initState();inputs={for(final f in widget.fields)f.key:TextEditingController(text:f.dateTime?editablePeruDateTime(widget.initial[f.key]):widget.initial[f.key]?.toString()??'')};}
 @override void dispose(){for(final c in inputs.values){c.dispose();}super.dispose();}
 Future<void> pickDate(FieldSpec f) async {
  final initial=DateTime.tryParse(inputs[f.key]!.text)??peruWallDateTime(widget.initial[f.key])??DateTime.now();
  final date=await showDatePicker(context:context,initialDate:initial,firstDate:DateTime(1900),lastDate:DateTime(2200),helpText:f.label);
  if(date==null||!mounted)return;
  final time=await showTimePicker(context:context,initialTime:TimeOfDay.fromDateTime(initial));
  if(time==null||!mounted)return;
  setState((){inputs[f.key]!.text='${date.year.toString().padLeft(4,'0')}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')} ${time.hour.toString().padLeft(2,'0')}:${time.minute.toString().padLeft(2,'0')}';});
 }
 String? validate(FieldSpec f,String? value){
  final v=(value??'').trim();
  if(f.required&&v.isEmpty)return 'Completa ${f.label.toLowerCase()}';
  if(v.isEmpty)return null;
  if(f.key=='dni'&&!RegExp(r'^\d{8}$').hasMatch(v))return 'El DNI debe tener exactamente 8 dígitos';
  if(f.key=='term'&&RegExp(r'^\d+$').hasMatch(v)&&v.length!=8)return 'El DNI debe tener exactamente 8 dígitos';
  if(f.key=='phone'&&!RegExp(r'^9\d{8}$').hasMatch(v))return 'El celular debe tener 9 dígitos y comenzar con 9';
  if(f.key.contains('email')&&!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v))return 'Ingresa un correo válido';
  if(f.key=='full_name'&&v.split(RegExp(r'\s+')).length<2)return 'Ingresa nombres y apellidos completos';
  if(f.key=='hospital'&&v.length<3)return 'Ingresa el nombre completo de la institución';
  if((f.key=='contact_facebook'||f.key=='contact_whatsapp')&&(!v.startsWith('https://')||Uri.tryParse(v)?.hasAuthority!=true))return 'Ingresa un enlace HTTPS válido';
  if(f.number&&num.tryParse(v.replaceAll(',','.'))==null)return 'Ingresa un número válido';
  if(f.dateTime&&DateTime.tryParse(v)==null)return 'Selecciona la fecha y hora en el calendario';
  return null;
 }
 Widget field(FieldSpec f){
  if(f.options!=null)return DropdownButtonFormField<String>(isExpanded:true,initialValue:f.options!.containsKey(inputs[f.key]!.text)?inputs[f.key]!.text:null,decoration:InputDecoration(labelText:f.label),items:f.options!.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),onChanged:f.readOnly?null:(v){inputs[f.key]!.text=v??'';},validator:(v)=>validate(f,v));
  final digits=f.key=='dni'?8:f.key=='phone'?9:f.key=='term'&&RegExp(r'^\d+$').hasMatch(inputs[f.key]!.text)?8:null;
  return TextFormField(controller:inputs[f.key],readOnly:f.readOnly||f.dateTime,onTap:f.dateTime&&!f.readOnly?()=>pickDate(f):null,onChanged:f.key=='term'?(_)=>setState((){}):null,obscureText:f.secret,maxLines:f.secret?1:f.lines,
   maxLength:digits,inputFormatters:digits==null?null:[FilteringTextInputFormatter.digitsOnly,LengthLimitingTextInputFormatter(digits)],
   keyboardType:digits!=null?TextInputType.number:f.number?const TextInputType.numberWithOptions(decimal:true):f.key.contains('email')?TextInputType.emailAddress:TextInputType.text,
   autovalidateMode:AutovalidateMode.onUserInteraction,
   decoration:InputDecoration(labelText:f.label,filled:f.readOnly,fillColor:f.readOnly?Colors.grey.shade200:null,helperText:f.readOnly?'Dato registrado en tu cuenta':f.dateTime?'Selecciona fecha y hora':null,
    suffixIcon:f.dateTime?IconButton(tooltip:'Abrir calendario',onPressed:f.readOnly?null:()=>pickDate(f),icon:const Icon(Icons.calendar_month)):f.help!=null?Tooltip(message:f.help!,triggerMode:TooltipTriggerMode.tap,child:const Icon(Icons.help_outline)):null),validator:(v)=>validate(f,v));
 }
 @override Widget build(BuildContext context)=>Card(child:Padding(padding:const EdgeInsets.all(24),child:Form(key:key,child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
 LayoutBuilder(builder:(context,c)=>Wrap(spacing:16,runSpacing:16,children:widget.fields.map((f)=>SizedBox(width:c.maxWidth>750?(c.maxWidth-16)/2:c.maxWidth,child:field(f))).toList())),
 if(widget.extra!=null)...[const SizedBox(height:20),widget.extra!],const SizedBox(height:20),Align(alignment:Alignment.centerRight,child:ActionButton(label:widget.label,run:()async{
 if(!key.currentState!.validate()){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Revisa los campos señalados antes de continuar.')));return;}
 await widget.save({...widget.initial,for(final f in widget.fields)f.key:f.number?num.tryParse(inputs[f.key]!.text.replaceAll(',','.')):inputs[f.key]!.text.trim()});
 }))]))));
}
