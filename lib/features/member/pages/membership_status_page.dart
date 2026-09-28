import 'package:flutter/material.dart';
import '../../../core/live/business_pages.dart';

class MembershipStatusPage extends StatelessWidget {
 const MembershipStatusPage({super.key});
 
 @override Widget build(BuildContext context)=>const BusinessList(scope:'memberships',title:'Estado y vigencia',role:'member');
}
