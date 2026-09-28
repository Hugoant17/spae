import 'package:flutter/material.dart';
import '../../../core/live/business_pages.dart';

class EnrollmentsPage extends StatelessWidget {
 const EnrollmentsPage({super.key});
 
 @override Widget build(BuildContext context)=>const BusinessList(scope:'enrollments',title:'Inscripciones',role:'assistant');
}
