class ListingDraft {
  static const categories = [
    'หนังสือเรียน',
    'อุปกรณ์อิเล็กทรอนิกส์',
    'ของแต่งหอพัก',
    'เสื้อผ้า',
    'อื่นๆ',
  ];
  final String title;
  final String category;
  final String description;
  const ListingDraft({
    required this.title,
    required this.category,
    required this.description,
  });

  factory ListingDraft.fromJson(Map<String, dynamic> json) {
    for (final key in ['title', 'category', 'description']) {
      if (json[key] is! String || (json[key] as String).trim().isEmpty) {
        throw const FormatException('ข้อมูลร่างประกาศไม่ครบถ้วน');
      }
    }
    if (!categories.contains(json['category'])) {
      throw const FormatException('หมวดหมู่ไม่ถูกต้อง');
    }
    return ListingDraft(
      title: json['title'].trim(),
      category: json['category'].trim(),
      description: json['description'].trim(),
    );
  }
}
