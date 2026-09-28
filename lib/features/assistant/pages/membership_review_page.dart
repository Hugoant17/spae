import 'package:flutter/material.dart';
import '../../../core/live/business_pages.dart';

class MembershipReviewPage extends StatelessWidget {
 const MembershipReviewPage({super.key,this.id});
 final String? id;
 @override Widget build(BuildContext context)=>BusinessList(scope:'membership_payments',title:'Validación de membresía',role:'assistant',id:id);
}
