import 'package:flutter/material.dart';
import '../../../core/live/business_pages.dart';

class ParticipantsPage extends StatelessWidget {
 const ParticipantsPage({super.key});
 
 @override Widget build(BuildContext context)=>const BusinessList(scope:'participants',title:'Participantes',role:'assistant');
}
