import 'package:flutter_test/flutter_test.dart';
import 'package:spae_capacitaciones/app.dart';

void main() {
  testWidgets('muestra la landing page de SPAE', (tester) async {
    await tester.pumpWidget(const SpaeApp());
    await tester.pumpAndSettle();
    expect(find.text('SPAE'), findsOneWidget);
    expect(find.textContaining('Capacitación especializada'), findsOneWidget);
  });
}
