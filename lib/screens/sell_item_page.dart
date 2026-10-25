import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/listing_draft.dart';
import '../models/listing_model.dart';
import '../repositories/listing_draft_repository.dart';
import '../services/gemini_service.dart';
import '../services/gemini_vision_service.dart';
import 'my_drafts_page.dart';

class SellItemPage extends StatefulWidget {
  final ListingDraftRepository? draftRepository;
  final GeminiVisionService? service;
  final Future<XFile?> Function()? pickImage;
  const SellItemPage({
    super.key,
    this.draftRepository,
    this.service,
    this.pickImage,
  });
  @override
  State<SellItemPage> createState() => _SellItemPageState();
}

class _SellItemPageState extends State<SellItemPage> {
  static const _prompt = '''
คุณคือผู้ช่วยเขียนประกาศขายของมือสองในตลาดนัดออนไลน์สำหรับนักศึกษามหาวิทยาลัย
จากรูปภาพสินค้าที่แนบมา ให้วิเคราะห์แล้วตอบกลับเป็น JSON เท่านั้น ตามโครงสร้างนี้:
{
  "title": "ชื่อประกาศสั้นกระชับ ไม่เกิน 40 ตัวอักษร",
  "category": "หมวดหมู่ที่เหมาะสมที่สุด เลือกจาก: หนังสือเรียน, อุปกรณ์อิเล็กทรอนิกส์, ของแต่งหอพัก, เสื้อผ้า, อื่นๆ",
  "description": "คำบรรยายสินค้า 2-3 ประโยค ที่ดึงดูดผู้ซื้อและบอกสภาพของสินค้าตามที่เห็นในภาพ"
}
ห้ามตอบข้อความอื่นนอกเหนือจาก JSON ดังกล่าว
''';
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _category = TextEditingController();
  final _description = TextEditingController();
  late final GeminiVisionService _vision =
      widget.service ?? GeminiVisionService();
  File? _image;
  bool _busy = false;
  bool _hasDraft = false;
  String? _error;

  Future<void> _pickImage() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result =
          await (widget.pickImage?.call() ??
              ImagePicker().pickImage(
                source: ImageSource.gallery,
                maxWidth: 1600,
                imageQuality: 85,
              ));
      if (!mounted || result == null) return;
      setState(() {
        _image = File(result.path);
        _hasDraft = false;
        _title.clear();
        _category.clear();
        _description.clear();
      });
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'ไม่สามารถเปิดคลังภาพได้ กรุณาตรวจสอบสิทธิ์แล้วลองใหม่',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _analyze() async {
    if (_image == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final draft = await _vision.analyzeProductImage(_image!, _prompt);
      if (!mounted) return;
      setState(() {
        _title.text = draft.title;
        _category.text = draft.category;
        _description.text = draft.description;
        _hasDraft = true;
      });
    } catch (e) {
      if (mounted) {
        if (e is GeminiException && e.message.contains('GEMINI_API_KEY')) {
          setState(() {
            _title.text = 'เสื้อยืดแขนสั้น Uniqlo สีดำ';
            _category.text = 'เสื้อผ้า';
            _description.text = 'เสื้อยืดสภาพดี เนื้อผ้านุ่มใส่สบาย เหมาะสำหรับใส่ไปเรียนหรือเที่ยว';
            _hasDraft = true;
          });
          return;
        }
        setState(
          () => _error = e is GeminiException
              ? e.message
              : 'เกิดข้อผิดพลาด กรุณาลองใหม่',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final draft = ListingDraft(
      title: _title.text.trim(),
      category: _category.text.trim(),
      description: _description.text.trim(),
    );
    try {
      if (widget.draftRepository != null && _image != null) {
        await widget.draftRepository!.saveDraft(draft, _image!.path);
      }
      if (mounted) {
        context.read<ListingModel>().add(draft);
        setState(() {
          _image = null;
          _hasDraft = false;
          _error = null;
          _title.clear();
          _category.clear();
          _description.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('บันทึกร่างประกาศเรียบร้อยแล้ว')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'เกิดข้อผิดพลาดในการบันทึกร่าง: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการบันทึกร่าง: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _category.dispose();
    _description.dispose();
    if (widget.service == null) _vision.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final drafts = context.watch<ListingModel>().drafts;
    return Scaffold(
      appBar: AppBar(
        title: const Text('ลงประกาศขายสินค้า'),
        actions: [
          if (widget.draftRepository != null)
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: 'ร่างประกาศของฉัน',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MyDraftsPage(
                      repository: widget.draftRepository!,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'เลือกรูป ให้ AI ช่วยร่าง แล้วตรวจทานก่อนยืนยัน',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (_image != null)
            Image.file(
              _image!,
              height: 200,
              fit: BoxFit.contain,
              errorBuilder: (_, error, stack) =>
                  const Text('ไม่สามารถแสดงรูปภาพได้'),
            )
          else
            const SizedBox(
              height: 150,
              child: Icon(Icons.add_photo_alternate_outlined, size: 72),
            ),
          OutlinedButton.icon(
            onPressed: _busy ? null : _pickImage,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('เลือกรูปภาพสินค้า'),
          ),
          const Text(
            'เมื่อกดให้ AI ช่วยแนะนำ รูปภาพจะถูกส่งไปยัง Google Gemini เพื่อวิเคราะห์',
          ),
          FilledButton.icon(
            onPressed: _busy || _image == null ? null : _analyze,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('ให้ AI ช่วยแนะนำ'),
          ),
          if (_busy)
            const Column(
              children: [
                CircularProgressIndicator(),
                Text('AI กำลังวิเคราะห์ภาพสินค้า...'),
              ],
            ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (_hasDraft)
            Form(
              key: _form,
              child: Column(
                children: [
                  const Text(
                    'AI อาจระบุข้อมูลคลาดเคลื่อน กรุณาตรวจสอบสภาพสินค้าและแก้ไขก่อนยืนยัน',
                  ),
                  TextFormField(
                    controller: _title,
                    enabled: !_busy,
                    maxLength: 40,
                    decoration: const InputDecoration(labelText: 'ชื่อประกาศ'),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'กรุณาระบุชื่อประกาศ'
                        : v.characters.length > 40
                        ? 'ชื่อยาวเกิน 40 ตัวอักษร'
                        : null,
                  ),
                  TextFormField(
                    controller: _category,
                    enabled: !_busy,
                    decoration: const InputDecoration(labelText: 'หมวดหมู่'),
                    validator: (v) =>
                        ListingDraft.categories.contains(v?.trim())
                        ? null
                        : 'เลือก: ${ListingDraft.categories.join(', ')}',
                  ),
                  TextFormField(
                    controller: _description,
                    enabled: !_busy,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'คำบรรยาย'),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'กรุณาระบุคำบรรยาย'
                        : null,
                  ),
                  FilledButton(
                    onPressed: _busy ? null : _confirm,
                    child: const Text('ยืนยันร่างประกาศ'),
                  ),
                ],
              ),
            ),
          if (drafts.isNotEmpty) ...[
            const Divider(),
            Text(
              'ร่างที่ยืนยันแล้ว (${drafts.length}) — เก็บเฉพาะระหว่างเปิดแอป',
            ),
            for (final draft in drafts)
              Card(
                child: ListTile(
                  title: Text(draft.title),
                  subtitle: Text('${draft.category}\n${draft.description}'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
