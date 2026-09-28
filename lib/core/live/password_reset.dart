import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'api.dart';
import '../config/supabase_config.dart';
import 'components.dart';
import '../widgets/page_frame.dart';
class PasswordResetPage extends StatelessWidget{
 const PasswordResetPage({super.key});
 @override Widget build(BuildContext context)=>PageFrame(title:'Recuperar contraseña',subtitle:'Solicita un correo o establece tu nueva contraseña después de abrir el enlace',publicHeader:true,child:Column(children:[
 EditForm(initial:const {},fields:const [FieldSpec('email','Correo electrónico')],label:'Enviar enlace',save:(v)async{await Api.client.auth.resetPasswordForEmail(v['email'],redirectTo:'${Uri.base.origin}/#/recuperar');if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Si el correo está registrado, recibirás un enlace.')));}),
 if(SupabaseConfig.isConfigured&&Api.client.auth.currentUser!=null)...[const SizedBox(height:20),EditForm(initial:const {},fields:const [FieldSpec('password','Nueva contraseña',secret:true),FieldSpec('confirm','Repetir contraseña',secret:true)],label:'Cambiar contraseña',save:(v)async{if(v['password'].length<10||v['password']!=v['confirm'])throw Exception('Usa al menos 10 caracteres y repite la misma contraseña.');await Api.client.auth.updateUser(UserAttributes(password:v['password']));await Api.client.auth.signOut();if(context.mounted)context.go('/miembro/login');})]
 ]));
}
