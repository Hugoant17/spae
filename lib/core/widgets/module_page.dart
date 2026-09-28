import 'package:flutter/material.dart';

import 'metric_card.dart';
import 'page_frame.dart';
import 'responsive_grid.dart';
import 'status_badge.dart';

class ModuleMetric {
  const ModuleMetric(this.label, this.value, this.icon);
  final String label;
  final String value;
  final IconData icon;
}

class ModulePage extends StatelessWidget {
  const ModulePage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.navigation,
    this.metrics = const [],
    this.columns = const [],
    this.rows = const [],
    this.filters = const [],
    this.primaryAction,
    this.onPrimaryAction,
    this.extra,
  });
  final String title;
  final String subtitle;
  final List<NavItem> navigation;
  final List<ModuleMetric> metrics;
  final List<String> columns;
  final List<List<String>> rows;
  final List<String> filters;
  final String? primaryAction;
  final VoidCallback? onPrimaryAction;
  final Widget? extra;

  @override
  Widget build(BuildContext context) => PageFrame(
        title: title,
        subtitle: subtitle,
        items: navigation,
        actions: primaryAction == null ? const [] : [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton.icon(onPressed: onPrimaryAction, icon: const Icon(Icons.add), label: Text(primaryAction!)),
          ),
        ],
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (metrics.isNotEmpty) ...[
            ResponsiveGrid(children: metrics.map((m) => MetricCard(label: m.label, value: m.value, icon: m.icon)).toList()),
            const SizedBox(height: 24),
          ],
          if (filters.isNotEmpty) Card(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(spacing: 12, runSpacing: 12, children: [
              SizedBox(width: 260, child: TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar'))),
              ...filters.map((f) => SizedBox(width: 210, child: DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: f),
                items: const [DropdownMenuItem(value: 'all', child: Text('Todos'))],
                onChanged: (_) {},
              ))),
            ]),
          )),
          if (filters.isNotEmpty) const SizedBox(height: 20),
          if (columns.isNotEmpty) Card(child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: columns.map((c) => DataColumn(label: Text(c))).toList(),
              rows: rows.map((row) => DataRow(cells: List.generate(columns.length, (i) {
                final value = i < row.length ? row[i] : '';
                return DataCell(i == columns.length - 1 && _isStatus(value) ? StatusBadge(value) : Text(value));
              }))).toList(),
            ),
          )),
          if (extra != null) ...[const SizedBox(height: 24), extra!],
        ]),
      );

  bool _isStatus(String value) {
    final v = value.toLowerCase();
    return ['pendiente', 'aprobada', 'aprobado', 'rechazada', 'activo', 'activa', 'vencida', 'emitido'].contains(v);
  }
}

