import 'package:flutter/material.dart';
import '../../../core/live/public_pages.dart';

class EnrollmentConfirmationPage extends StatelessWidget {
 const EnrollmentConfirmationPage({super.key,this.receipt});
 final Map<String,dynamic>? receipt;
 @override Widget build(BuildContext context)=>ConfirmationView(receipt:receipt);
}
