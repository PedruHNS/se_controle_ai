import 'package:flutter_test/flutter_test.dart';
import 'package:se_controle_ai/app.dart';

import 'package:se_controle_ai/features/home/view/home_page.dart';

import 'fixtures/test_injector.dart';

void main() {
  setUp(setupTestInjector);

  testWidgets('o app sobe e cai na home', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.byType(HomePage), findsOneWidget);
  });
}
