import 'package:flutter/material.dart';
import '../../../core/live/public_pages.dart';

class EnrollmentFormPage extends StatelessWidget {
 const EnrollmentFormPage({super.key,this.id});
 final String? id;
 @override Widget build(BuildContext context)=>PublicEnrollmentView(id:id!);
}
