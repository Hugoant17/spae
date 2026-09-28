import 'package:flutter/material.dart';
import '../../../core/live/business_pages.dart';

class EnrollmentReviewPage extends StatelessWidget {
 const EnrollmentReviewPage({super.key,this.id});
 final String? id;
 @override Widget build(BuildContext context)=>BusinessList(scope:'enrollments',title:'Validación de inscripción',role:'assistant',id:id);
}
