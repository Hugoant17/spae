import 'package:flutter/material.dart';
import '../../../core/live/admin_pages.dart';

class TrainingFormPage extends StatelessWidget {
 const TrainingFormPage({super.key,this.id});
 final String? id;
 @override Widget build(BuildContext context)=>TrainingEditor(id:id);
}
