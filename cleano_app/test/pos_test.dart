import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cleano_app/models/service_model.dart';
import 'package:cleano_app/models/user_model.dart';
import 'package:cleano_app/widgets/member_card.dart';
import 'package:cleano_app/widgets/service_dropdown.dart';
import 'package:cleano_app/widgets/weight_input.dart';

void main() {
  group('POS Widgets Test', () {
    testWidgets('MemberCard menampilkan nama, MBR code, tier, poin, dan WA tersensor', (tester) async {
      const user = UserModel(
        id: 2,
        name: 'Rina Marlina',
        email: 'rina@example.com',
        phone: '081234567890',
        role: 'pelanggan',
        memberCode: 'MBR-0001',
        points: 150,
        tier: 'Gold',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MemberCard(user: user),
          ),
        ),
      );

      expect(find.text('Rina Marlina'), findsOneWidget);
      expect(find.text('MBR-0001'), findsOneWidget);
      expect(find.text('GOLD'), findsOneWidget);
      expect(find.text('150 Poin'), findsOneWidget);
      expect(find.text('0812-****-7890'), findsOneWidget);
    });

    testWidgets('WeightInput menghitung subtotal dan tombol step menambah/mengurangi berat', (tester) async {
      final controller = TextEditingController(text: '3.0');
      double currentWeight = 3.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return WeightInput(
                  controller: controller,
                  weight: currentWeight,
                  pricePerKg: 7000,
                  onChanged: (val) {
                    setState(() => currentWeight = val);
                  },
                );
              },
            ),
          ),
        ),
      );

      // Subtotal 3.0 * 7000 = Rp 21.000
      expect(find.text('Subtotal: Rp 21.000'), findsOneWidget);

      // Tap tombol +0.5
      await tester.tap(find.text('+0.5'));
      await tester.pumpAndSettle();

      expect(controller.text, '3.5');
      expect(currentWeight, 3.5);
      expect(find.text('Subtotal: Rp 24.500'), findsOneWidget);
    });

    testWidgets('ServiceDropdown menampilkan daftar layanan dan harga per kg', (tester) async {
      const service1 = ServiceModel(
        id: 1,
        name: 'Cuci Komplit Reguler',
        pricePerKg: 7000,
        washDurationMinutes: 45,
        estimatedHours: 24,
        requiresMachine: true,
      );
      const service2 = ServiceModel(
        id: 2,
        name: 'Cuci Kilat Express',
        pricePerKg: 12000,
        washDurationMinutes: 30,
        estimatedHours: 6,
        requiresMachine: true,
      );

      ServiceModel? selected = service1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ServiceDropdown(
              services: const [service1, service2],
              selectedService: selected,
              onChanged: (val) => selected = val,
            ),
          ),
        ),
      );

      expect(find.text('Cuci Komplit Reguler'), findsOneWidget);
      expect(find.text('Rp 7.000'), findsOneWidget);
    });
  });
}
