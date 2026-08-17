import 'package:flutter_test/flutter_test.dart';

import 'package:basic_flutter_hot_updates_example/main.dart';

void main() {
  testWidgets('example app renders headline', (WidgetTester tester) async {
    await tester.pumpWidget(const HotUpdatesExampleApp());
    await tester.pump();

    expect(find.textContaining('Welcome to flutter_hot_updates'), findsOneWidget);
    expect(find.text('Check and apply update'), findsOneWidget);
  });
}
