import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:campus_marketplace_w7/services/gemini_service.dart';
import 'package:campus_marketplace_w7/services/gemini_vision_service.dart';

http.Response answer(String text) => http.Response(
  jsonEncode({
    'candidates': [
      {
        'finishReason': 'STOP',
        'content': {
          'parts': [
            {'text': text},
          ],
        },
      },
    ],
  }),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  test('text request and UTF-8 response', () async {
    final service = GeminiService(
      apiKey: 'test',
      client: MockClient((r) async {
        expect(r.headers['x-goog-api-key'], 'test');
        expect(jsonDecode(r.body)['contents'][0]['parts'][0]['text'], 'hello');
        return answer('สวัสดี');
      }),
    );
    addTearDown(service.close);
    expect(await service.generateText('hello'), 'สวัสดี');
  });
  for (final body in [
    {
      'promptFeedback': {'blockReason': 'SAFETY'},
    },
    {'candidates': []},
    {
      'candidates': [
        {'finishReason': 'SAFETY'},
      ],
    },
    {
      'candidates': [
        {'finishReason': 'MAX_TOKENS'},
      ],
    },
    {
      'candidates': [
        {'content': {}},
      ],
    },
  ]) {
    test('reject response $body', () async {
      final service = GeminiService(
        apiKey: 'test',
        client: MockClient((_) async => http.Response(jsonEncode(body), 200)),
      );
      addTearDown(service.close);
      await expectLater(
        service.generateText('test'),
        throwsA(isA<GeminiException>()),
      );
    });
  }
  for (final status in [400, 403, 404, 429, 503]) {
    test('handles HTTP $status', () async {
      final service = GeminiService(
        apiKey: 'test',
        client: MockClient((_) async => http.Response('error', status)),
      );
      addTearDown(service.close);
      await expectLater(
        service.generateText('test'),
        throwsA(isA<GeminiException>()),
      );
    });
  }
  test('missing key prevents request', () async {
    final service = GeminiService(
      apiKey: '',
      client: MockClient((_) async => throw StateError('must not call')),
    );
    addTearDown(service.close);
    await expectLater(
      service.generateText('test'),
      throwsA(isA<GeminiException>()),
    );
  });
  test('timeout is handled', () async {
    final service = GeminiService(
      apiKey: 'test',
      timeout: const Duration(milliseconds: 1),
      client: MockClient((_) => Completer<http.Response>().future),
    );
    addTearDown(service.close);
    await expectLater(
      service.generateText('test'),
      throwsA(isA<GeminiException>()),
    );
  });
  test('vision sends image, schema and parses inner JSON', () async {
    final dir = await Directory.systemTemp.createTemp('lab7_test');
    addTearDown(() => dir.delete(recursive: true));
    final file = await File(
      '${dir.path}/product.jpg',
    ).writeAsBytes([255, 216, 255, 0]);
    final vision = GeminiVisionService(
      service: GeminiService(
        apiKey: 'test',
        client: MockClient((r) async {
          final body = jsonDecode(r.body);
          expect(
            body['contents'][0]['parts'][1]['inline_data']['mime_type'],
            'image/jpeg',
          );
          expect(
            base64Decode(
              body['contents'][0]['parts'][1]['inline_data']['data'],
            ),
            [255, 216, 255, 0],
          );
          expect(body['generationConfig']['responseSchema']['required'], [
            'title',
            'category',
            'description',
          ]);
          expect(body['safetySettings'], hasLength(6));
          return answer(
            jsonEncode({
              'title': 'หนังสือ',
              'category': 'หนังสือเรียน',
              'description': 'หนังสือมือสอง',
            }),
          );
        }),
      ),
    );
    addTearDown(vision.close);
    expect((await vision.analyzeProductImage(file, 'prompt')).title, 'หนังสือ');
  });

  test(
    'vision turns a structured safety refusal into a safety error',
    () async {
      final dir = await Directory.systemTemp.createTemp('lab7_refusal');
      addTearDown(() => dir.delete(recursive: true));
      final file = await File(
        '${dir.path}/product.jpg',
      ).writeAsBytes([255, 216, 255, 0]);
      final vision = GeminiVisionService(
        service: GeminiService(
          apiKey: 'test',
          client: MockClient(
            (_) async => answer(
              jsonEncode({
                'title': 'คำขอที่ไม่ปลอดภัย',
                'category': 'อื่นๆ',
                'description': 'ไม่สามารถให้คำแนะนำตามข้อกำหนดด้านความปลอดภัย',
              }),
            ),
          ),
        ),
      );
      addTearDown(vision.close);
      await expectLater(
        vision.analyzeProductImage(file, 'prompt'),
        throwsA(isA<GeminiException>()),
      );
    },
  );
}
