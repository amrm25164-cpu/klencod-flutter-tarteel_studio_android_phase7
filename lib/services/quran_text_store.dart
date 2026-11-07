import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Imports a Tanzil-compatible plain-text file containing one ayah per line.
/// The app deliberately does not fabricate Quran text when no verified file exists.
class QuranTextStore {
  static const _pathKey = 'verified_quran_text_path_v1';

  static const surahNames = <String>[
    'الفاتحة','البقرة','آل عمران','النساء','المائدة','الأنعام','الأعراف','الأنفال',
    'التوبة','يونس','هود','يوسف','الرعد','إبراهيم','الحجر','النحل','الإسراء','الكهف',
    'مريم','طه','الأنبياء','الحج','المؤمنون','النور','الفرقان','الشعراء','النمل','القصص',
    'العنكبوت','الروم','لقمان','السجدة','الأحزاب','سبأ','فاطر','يس','الصافات','ص','الزمر',
    'غافر','فصلت','الشورى','الزخرف','الدخان','الجاثية','الأحقاف','محمد','الفتح','الحجرات',
    'ق','الذاريات','الطور','النجم','القمر','الرحمن','الواقعة','الحديد','المجادلة','الحشر',
    'الممتحنة','الصف','الجمعة','المنافقون','التغابن','الطلاق','التحريم','الملك','القلم',
    'الحاقة','المعارج','نوح','الجن','المزمل','المدثر','القيامة','الإنسان','المرسلات','النبأ',
    'النازعات','عبس','التكوير','الانفطار','المطففين','الانشقاق','البروج','الطارق','الأعلى',
    'الغاشية','الفجر','البلد','الشمس','الليل','الضحى','الشرح','التين','العلق','القدر',
    'البينة','الزلزلة','العاديات','القارعة','التكاثر','العصر','الهمزة','الفيل','قريش',
    'الماعون','الكوثر','الكافرون','النصر','المسد','الإخلاص','الفلق','الناس'
  ];

  static const ayahCounts = <int>[
    7,286,200,176,120,165,206,75,129,109,123,111,43,52,99,128,111,110,
    98,135,112,78,118,64,77,227,93,88,69,60,34,30,73,54,45,83,182,88,
    75,85,54,53,89,59,37,35,38,29,18,45,60,49,62,55,78,96,29,22,24,
    13,14,11,11,18,12,12,30,52,52,44,28,28,20,56,40,31,50,40,46,42,
    29,19,36,25,22,17,19,26,30,20,15,21,11,8,8,19,5,8,8,11,11,8,3,
    9,5,4,7,3,6,3,5,4,5,6
  ];

  Future<String?> getImportedPath() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_pathKey);
    if (path == null || !await File(path).exists()) return null;
    return path;
  }

  Future<int> importTanzilText() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['txt'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      throw const ImportCancelledException();
    }

    final picked = result.files.single;
    final bytes = picked.bytes ??
        (picked.path != null ? await File(picked.path!).readAsBytes() : null);
    if (bytes == null) throw const FormatException('تعذر قراءة الملف المختار.');

    // UTF-8 is required so Arabic characters remain intact.
    final text = utf8.decode(bytes, allowMalformed: false);
    final lines = text
        .replaceFirst('\uFEFF', '')
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('#'))
        .toList();

    final expected = ayahCounts.fold<int>(0, (a, b) => a + b);
    if (lines.length != expected) {
      throw FormatException(
        'عدد الأسطر ${lines.length} وليس $expected آية. اختر ملف Tanzil النصي البسيط: آية واحدة في كل سطر، دون عناوين إضافية.',
      );
    }

    // Store only after validation succeeds.
    final docs = await getApplicationDocumentsDirectory();
    final quranDir = Directory('${docs.path}/quran');
    if (!await quranDir.exists()) await quranDir.create(recursive: true);
    final destination = File('${quranDir.path}/quran_verified.txt');
    await destination.writeAsString(lines.join('\n'), encoding: utf8, flush: true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pathKey, destination.path);
    return lines.length;
  }

  Future<String?> readAyah({
    required String path,
    required int surahNumber,
    required int ayahNumber,
  }) async {
    if (surahNumber < 1 || surahNumber > 114) return null;
    final maxAyah = ayahCounts[surahNumber - 1];
    if (ayahNumber < 1 || ayahNumber > maxAyah) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    final lines = await file.readAsLines(encoding: utf8);
    var offset = 0;
    for (var i = 0; i < surahNumber - 1; i++) {
      offset += ayahCounts[i];
    }
    final index = offset + ayahNumber - 1;
    if (index >= lines.length) return null;
    return lines[index];
  }

  Future<List<String>> readRange({
    required String path,
    required int surahNumber,
    required int start,
    required int end,
  }) async {
    if (surahNumber < 1 || surahNumber > 114) return [];
    final maxAyah = ayahCounts[surahNumber - 1];
    if (start < 1 || end < start || end > maxAyah) return [];
    final file = File(path);
    if (!await file.exists()) return [];
    final lines = await file.readAsLines(encoding: utf8);
    var offset = 0;
    for (var i = 0; i < surahNumber - 1; i++) {
      offset += ayahCounts[i];
    }
    final from = offset + start - 1;
    final to = offset + end;
    if (to > lines.length) return [];
    return lines.sublist(from, to);
  }
}

class ImportCancelledException implements Exception {
  const ImportCancelledException();
}
