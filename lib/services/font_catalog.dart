import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Names mirror the font-style choices exposed by Tarteel Studio's editor.
/// Actual typefaces are user-importable; generic fallbacks are used otherwise.
class FontCatalog {
  static final Map<String, String> _loadedFonts = {};
  static const quranFamily = 'TarteelQuranFont';
  static const surahFamily = 'TarteelSurahFont';
  static const markerFamily = 'TarteelMarkerFont';

  static String familyForPath(String? path, String rolePrefix) =>
      path == null ? rolePrefix : '${rolePrefix}_${path.hashCode.abs()}';
  static const quranStyles = <String>[
    'العثماني الكلاسيكي',
    'العثماني الحديث',
    'الخط المصري',
  ];

  static const reciterStyles = <String>[
    'خط الثلث',
    'الخط الديواني',
    'خط الرقعة',
    'خط شهرزاد (نسخ هادئ)',
    'خط النسخ (أميري)',
    'الخط الكوفي (ريم كوفي)',
    'خط التعليق / النستعليق',
    'خط رقاص (كاليغرافي عريض)',
    'خط كتيبة',
    'خط القاهرة (عصري بارز)',
    'خط تجوال (حديث أنيق)',
    'خط المصحف',
    'خط الأندلس',
  ];

  static const surahStyles = <String>['خط حفص', 'خط النسخ'];

  static const translationStyles = <String>[
    'الخط الافتراضي',
    'خط النسخ (أميري)',
    'نسخ نوتو',
    'القاهرة',
    'تجوال',
    'ريم كوفي',
  ];

  /// Imports a licensed TTF/OTF supplied by the user and keeps it offline.
  static Future<String?> importFont() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['ttf', 'otf'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return null;
    final file = picked.files.single;
    final bytes = file.bytes ?? (file.path == null ? null : await File(file.path!).readAsBytes());
    if (bytes == null || bytes.isEmpty) {
      throw const FormatException('تعذر قراءة ملف الخط.');
    }
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/fonts');
    await dir.create(recursive: true);
    final safe = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final target = File('${dir.path}/${DateTime.now().microsecondsSinceEpoch}_$safe');
    await target.writeAsBytes(bytes, flush: true);
    return target.path;
  }

  static Future<void> loadCustomFont(String? path, {String family = 'TarteelImportedFont'}) async {
    if (path == null || path.isEmpty || _loadedFonts[family] == path || !await File(path).exists()) return;
    final bytes = await File(path).readAsBytes();
    final loader = FontLoader(family)
      ..addFont(Future<ByteData>.value(ByteData.sublistView(Uint8List.fromList(bytes))));
    await loader.load();
    _loadedFonts[family] = path;
  }

  /// Generic Android fallbacks only. For exact matching, import the font file.
  static String familyFor(String style) {
    if (style.contains('كوفي') || style.contains('القاهرة') || style.contains('تجوال')) {
      return 'sans-serif';
    }
    if (style.contains('الافتراضي')) return 'sans-serif';
    return 'serif';
  }
}
