import 'dart:convert';
import 'dart:io';
import '../models/listing_draft.dart';
import 'gemini_service.dart';

class GeminiVisionService {
  final GeminiService _service;
  GeminiVisionService({GeminiService? service})
    : _service = service ?? GeminiService();

  Future<ListingDraft> analyzeProductImage(File image, String prompt) async {
    try {
      final bytes = await image.readAsBytes();
      if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
        throw const GeminiException('กรุณาเลือกรูปภาพขนาดไม่เกิน 10 MB');
      }
      final String mime;
      if (bytes.length >= 3 &&
          bytes[0] == 255 &&
          bytes[1] == 216 &&
          bytes[2] == 255) {
        mime = 'image/jpeg';
      } else if (bytes.length >= 8 &&
          bytes[0] == 137 &&
          bytes[1] == 80 &&
          bytes[2] == 78 &&
          bytes[3] == 71) {
        mime = 'image/png';
      } else if (bytes.length >= 12 &&
          ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
          ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP') {
        mime = 'image/webp';
      } else {
        throw const GeminiException('กรุณาเลือกรูป JPEG, PNG หรือ WebP');
      }
      final text = await _service.generate(
        [
          {'text': prompt},
          {
            'inline_data': {'mime_type': mime, 'data': base64Encode(bytes)},
          },
        ],
        schema: {
          'type': 'OBJECT',
          'properties': {
            'title': {'type': 'STRING'},
            'category': {'type': 'STRING', 'enum': ListingDraft.categories},
            'description': {'type': 'STRING'},
          },
          'required': ['title', 'category', 'description'],
        },
      );
      final draft = ListingDraft.fromJson(
        jsonDecode(text) as Map<String, dynamic>,
      );
      if (_isSafetyRefusal(draft)) {
        throw const GeminiException(
          'เนื้อหาที่วิเคราะห์เข้าข่ายไม่ปลอดภัยตามนโยบายของ Gemini กรุณาใช้ภาพอื่น',
        );
      }
      return draft;
    } on FileSystemException {
      throw const GeminiException('ไม่สามารถอ่านรูปภาพได้ กรุณาเลือกใหม่');
    } on FormatException {
      throw const GeminiException(
        'AI ส่งร่างประกาศไม่ครบหรือ JSON ไม่ถูกต้อง กรุณาลองใหม่',
      );
    } on TypeError {
      throw const GeminiException('รูปแบบร่างประกาศไม่ถูกต้อง กรุณาลองใหม่');
    }
  }

  void close() => _service.close();

  /// Some Gemini models return a structured refusal rather than a SAFETY
  /// finish reason. Do not present that refusal as a product listing.
  bool _isSafetyRefusal(ListingDraft draft) {
    final value = '${draft.title} ${draft.description}'.toLowerCase();
    const refusalPhrases = [
      'ไม่สามารถให้คำแนะนำ',
      'ข้อกำหนดด้านความปลอดภัย',
      'ไม่อนุญาตให้',
      'cannot provide',
      'safety policy',
    ];
    return refusalPhrases.any(value.contains);
  }
}
