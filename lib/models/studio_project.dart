class StudioProject {
  const StudioProject({
    required this.id,
    required this.name,
    required this.surahName,
    required this.createdAt,
    this.verseStart = 1,
    this.verseEnd = 7,
    this.aspectRatio = '9:16',
    this.background = 'Midnight',
    this.quranFilePath,
    this.audioPath,
    this.ayahTimings = const [],
    this.quranFontStyle = 'العثماني الكلاسيكي',
    this.reciterFontStyle = 'خط النسخ (أميري)',
    this.surahFontStyle = 'خط حفص',
    this.translationFontStyle = 'الخط الافتراضي',
    this.customFontPath,
    this.quranCustomFontPath,
    this.surahCustomFontPath,
    this.markerCustomFontPath,
    this.quranFontSize = 23,
    this.surahFontSize = 18,
    this.markerFontSize = 20,
    this.quranTextColor = 0xFFFFF5E3,
    this.surahTextColor = 0xFFEEDDBB,
    this.markerTextColor = 0xFFE8C47D,
  });

  final String id;
  final String name;
  final String surahName;
  final String createdAt;
  final int verseStart;
  final int verseEnd;
  final String aspectRatio;
  final String background;
  final String? quranFilePath;
  final String? audioPath;
  final List<AyahTiming> ayahTimings;
  final String quranFontStyle;
  final String reciterFontStyle;
  final String surahFontStyle;
  final String translationFontStyle;
  final String? customFontPath;
  final String? quranCustomFontPath;
  final String? surahCustomFontPath;
  final String? markerCustomFontPath;
  final double quranFontSize;
  final double surahFontSize;
  final double markerFontSize;
  final int quranTextColor;
  final int surahTextColor;
  final int markerTextColor;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'surahName': surahName,
        'createdAt': createdAt,
        'verseStart': verseStart,
        'verseEnd': verseEnd,
        'aspectRatio': aspectRatio,
        'background': background,
        'quranFilePath': quranFilePath,
        'audioPath': audioPath,
        'ayahTimings': ayahTimings.map((item) => item.toJson()).toList(),
        'quranFontStyle': quranFontStyle,
        'reciterFontStyle': reciterFontStyle,
        'surahFontStyle': surahFontStyle,
        'translationFontStyle': translationFontStyle,
        'customFontPath': customFontPath,
        'quranCustomFontPath': quranCustomFontPath,
        'surahCustomFontPath': surahCustomFontPath,
        'markerCustomFontPath': markerCustomFontPath,
        'quranFontSize': quranFontSize,
        'surahFontSize': surahFontSize,
        'markerFontSize': markerFontSize,
        'quranTextColor': quranTextColor,
        'surahTextColor': surahTextColor,
        'markerTextColor': markerTextColor,
      };

  factory StudioProject.fromJson(Map<String, dynamic> json) {
    return StudioProject(
      id: json['id'] as String,
      name: json['name'] as String,
      surahName: json['surahName'] as String,
      createdAt: json['createdAt'] as String,
      verseStart: json['verseStart'] as int? ?? 1,
      verseEnd: json['verseEnd'] as int? ?? 7,
      aspectRatio: json['aspectRatio'] as String? ?? '9:16',
      background: json['background'] as String? ?? 'Midnight',
      quranFilePath: json['quranFilePath'] as String?,
      audioPath: json['audioPath'] as String?,
      quranFontStyle: json['quranFontStyle'] as String? ?? 'العثماني الكلاسيكي',
      reciterFontStyle: json['reciterFontStyle'] as String? ?? 'خط النسخ (أميري)',
      surahFontStyle: json['surahFontStyle'] as String? ?? 'خط حفص',
      translationFontStyle: json['translationFontStyle'] as String? ?? 'الخط الافتراضي',
      customFontPath: json['customFontPath'] as String?,
      quranCustomFontPath: json['quranCustomFontPath'] as String?,
      surahCustomFontPath: json['surahCustomFontPath'] as String?,
      markerCustomFontPath: json['markerCustomFontPath'] as String?,
      quranFontSize: (json['quranFontSize'] as num?)?.toDouble() ?? 23,
      surahFontSize: (json['surahFontSize'] as num?)?.toDouble() ?? 18,
      markerFontSize: (json['markerFontSize'] as num?)?.toDouble() ?? 20,
      quranTextColor: json['quranTextColor'] as int? ?? 0xFFFFF5E3,
      surahTextColor: json['surahTextColor'] as int? ?? 0xFFEEDDBB,
      markerTextColor: json['markerTextColor'] as int? ?? 0xFFE8C47D,
      ayahTimings: (json['ayahTimings'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((item) => AyahTiming.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }

  StudioProject copyWith({
    String? name,
    String? surahName,
    int? verseStart,
    int? verseEnd,
    String? aspectRatio,
    String? background,
    String? quranFilePath,
    String? audioPath,
    bool clearQuranFile = false,
    bool clearAudio = false,
    List<AyahTiming>? ayahTimings,
    String? quranFontStyle,
    String? reciterFontStyle,
    String? surahFontStyle,
    String? translationFontStyle,
    String? customFontPath,
    bool clearCustomFont = false,
    String? quranCustomFontPath,
    String? surahCustomFontPath,
    String? markerCustomFontPath,
    double? quranFontSize,
    double? surahFontSize,
    double? markerFontSize,
    int? quranTextColor,
    int? surahTextColor,
    int? markerTextColor,
  }) {
    return StudioProject(
      id: id,
      name: name ?? this.name,
      surahName: surahName ?? this.surahName,
      createdAt: createdAt,
      verseStart: verseStart ?? this.verseStart,
      verseEnd: verseEnd ?? this.verseEnd,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      background: background ?? this.background,
      quranFilePath: clearQuranFile ? null : (quranFilePath ?? this.quranFilePath),
      audioPath: clearAudio ? null : (audioPath ?? this.audioPath),
      ayahTimings: ayahTimings ?? this.ayahTimings,
      quranFontStyle: quranFontStyle ?? this.quranFontStyle,
      reciterFontStyle: reciterFontStyle ?? this.reciterFontStyle,
      surahFontStyle: surahFontStyle ?? this.surahFontStyle,
      translationFontStyle: translationFontStyle ?? this.translationFontStyle,
      customFontPath: clearCustomFont ? null : (customFontPath ?? this.customFontPath),
      quranCustomFontPath: quranCustomFontPath ?? this.quranCustomFontPath,
      surahCustomFontPath: surahCustomFontPath ?? this.surahCustomFontPath,
      markerCustomFontPath: markerCustomFontPath ?? this.markerCustomFontPath,
      quranFontSize: quranFontSize ?? this.quranFontSize,
      surahFontSize: surahFontSize ?? this.surahFontSize,
      markerFontSize: markerFontSize ?? this.markerFontSize,
      quranTextColor: quranTextColor ?? this.quranTextColor,
      surahTextColor: surahTextColor ?? this.surahTextColor,
      markerTextColor: markerTextColor ?? this.markerTextColor,
    );
  }
}

/// Manual timing for one ayah, measured from the beginning of the audio file.
class AyahTiming {
  const AyahTiming({required this.ayah, required this.startMs, this.endMs});

  final int ayah;
  final int startMs;
  final int? endMs;

  Map<String, Object?> toJson() => {
        'ayah': ayah,
        'startMs': startMs,
        'endMs': endMs,
      };

  factory AyahTiming.fromJson(Map<String, dynamic> json) => AyahTiming(
        ayah: json['ayah'] as int,
        startMs: json['startMs'] as int,
        endMs: json['endMs'] as int?,
      );
}
