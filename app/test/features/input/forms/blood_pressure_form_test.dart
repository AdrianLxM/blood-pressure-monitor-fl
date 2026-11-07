import 'package:blood_pressure_app/features/input/forms/blood_pressure_form.dart';
import 'package:blood_pressure_app/l10n/app_localizations.dart';
import 'package:blood_pressure_app/model/blood_pressure/pressure_unit.dart';
import 'package:blood_pressure_app/model/storage/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_data_store/health_data_store.dart';

import '../../../util.dart';

void main() {
  testWidgets('saves entered values', (WidgetTester tester) async {
    final key = GlobalKey<BloodPressureFormState>();
    await tester.pumpWidget(materialApp(BloodPressureForm(key: key)));
    await tester.pumpAndSettle();
    final localizations = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.text(localizations.sysLong), findsOneWidget);
    expect(find.text(localizations.diaLong), findsOneWidget);
    expect(find.text(localizations.pulLong), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(3));
    expect(key.currentState?.validate(), true);

    await tester.enterText(find.ancestor(of: find.text(localizations.sysLong), matching: find.byType(TextField)), '123');
    await tester.enterText(find.ancestor(of: find.text(localizations.diaLong), matching: find.byType(TextField)), '67');
    await tester.enterText(find.ancestor(of: find.text(localizations.pulLong), matching: find.byType(TextField)), '89');

    expect(key.currentState?.validate(), true);
    expect(key.currentState?.save(), (sys: Pressure.mmHg(123), dia: Pressure.mmHg(67), pul: 89));
  });

  testWidgets('shows errors on bad inputs', (WidgetTester tester) async {
    final key = GlobalKey<BloodPressureFormState>();
    await tester.pumpWidget(materialApp(BloodPressureForm(key: key)));
    final localizations = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.text(localizations.errNaN), findsNothing);

    await tester.enterText(find.byType(TextField).first, '..,..');
    await tester.pump();
    expect(find.text('..,..'), findsNothing);

    expect(find.text(localizations.errNaN), findsNothing);
    expect(find.text(localizations.errLt30), findsNothing);

    await tester.enterText(find.byType(TextField).first, '13');
    await tester.pump();
    expect(key.currentState!.validate(), isFalse);
    await tester.pumpAndSettle();

    expect(find.text(localizations.errLt30), findsOneWidget);
    expect(find.text(localizations.errUnrealistic), findsNothing);

    await tester.enterText(find.byType(TextField).first, '500');
    await tester.pump();
    expect(key.currentState!.validate(), isFalse);
    await tester.pumpAndSettle();

    expect(find.text(localizations.errLt30), findsNothing);
    expect(find.text(localizations.errUnrealistic), findsOneWidget);

    await tester.enterText(find.ancestor(of: find.text(localizations.sysLong), matching: find.byType(TextField)), '123');
    await tester.enterText(find.ancestor(of: find.text(localizations.diaLong), matching: find.byType(TextField)), '67');
    await tester.enterText(find.ancestor(of: find.text(localizations.pulLong), matching: find.byType(TextField)), '');
    await tester.pump();
    expect(key.currentState!.validate(), isFalse);
    await tester.pumpAndSettle();

    expect(find.text(localizations.errUnrealistic), findsNothing);
    expect(find.text(localizations.errNaN), findsOneWidget, reason: 'pul is null');

    await tester.enterText(find.ancestor(of: find.text(localizations.sysLong), matching: find.byType(TextField)), '90');
    await tester.enterText(find.ancestor(of: find.text(localizations.diaLong), matching: find.byType(TextField)), '130');
    await tester.enterText(find.ancestor(of: find.text(localizations.pulLong), matching: find.byType(TextField)), '89');
    await tester.pump();
    expect(key.currentState!.validate(), isFalse);
    await tester.pumpAndSettle();

    expect(find.text(localizations.errUnrealistic), findsNothing);
    expect(find.text(localizations.errDiaGtSys), findsOneWidget);
  });

  testWidgets('loads initial values', (WidgetTester tester) async {
    await tester.pumpWidget(materialApp(BloodPressureForm(
      initialValue: (sys: Pressure.mmHg(123), dia: Pressure.mmHg(67), pul: 89),
    )));
    await tester.pumpAndSettle();
    expect(find.text('123'), findsOneWidget);
    expect(find.text('67'), findsOneWidget);
    expect(find.text('89'), findsOneWidget);
  });

  testWidgets('saves and validates kPa values', (WidgetTester tester) async {
    final key = GlobalKey<BloodPressureFormState>();
    await tester.pumpWidget(materialApp(BloodPressureForm(key: key),
      settings: Settings(preferredPressureUnit: PressureUnit.kPa),
    ));
    final localizations = await AppLocalizations.delegate.load(const Locale('en'));
    final sys = find.ancestor(of: find.text(localizations.sysLong), matching: find.byType(TextField));
    final dia = find.ancestor(of: find.text(localizations.diaLong), matching: find.byType(TextField));
    final pul = find.ancestor(of: find.text(localizations.pulLong), matching: find.byType(TextField));

    await tester.enterText(sys, '16.4');
    await tester.enterText(dia, '10,5');
    await tester.enterText(pul, '89');
    expect(key.currentState?.validate(), true);
    expect(key.currentState?.save(), (sys: Pressure.kPa(16.4), dia: Pressure.kPa(10.5), pul: 89));

    await tester.enterText(sys, '3.9'); // ~29 mmHg
    expect(key.currentState?.validate(), false);
    await tester.enterText(sys, '60'); // ~450 mmHg
    expect(key.currentState?.validate(), false);
  });

  testWidgets('loads kPa values and keeps them when unchanged', (WidgetTester tester) async {
    final key = GlobalKey<BloodPressureFormState>();
    final value = (sys: Pressure.mmHg(123), dia: Pressure.kPa(10.04), pul: 89);
    await tester.pumpWidget(materialApp(BloodPressureForm(key: key, initialValue: value),
      settings: Settings(preferredPressureUnit: PressureUnit.kPa),
    ));
    await tester.pumpAndSettle();
    expect(find.text('16.4'), findsOneWidget);
    expect(find.text('10.0'), findsOneWidget);
    expect(key.currentState?.save(), value);
  });
}
