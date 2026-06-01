import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kelseyapp/main.dart';

void main() {
  testWidgets('Login screen shows branding and form', (WidgetTester tester) async {
    await tester.pumpWidget(const KelseyApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.text('welcome!'), findsOneWidget);
    expect(find.text('Log In'), findsWidgets);
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });
}
