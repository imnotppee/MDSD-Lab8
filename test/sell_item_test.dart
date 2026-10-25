import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:campus_marketplace_w7/models/listing_draft.dart';
import 'package:campus_marketplace_w7/models/listing_model.dart';
import 'package:campus_marketplace_w7/screens/sell_item_page.dart';
import 'package:campus_marketplace_w7/services/gemini_vision_service.dart';

class FakeVision extends GeminiVisionService {
  @override
  Future<ListingDraft> analyzeProductImage(File image, String prompt) async =>
      const ListingDraft(
        title: 'ชื่อจาก AI',
        category: 'หนังสือเรียน',
        description: 'คำบรรยายจาก AI',
      );
}

void main() {
  testWidgets(
    'review edited values, confirm once, clear form and retain saved draft',
    (tester) async {
      final model = ListingModel();
      final vision = FakeVision();
      addTearDown(vision.close);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: model,
          child: MaterialApp(
            home: SellItemPage(
              service: vision,
              pickImage: () async => XFile('missing-test-image.jpg'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('เลือกรูปภาพสินค้า'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ให้ AI ช่วยแนะนำ'));
      await tester.pumpAndSettle();
      expect(model.drafts, isEmpty);
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'ชื่อที่ผู้ใช้แก้ไข',
      );
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('ยืนยันร่างประกาศ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ยืนยันร่างประกาศ'));
      await tester.pumpAndSettle();
      expect(model.drafts.single.title, 'ชื่อที่ผู้ใช้แก้ไข');
      expect(find.byType(TextFormField), findsNothing);
      expect(find.byType(Image), findsNothing);
      expect(find.text('บันทึกร่างประกาศเรียบร้อยแล้ว'), findsOneWidget);
    },
  );
}
