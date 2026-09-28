import 'package:flutter/material.dart';
import '../../../core/live/business_pages.dart';

class MemberTrainingHistoryPage extends StatelessWidget {
 const MemberTrainingHistoryPage({super.key});
 
 @override Widget build(BuildContext context)=>const BusinessList(scope:'certificates',title:'Mis inscripciones',role:'member');
}
