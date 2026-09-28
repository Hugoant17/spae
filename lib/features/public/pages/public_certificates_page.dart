import 'package:flutter/material.dart';
import '../../../core/live/public_pages.dart';

class PublicCertificatesPage extends StatelessWidget {
 const PublicCertificatesPage({super.key});
 
 @override Widget build(BuildContext context)=>const PublicLookupView(certificates:true);
}
