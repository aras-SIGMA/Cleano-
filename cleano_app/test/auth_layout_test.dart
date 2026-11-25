import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cleano_app/screens/auth/login_screen.dart';
import 'package:cleano_app/screens/auth/register_screen.dart';
import 'package:cleano_app/screens/splash_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('welcome: di desktop kolom dibatasi 460 px dan berpusat', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    final loginButton = find.ancestor(of: find.text('Login'), matching: find.byType(ElevatedButton)).first;
    expect(tester.getSize(loginButton).width, 460);
    expect(tester.getCenter(find.text('Login')).dx, closeTo(720, 0.5));
  });

  testWidgets('welcome: di ponsel tombol memakai lebar penuh', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    final loginButton = find.ancestor(of: find.text('Login'), matching: find.byType(ElevatedButton)).first;
    // 390 - 2 * 28 padding = 334
    expect(tester.getSize(loginButton).width, 334);
  });

  testWidgets('login: di desktop form dibatasi 460 px dan berpusat', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pumpAndSettle();

    final emailField = tester.widget<TextFormField>(find.widgetWithText(TextFormField, 'Email'));
    expect(tester.getSize(find.byWidget(emailField)).width, 460);
    expect(tester.getCenter(find.text('Welcome Back')).dx, closeTo(720, 0.5));
  });

  testWidgets('register: di desktop form dibatasi 460 px dan berpusat', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
    await tester.pumpAndSettle();

    final nameField = tester.widget<TextFormField>(find.widgetWithText(TextFormField, 'Nama Lengkap'));
    expect(tester.getSize(find.byWidget(nameField)).width, 460);
    expect(tester.getCenter(find.text('Register')).dx, closeTo(720, 0.5));
  });
}
