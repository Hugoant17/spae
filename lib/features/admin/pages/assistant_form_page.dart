import 'package:flutter/material.dart';
import '../../../core/live/admin_pages.dart';

class AssistantFormPage extends StatelessWidget {
 const AssistantFormPage({super.key,this.id});
 final String? id;
 @override Widget build(BuildContext context)=>AssistantEditor(id:id);
}
