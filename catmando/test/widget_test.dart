import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:catmando/main.dart';

void main() {
  testWidgets('Cat Tower app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const CatTowerApp());
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
