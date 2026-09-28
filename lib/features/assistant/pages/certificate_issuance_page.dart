import 'package:flutter/material.dart';
import '../../../core/live/business_pages.dart';

class CertificateIssuancePage extends StatelessWidget {
 const CertificateIssuancePage({super.key});
 
 @override Widget build(BuildContext context)=>const BusinessList(scope:'certificates',title:'Emisión de certificados',role:'assistant');
}
