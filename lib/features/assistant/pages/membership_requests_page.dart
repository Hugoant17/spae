import 'package:flutter/material.dart';
import '../../../core/live/business_pages.dart';

class MembershipRequestsPage extends StatelessWidget {
 const MembershipRequestsPage({super.key});
 
 @override Widget build(BuildContext context)=>const BusinessList(scope:'membership_payments',title:'Solicitudes de membresía',role:'assistant');
}
