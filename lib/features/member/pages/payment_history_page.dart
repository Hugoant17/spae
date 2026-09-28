import 'package:flutter/material.dart';
import '../../../core/live/business_pages.dart';

class PaymentHistoryPage extends StatelessWidget {
 const PaymentHistoryPage({super.key});
 
 @override Widget build(BuildContext context)=>const BusinessList(scope:'membership_payments',title:'Mis pagos anuales',role:'member');
}
