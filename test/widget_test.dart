// This is a basic Flutter widget test.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chromodoro_flutter/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: ChromodoroApp()));
    expect(find.text('Projects'), findsOneWidget);
    // Unmount and advance the clock so drift/Riverpod dispose-time timers fire.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });
}