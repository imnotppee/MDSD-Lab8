import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class GeminiException implements Exception {
  final String message;
  const GeminiException(this.message);
  @override
  String toString() => message;
}

class GeminiService {
  final http.Client _client;
  final String apiKey;
  final String model;
  final Duration timeout;
  GeminiService({
    http.Client? client,
    this.apiKey = const String.fromEnvironment('GEMINI_API_KEY'),
    this.model = const String.fromEnvironment(
      'GEMINI_MODEL',
      defaultValue: 'gemini-3.8-flash',
    ),
    this.timeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client();

  Future<String> generateText(String prompt) => generate([
    {'text': prompt},
  ]);

  Future<String> generate(
    List<Map<String, dynamic>> parts, {
    Map<String, dynamic>? schema,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw const GeminiException(
        'ยังไม่ได้ตั้งค่า GEMINI_API_KEY ผ่าน --dart-define',
      );
    }
    try {
      final response = await _client
          .post(
            Uri.https(
              'generativelanguage.googleapis.com',
              '/v1beta/models/$model:generateContent',
            ),
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': apiKey,
            },
            body: jsonEncode({
              'contents': [
                {'role': 'user', 'parts': parts},
              ],
              // Gemini 3 models use permissive defaults. Request the strictest
              // available filter level for each adjustable harm category.
              'safetySettings': [
                for (final category in [
                  'HARM_CATEGORY_HARASSMENT',
                  'HARM_CATEGORY_HATE_SPEECH',
                  'HARM_CATEGORY_SEXUALLY_EXPLICIT',
                  'HARM_CATEGORY_DANGEROUS_CONTENT',
                  'HARM_CATEGORY_CIVIC_INTEGRITY',
                  'HARM_CATEGORY_JAILBREAK',
                ])
                  {'category': category, 'threshold': 'BLOCK_LOW_AND_ABOVE'},
              ],
              if (schema != null)
                'generationConfig': {
                  'responseMimeType': 'application/json',
                  'responseSchema': schema,
                },
            }),
          )
          .timeout(timeout);
      if (response.statusCode != 200) {
        String? apiMessage;
        try {
          final errorBody =
              jsonDecode(utf8.decode(response.bodyBytes))
                  as Map<String, dynamic>;
          apiMessage = errorBody['error']?['message'] as String?;
        } on FormatException {
          // Some intermediary errors are not JSON; use the local message below.
        } on TypeError {
          // The Gemini error envelope was not in its usual shape.
        }
        final localMessage = switch (response.statusCode) {
          400 => 'คำขอไม่ถูกต้อง',
          401 || 403 => 'API Key ไม่ถูกต้องหรือไม่มีสิทธิ์ใช้งาน',
          404 => 'ไม่พบโมเดล กรุณาตรวจสอบ GEMINI_MODEL',
          429 => 'เกินโควตาการใช้งาน กรุณารอสักครู่แล้วลองใหม่',
          503 => 'Gemini ไม่พร้อมใช้งานชั่วคราว กรุณาลองใหม่',
          _ => 'เซิร์ฟเวอร์ Gemini ตอบกลับผิดพลาด (${response.statusCode})',
        };
        debugPrint(
          'Gemini API error: HTTP ${response.statusCode}; ${apiMessage ?? localMessage}',
        );
        throw GeminiException(switch (response.statusCode) {
          _ =>
            apiMessage == null || apiMessage.trim().isEmpty
                ? localMessage
                : '$localMessage: ${apiMessage.trim()}',
        });
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (data['promptFeedback']?['blockReason'] != null) {
        throw const GeminiException(
          'คำขอถูกปฏิเสธตามนโยบายความปลอดภัยของ Gemini',
        );
      }
      final candidates = data['candidates'];
      if (candidates is! List || candidates.isEmpty) {
        throw const GeminiException(
          'AI ไม่สามารถวิเคราะห์ข้อมูลนี้ได้ ลองใช้ภาพหรือข้อความอื่น',
        );
      }
      final candidate = candidates.first as Map<String, dynamic>;
      final reason = candidate['finishReason'];
      if ([
        'SAFETY',
        'IMAGE_SAFETY',
        'PROHIBITED_CONTENT',
        'BLOCKLIST',
      ].contains(reason)) {
        throw const GeminiException(
          'เนื้อหาที่วิเคราะห์เข้าข่ายไม่ปลอดภัยตามนโยบายของ Gemini กรุณาใช้ภาพอื่น',
        );
      }
      if (reason != null && reason != 'STOP') {
        throw const GeminiException('AI ตอบกลับไม่สมบูรณ์ กรุณาลองใหม่');
      }
      final resultParts = candidate['content']?['parts'];
      if (resultParts is! List) throw const FormatException();
      final text = resultParts
          .whereType<Map<String, dynamic>>()
          .where((p) => p['thought'] != true)
          .map((p) => p['text'] is String ? p['text'] as String : '')
          .join()
          .trim();
      if (text.isEmpty) throw const FormatException();
      return text;
    } on TimeoutException {
      throw const GeminiException('การเชื่อมต่อหมดเวลา กรุณาลองใหม่อีกครั้ง');
    } on http.ClientException {
      throw const GeminiException('ไม่สามารถเชื่อมต่ออินเทอร์เน็ตได้');
    } on FormatException {
      throw const GeminiException('ข้อมูลที่ได้รับจาก Gemini ไม่ถูกต้อง');
    } on TypeError {
      throw const GeminiException(
        'โครงสร้างข้อมูลที่ได้รับจาก Gemini ไม่ถูกต้อง',
      );
    }
  }

  void close() => _client.close();
}
