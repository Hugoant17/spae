import 'package:flutter/material.dart';
import '../../../core/live/public_pages.dart';

class TrainingDetailPage extends StatelessWidget {
 const TrainingDetailPage({super.key,this.id});
 final String? id;
 @override Widget build(BuildContext context)=>TrainingDetailView(id:id!);
}
