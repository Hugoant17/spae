import 'package:flutter/material.dart';

class FormFieldSpec {
  const FormFieldSpec(this.label, {this.icon = Icons.edit_outlined, this.lines = 1, this.keyboardType});
  final String label;
  final IconData icon;
  final int lines;
  final TextInputType? keyboardType;
}

class FormCard extends StatelessWidget {
  const FormCard({
    super.key,
    required this.fields,
    required this.submitLabel,
    this.onSubmit,
    this.footer,
  });
  final List<FormFieldSpec> fields;
  final String submitLabel;
  final VoidCallback? onSubmit;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            LayoutBuilder(builder: (context, constraints) {
              final wide = constraints.maxWidth >= 720;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: fields.map((f) => SizedBox(
                  width: wide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth,
                  child: TextFormField(
                    maxLines: f.lines,
                    keyboardType: f.keyboardType,
                    decoration: InputDecoration(labelText: f.label, prefixIcon: Icon(f.icon)),
                  ),
                )).toList(),
              );
            }),
            if (footer != null) ...[const SizedBox(height: 20), footer!],
            const SizedBox(height: 24),
            Align(alignment: Alignment.centerRight, child: FilledButton(onPressed: onSubmit, child: Text(submitLabel))),
          ]),
        ),
      );
}
