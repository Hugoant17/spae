import 'package:flutter/material.dart';
import '../navigation/nav_items.dart';
import '../widgets/page_frame.dart';
import 'api.dart';
import 'components.dart';

class MemberRequestsView extends StatelessWidget {
 const MemberRequestsView({super.key});
 @override
 Widget build(BuildContext context)=>PageFrame(
  title:'Solicitudes de miembros',
  subtitle:'La aprobación de la cuenta es independiente del pago anual',
  items:AppNavigation.assistant,
  child:LoadData(
   load:()=>Api.client.rpc('spae_member_requests'),
   builder:(context,data,reload)=>Records(
    rows:Api.rows(data).map((r)=>{...r,'status':r['registration_status']}).toList(),
    columns:const {
     'full_name':'Nombres y apellidos',
     'dni':'DNI',
     'email':'Correo',
     'phone':'Celular',
     'status':'Solicitud',
     'enabled':'Cuenta habilitada',
     'registration_reason':'Observación',
    },
    actions:(r)=>Wrap(spacing:12,runSpacing:12,children:[
     if(r['status']=='pending')...[
      ActionButton(label:'Aprobar cuenta',confirm:true,run:()async{
       await Api.edge('review_member',{'id':r['id'],'status':'approved'});
       reload();
      }),
      ActionButton(label:'Rechazar cuenta',run:()async{
       final reason=await askText(context,'Motivo del rechazo');
       if(reason==null)return;
       await Api.edge('review_member',{'id':r['id'],'status':'rejected','reason':reason});
       reload();
      }),
     ],
     if(r['status']!='pending')ActionButton(
      label:r['enabled']==true?'Inactivar cuenta':'Activar cuenta',
      icon:r['enabled']==true?Icons.person_off_outlined:Icons.person_outline,
      confirm:true,
      run:()async{
       await Api.memberState(r['id'].toString(),r['enabled']!=true);
       reload();
      },
     ),
     ActionButton(label:'Eliminar miembro',icon:Icons.delete_outline,confirm:true,run:()async{
      await Api.edge('member_delete',{'id':r['id']});
      reload();
     }),
    ]),
   ),
  ),
 );
}
