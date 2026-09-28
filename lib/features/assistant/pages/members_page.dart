import 'package:flutter/material.dart';
import '../../../core/live/business_pages.dart';

class MembersPage extends StatelessWidget {
 const MembersPage({super.key});
 
 @override Widget build(BuildContext context)=>const BusinessList(scope:'members',title:'Miembros',role:'assistant');
}
