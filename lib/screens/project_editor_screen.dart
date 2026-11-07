import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../models/studio_project.dart';
import '../services/audio_import_service.dart';
import '../services/project_store.dart';
import '../services/quran_text_store.dart';
import '../services/video_export_service.dart';
import '../services/font_catalog.dart';

class ProjectEditorScreen extends StatefulWidget {
  const ProjectEditorScreen({super.key, required this.project});
  final StudioProject project;

  @override
  State<ProjectEditorScreen> createState() => _ProjectEditorScreenState();
}

class _ProjectEditorScreenState extends State<ProjectEditorScreen> {
  late StudioProject _project;
  final ProjectStore _projectStore = ProjectStore();
  final QuranTextStore _quranStore = QuranTextStore();
  final AudioImportService _audioImport = AudioImportService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final VideoExportService _videoExporter = VideoExportService();

  String? _quranPath;
  List<String> _visibleAyat = [];
  bool _loadingQuran = false;
  bool _importingAudio = false;
  bool _exportingVideo = false;
  String? _audioError;
  int _timingAyah = 1;

  static const _surahs = QuranTextStore.surahNames;

  int get _surahNumber => _surahs.indexOf(_project.surahName) + 1;

  @override
  void initState() {
    super.initState();
    _project = widget.project;
    _quranPath = _project.quranFilePath;
    _loadSavedQuran();
    _loadCustomFontForPreview();
    if (_project.audioPath != null) {
      _setAudioSource(_project.audioPath!, showErrors: false);
    }
  }

  Future<void> _loadCustomFontForPreview() async {
    try {
      await FontCatalog.loadCustomFont(_project.quranCustomFontPath ?? _project.customFontPath, family: FontCatalog.familyForPath(_project.quranCustomFontPath ?? _project.customFontPath, FontCatalog.quranFamily));
      await FontCatalog.loadCustomFont(_project.surahCustomFontPath ?? _project.customFontPath, family: FontCatalog.familyForPath(_project.surahCustomFontPath ?? _project.customFontPath, FontCatalog.surahFamily));
      await FontCatalog.loadCustomFont(_project.markerCustomFontPath ?? _project.customFontPath, family: FontCatalog.familyForPath(_project.markerCustomFontPath ?? _project.customFontPath, FontCatalog.markerFamily));
      if (mounted) setState(() {});
    } catch (_) { /* Keep system fallback if a custom font cannot be loaded. */ }
  }

  Future<void> _loadSavedQuran() async {
    final path = _project.quranFilePath ?? await _quranStore.getImportedPath();
    if (!mounted) return;
    if (path != null && await File(path).exists()) {
      setState(() => _quranPath = path);
      await _loadAyat();
    }
  }

  Future<void> _update(StudioProject updated) async {
    setState(() => _project = updated);
    await _projectStore.saveProject(updated);
  }

  Future<void> _importQuran() async {
    setState(() => _loadingQuran = true);
    try {
      final count = await _quranStore.importTanzilText();
      final path = await _quranStore.getImportedPath();
      if (path == null) throw const FormatException('لم يتم العثور على الملف بعد استيراده.');
      await _update(_project.copyWith(quranFilePath: path));
      if (!mounted) return;
      setState(() => _quranPath = path);
      await _loadAyat();
      if (!mounted) return;
      _message('تم استيراد $count آية والتحقق من عدد الأسطر.');
    } on ImportCancelledException {
      // User closed the file picker; this is not an error.
    } catch (error) {
      _message('تعذر استيراد المصحف: $error');
    } finally {
      if (mounted) setState(() => _loadingQuran = false);
    }
  }

  Future<void> _loadAyat() async {
    final path = _quranPath;
    if (path == null) return;
    final max = QuranTextStore.ayahCounts[_surahNumber - 1];
    final start = _project.verseStart.clamp(1, max).toInt();
    final end = _project.verseEnd.clamp(start, max).toInt();
    final ayat = await _quranStore.readRange(
      path: path,
      surahNumber: _surahNumber,
      start: start,
      end: end,
    );
    if (mounted) setState(() => _visibleAyat = ayat);
  }

  Future<void> _importAudio() async {
    setState(() {
      _importingAudio = true;
      _audioError = null;
    });
    try {
      final path = await _audioImport.pickAndCopyAudio();
      if (path == null) return;
      await _audioPlayer.stop();
      await _update(_project.copyWith(audioPath: path));
      await _setAudioSource(path);
      if (mounted) _message('تم نسخ الملف الصوتي إلى مساحة التطبيق المحلية.');
    } catch (error) {
      if (mounted) setState(() => _audioError = error.toString());
    } finally {
      if (mounted) setState(() => _importingAudio = false);
    }
  }

  Future<void> _exportVideo() async {
    if (_exportingVideo) return;
    final quranPath = _quranPath;
    final audioPath = _project.audioPath;
    if (quranPath == null || audioPath == null) {
      _message('استورد نص القرآن وملف التلاوة أولًا.');
      return;
    }
    setState(() => _exportingVideo = true);
    try {
      await _audioPlayer.pause();
      await FontCatalog.loadCustomFont(_project.quranCustomFontPath ?? _project.customFontPath, family: FontCatalog.familyForPath(_project.quranCustomFontPath ?? _project.customFontPath, FontCatalog.quranFamily));
      await FontCatalog.loadCustomFont(_project.surahCustomFontPath ?? _project.customFontPath, family: FontCatalog.familyForPath(_project.surahCustomFontPath ?? _project.customFontPath, FontCatalog.surahFamily));
      await FontCatalog.loadCustomFont(_project.markerCustomFontPath ?? _project.customFontPath, family: FontCatalog.familyForPath(_project.markerCustomFontPath ?? _project.customFontPath, FontCatalog.markerFamily));
      final ayat = await _quranStore.readRange(
        path: quranPath,
        surahNumber: _surahNumber,
        start: _project.verseStart,
        end: _project.verseEnd,
      );
      final result = await _videoExporter.export(
        project: _project,
        ayat: ayat,
        audioPath: audioPath,
        outputName: _project.name,
      );
      if (mounted) {
        _message('تم إنشاء الفيديو (${result.ayahCount} آية): ${result.path}');
      }
    } catch (error) {
      if (mounted) _message('تعذر تصدير الفيديو: $error');
    } finally {
      if (mounted) setState(() => _exportingVideo = false);
    }
  }

  Future<void> _setAudioSource(String path, {bool showErrors = true}) async {
    try {
      if (!await File(path).exists()) {
        if (showErrors && mounted) _message('ملف الصوت غير موجود.');
        return;
      }
      await _audioPlayer.setFilePath(path);
      if (mounted) setState(() => _audioError = null);
    } catch (error) {
      if (mounted) {
        setState(() => _audioError = 'تعذر تشغيل الملف: $error');
      }
    }
  }

  Duration get _audioPosition => _audioPlayer.position;
  int get _activeTimingAyah =>
      _timingAyah.clamp(_project.verseStart, _project.verseEnd).toInt();

  AyahTiming? _timingFor(int ayah) {
    for (final timing in _project.ayahTimings) {
      if (timing.ayah == ayah) return timing;
    }
    return null;
  }

  Future<void> _saveAyahStart() async {
    final now = _audioPosition.inMilliseconds;
    final old = _timingFor(_activeTimingAyah);
    final timings = _project.ayahTimings
        .where((item) => item.ayah != _activeTimingAyah)
        .toList();
    timings.add(AyahTiming(
      ayah: _activeTimingAyah,
      startMs: now,
      endMs: old?.endMs != null && old!.endMs! > now ? old.endMs : null,
    ));
    timings.sort((a, b) => a.ayah.compareTo(b.ayah));
    await _update(_project.copyWith(ayahTimings: timings));
    _message('تم تسجيل بداية الآية عند ${_format(_audioPosition)}');
  }

  Future<void> _saveAyahEnd() async {
    final old = _timingFor(_activeTimingAyah);
    if (old == null) {
      _message('سجّل بداية الآية أولًا.');
      return;
    }
    final now = _audioPosition.inMilliseconds;
    if (now <= old.startMs) {
      _message('نهاية الآية يجب أن تأتي بعد بدايتها.');
      return;
    }
    final timings = _project.ayahTimings
        .where((item) => item.ayah != _activeTimingAyah)
        .toList()
      ..add(AyahTiming(ayah: _activeTimingAyah, startMs: old.startMs, endMs: now));
    timings.sort((a, b) => a.ayah.compareTo(b.ayah));
    await _update(_project.copyWith(ayahTimings: timings));
    _message('تم تسجيل نهاية الآية وحفظ التوقيت.');
  }

  Future<void> _seekToAyahStart() async {
    final timing = _timingFor(_activeTimingAyah);
    if (timing == null) {
      _message('لا يوجد توقيت محفوظ لهذه الآية.');
      return;
    }
    await _audioPlayer.seek(Duration(milliseconds: timing.startMs));
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxAyah = QuranTextStore.ayahCounts[_surahNumber - 1];
    return Scaffold(
      appBar: AppBar(
        title: Text(_project.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'حفظ',
            onPressed: () async {
              await _projectStore.saveProject(_project);
              _message('تم حفظ إعدادات المشروع على الهاتف.');
            },
            icon: const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          StreamBuilder<Duration>(
            stream: _audioPlayer.positionStream,
            initialData: _audioPlayer.position,
            builder: (context, snapshot) => _LiveVideoPreview(
              project: _project,
              ayat: _visibleAyat,
              positionMs: (snapshot.data ?? Duration.zero).inMilliseconds,
            ),
          ),
          const SizedBox(height: 22),
          const _SectionTitle('إعدادات القرآن'),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _loadingQuran ? null : _importQuran,
            icon: _loadingQuran
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.menu_book_outlined),
            label: Text(_quranPath == null
                ? 'استيراد نص المصحف الموثوق (TXT)'
                : 'استبدال ملف المصحف'),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 5, bottom: 12),
            child: Text(
              'اختر ملف Tanzil النصي البسيط بترميز UTF-8: آية واحدة في كل سطر (6236 سطرًا). لا يضع التطبيق نصًا قرآنيًا تجريبيًا بدل النص الموثق.',
              textDirection: TextDirection.rtl,
              style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.5),
            ),
          ),
          DropdownButtonFormField<String>(
            value: _project.surahName,
            decoration: const InputDecoration(labelText: 'السورة'),
            items: _surahs.map((name) =>
              DropdownMenuItem(value: name, child: Text(name))).toList(),
            onChanged: (value) async {
              if (value == null) return;
              final number = _surahs.indexOf(value) + 1;
              final max = QuranTextStore.ayahCounts[number - 1];
              await _update(_project.copyWith(
                surahName: value,
                verseStart: 1,
                verseEnd: max < 7 ? max : 7,
              ));
              await _loadAyat();
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _NumberField(
                  label: 'من الآية',
                  value: _project.verseStart,
                  max: maxAyah,
                  onChanged: (v) async {
                    final end = _project.verseEnd < v ? v : _project.verseEnd;
                    await _update(_project.copyWith(verseStart: v, verseEnd: end));
                    await _loadAyat();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _NumberField(
                  label: 'إلى الآية',
                  value: _project.verseEnd,
                  max: maxAyah,
                  onChanged: (v) async {
                    final start = _project.verseStart > v ? v : _project.verseStart;
                    await _update(_project.copyWith(verseStart: start, verseEnd: v));
                    await _loadAyat();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_quranPath == null)
            const _InfoPanel(
              icon: Icons.info_outline,
              text: 'لم يتم استيراد نص المصحف بعد. اختر ملفًا موثوقًا لعرض الآيات دون اتصال.',
            )
          else if (_visibleAyat.isEmpty)
            const _InfoPanel(
              icon: Icons.warning_amber_outlined,
              text: 'لم تُعرض آيات. تحقق من الملف ونطاق الآيات المختار.',
            )
          else
            _AyahPreview(
              ayat: _visibleAyat,
              start: _project.verseStart,
            ),
          const SizedBox(height: 24),
          const _SectionTitle('التلاوة الصوتية'),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: _importingAudio ? null : _importAudio,
            icon: _importingAudio
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.audio_file),
            label: Text(_project.audioPath == null
                ? 'استيراد ملف صوتي من الهاتف'
                : 'اختيار ملف صوتي آخر'),
          ),
          if (_project.audioPath != null) ...[
            const SizedBox(height: 8),
            Text(
              'الملف: ${_project.audioPath!.split(Platform.pathSeparator).last}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
            StreamBuilder<PlayerState>(
              stream: _audioPlayer.playerStateStream,
              builder: (context, snapshot) {
                final playing = snapshot.data?.playing ?? false;
                return Row(
                  children: [
                    IconButton.filled(
                      onPressed: () async {
                        if (playing) {
                          await _audioPlayer.pause();
                        } else {
                          if (_audioPlayer.processingState == ProcessingState.completed) {
                            await _audioPlayer.seek(Duration.zero);
                          }
                          await _audioPlayer.play();
                        }
                      },
                      icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                    ),
                    Expanded(
                      child: StreamBuilder<Duration?>(
                        stream: _audioPlayer.durationStream,
                        builder: (context, durationSnapshot) {
                          final duration = durationSnapshot.data ?? Duration.zero;
                          return StreamBuilder<Duration>(
                            stream: _audioPlayer.positionStream,
                            builder: (context, positionSnapshot) {
                              final position = positionSnapshot.data ?? Duration.zero;
                              final maxMs = duration.inMilliseconds;
                              final value = maxMs == 0
                                  ? 0.0
                                  : position.inMilliseconds.clamp(0, maxMs).toDouble();
                              return Column(
                                children: [
                                  Slider(
                                    value: value,
                                    max: maxMs == 0 ? 1 : maxMs.toDouble(),
                                    onChanged: maxMs == 0
                                        ? null
                                        : (v) => _audioPlayer.seek(
                                              Duration(milliseconds: v.round())),
                                  ),
                                  Text('${_format(position)} / ${_format(duration)}',
                                      style: const TextStyle(
                                          color: Colors.white60, fontSize: 11)),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
          if (_audioError != null)
            Text(_audioError!,
                style: const TextStyle(color: Colors.orangeAccent)),
          const SizedBox(height: 24),
          const _SectionTitle('مزامنة توقيت الآيات يدويًا'),
          const SizedBox(height: 8),
          const Text(
            'شغّل التلاوة، وعند بداية الآية اضغط تسجيل البداية، وعند نهايتها اضغط تسجيل النهاية. التوقيتات محفوظة بالمللي ثانية من بداية الملف الصوتي.',
            textDirection: TextDirection.rtl,
            style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            value: _timingAyah.clamp(_project.verseStart, _project.verseEnd).toInt(),
            decoration: const InputDecoration(labelText: 'الآية التي تتم مزامنتها'),
            items: List.generate(
              _project.verseEnd - _project.verseStart + 1,
              (index) => DropdownMenuItem(
                value: _project.verseStart + index,
                child: Text('الآية ${_project.verseStart + index}'),
              ),
            ),
            onChanged: (value) {
              if (value != null) setState(() => _timingAyah = value);
            },
          ),
          const SizedBox(height: 8),
          Builder(builder: (context) {
            final timing = _timingFor(_activeTimingAyah);
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF202729),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                timing == null
                    ? 'لم يتم تسجيل توقيت لهذه الآية.'
                    : 'البداية: ${_format(Duration(milliseconds: timing.startMs))}  •  النهاية: ${timing.endMs == null ? 'غير مسجلة' : _format(Duration(milliseconds: timing.endMs!))}',
                textDirection: TextDirection.rtl,
                style: const TextStyle(color: Colors.white70),
              ),
            );
          }),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: _project.audioPath == null ? null : _saveAyahStart,
                icon: const Icon(Icons.flag_outlined),
                label: const Text('تسجيل البداية'),
              ),
              FilledButton.tonalIcon(
                onPressed: _project.audioPath == null ? null : _saveAyahEnd,
                icon: const Icon(Icons.flag),
                label: const Text('تسجيل النهاية'),
              ),
              OutlinedButton.icon(
                onPressed: _project.audioPath == null ? null : _seekToAyahStart,
                icon: const Icon(Icons.replay),
                label: const Text('الانتقال للبداية'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'تم تسجيل ${_project.ayahTimings.where((t) => t.ayah >= _project.verseStart && t.ayah <= _project.verseEnd && t.endMs != null).length} من ${_project.verseEnd - _project.verseStart + 1} آية بالكامل.',
            textDirection: TextDirection.rtl,
            style: const TextStyle(color: Color(0xFFE1B86F), fontSize: 12),
          ),
          const SizedBox(height: 24),
          const _SectionTitle('الخطوط — مثل خيارات الموقع'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: FontCatalog.quranStyles.contains(_project.quranFontStyle)
                ? _project.quranFontStyle : FontCatalog.quranStyles.first,
            decoration: const InputDecoration(labelText: 'خط النص القرآني'),
            items: FontCatalog.quranStyles.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (v) { if (v != null) _update(_project.copyWith(quranFontStyle: v)); },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: FontCatalog.reciterStyles.contains(_project.reciterFontStyle)
                ? _project.reciterFontStyle : FontCatalog.reciterStyles[4],
            decoration: const InputDecoration(labelText: 'خط اسم القارئ والعناوين'),
            items: FontCatalog.reciterStyles.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (v) { if (v != null) _update(_project.copyWith(reciterFontStyle: v)); },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: FontCatalog.surahStyles.contains(_project.surahFontStyle)
                ? _project.surahFontStyle : FontCatalog.surahStyles.first,
            decoration: const InputDecoration(labelText: 'خط اسم السورة'),
            items: FontCatalog.surahStyles.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (v) { if (v != null) _update(_project.copyWith(surahFontStyle: v)); },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: FontCatalog.translationStyles.contains(_project.translationFontStyle)
                ? _project.translationFontStyle : FontCatalog.translationStyles.first,
            decoration: const InputDecoration(labelText: 'خط الترجمة / النص الإضافي'),
            items: FontCatalog.translationStyles.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (v) { if (v != null) _update(_project.copyWith(translationFontStyle: v)); },
          ),
          const SizedBox(height: 10),
          _fontImportButton(
            label: 'خط الآيات',
            currentPath: _project.quranCustomFontPath,
            family: FontCatalog.quranFamily,
            onImported: (path) => _update(_project.copyWith(quranCustomFontPath: path)),
          ),
          _fontImportButton(
            label: 'خط اسم السورة',
            currentPath: _project.surahCustomFontPath,
            family: FontCatalog.surahFamily,
            onImported: (path) => _update(_project.copyWith(surahCustomFontPath: path)),
          ),
          _fontImportButton(
            label: 'خط رقم الآية',
            currentPath: _project.markerCustomFontPath,
            family: FontCatalog.markerFamily,
            onImported: (path) => _update(_project.copyWith(markerCustomFontPath: path)),
          ),
          const SizedBox(height: 12),
          const _SectionTitle('حجم ولون النصوص'),
          _sizeControl('حجم الآية', _project.quranFontSize, 16, 42,
              (v) => _update(_project.copyWith(quranFontSize: v))),
          _sizeControl('حجم اسم السورة', _project.surahFontSize, 12, 32,
              (v) => _update(_project.copyWith(surahFontSize: v))),
          _sizeControl('حجم رقم الآية', _project.markerFontSize, 12, 32,
              (v) => _update(_project.copyWith(markerFontSize: v))),
          _colorControl('لون الآيات', _project.quranTextColor,
              (v) => _update(_project.copyWith(quranTextColor: v))),
          _colorControl('لون اسم السورة', _project.surahTextColor,
              (v) => _update(_project.copyWith(surahTextColor: v))),
          _colorControl('لون رقم الآية', _project.markerTextColor,
              (v) => _update(_project.copyWith(markerTextColor: v))),
          const Padding(
            padding: EdgeInsets.only(top: 5),
            child: Text(
              'ملاحظة: أسماء الأنماط تطابق الخيارات الظاهرة في الموقع. الخطوط الأصلية نفسها لا تُضمّن دون ملفاتها وترخيصها؛ لعرض شكل مطابق استورد ملف TTF/OTF مرخّصًا. الخط المستورد يعمل دون إنترنت.',
              textDirection: TextDirection.rtl,
              style: TextStyle(color: Colors.white60, fontSize: 11, height: 1.5),
            ),
          ),
          const SizedBox(height: 24),
          const _SectionTitle('شكل الفيديو'),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _project.aspectRatio,
            decoration: const InputDecoration(labelText: 'أبعاد الفيديو'),
            items: const ['9:16', '16:9', '1:1', '4:5']
                .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (v) {
              if (v != null) _update(_project.copyWith(aspectRatio: v));
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _project.background,
            decoration: const InputDecoration(labelText: 'الخلفية التجريبية'),
            items: const ['Midnight', 'Desert', 'Forest', 'Plain']
                .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (v) {
              if (v != null) _update(_project.copyWith(background: v));
            },
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _exportingVideo ? null : _exportVideo,
            icon: _exportingVideo
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.video_file_outlined),
            label: Text(_exportingVideo ? 'جارٍ إنشاء الفيديو...' : 'إنشاء وتصدير MP4'),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 7),
            child: Text(
              'يتطلب اكتمال توقيت البداية والنهاية لكل آية. يحفظ الفيديو داخل مجلد التطبيق exports، بدقة مناسبة لنسبة الأبعاد المختارة.',
              textDirection: TextDirection.rtl,
              style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.5),
            ),
          ),
          const SizedBox(height: 22),
          const _SectionTitle('حالة المرحلة الخامسة'),
          const _FeatureStatus(
            title: 'استيراد ملف نص القرآن والتحقق من عدد الآيات',
            detail: 'يعمل محليًا بعد اختيار ملف Tanzil المتوافق.',
            done: true,
          ),
          const _FeatureStatus(
            title: 'استيراد وتشغيل ملف صوتي محلي',
            detail: 'يستخدم ملفات يختارها المستخدم من الهاتف.',
            done: true,
          ),
          const _FeatureStatus(
            title: 'تسجيل بداية ونهاية كل آية يدويًا',
            detail: 'التوقيتات تحفظ داخل المشروع ويمكن الرجوع لبداية الآية.',
            done: true,
          ),
          const _FeatureStatus(
            title: 'معاينة الآية الحالية حسب توقيت الصوت',
            detail: 'تتغير الآية في المعاينة أثناء تشغيل الصوت إذا كانت توقيتاتها مسجلة.',
            done: true,
          ),
          const _FeatureStatus(
            title: 'إنشاء بطاقات الآيات وتركيبها مع التلاوة',
            detail: 'توليد صور عربية لكل آية ثم تركيبها مع الصوت باستخدام FFmpeg.',
            done: true,
          ),
          const SizedBox(height: 18),
          const Text(
            'التصدير يعتمد على التوقيتات اليدوية، وينشئ بطاقات ثابتة للآيات دون انتقالات متحركة. احفظ الفيديو من مجلد التطبيق بعد التصدير؛ لم تتم إضافة زر مشاركة إلى المعرض بعد.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _fontImportButton({
    required String label,
    required String? currentPath,
    required String family,
    required Future<void> Function(String path) onImported,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: OutlinedButton.icon(
        onPressed: () async {
          try {
            final path = await FontCatalog.importFont();
            if (path == null) return;
            await FontCatalog.loadCustomFont(path, family: FontCatalog.familyForPath(path, family));
            await onImported(path);
            if (mounted) _message('تم استيراد $label وتفعيله.');
          } catch (e) {
            if (mounted) _message('تعذر استيراد $label: $e');
          }
        },
        icon: const Icon(Icons.font_download_outlined),
        label: Text(currentPath == null ? 'استيراد $label (TTF / OTF)' : 'تغيير $label'),
      ),
    );
  }

  Widget _sizeControl(String label, double value, double min, double max,
      ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('$label: ${value.round()} px', textDirection: TextDirection.rtl,
            style: const TextStyle(color: Colors.white70)),
        Slider(value: value.clamp(min, max).toDouble(), min: min, max: max,
            divisions: (max - min).round(), onChanged: onChanged),
      ],
    );
  }

  Widget _colorControl(String label, int value, ValueChanged<int> onChanged) {
    const palette = <int, String>{
      0xFFFFF5E3: 'عاجي',
      0xFFFFFFFF: 'أبيض',
      0xFFE8C47D: 'ذهبي',
      0xFFEEDDBB: 'ذهبي فاتح',
      0xFFB8D8E8: 'أزرق فاتح',
      0xFFD7C4F2: 'بنفسجي فاتح',
      0xFFBFE3C0: 'أخضر فاتح',
    };
    final selected = palette.containsKey(value) ? value : palette.keys.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DropdownButtonFormField<int>(
        value: selected,
        decoration: InputDecoration(labelText: label),
        items: palette.entries.map((entry) => DropdownMenuItem<int>(
          value: entry.key,
          child: Row(children: [
            Container(width: 18, height: 18, decoration: BoxDecoration(
              color: Color(entry.key), shape: BoxShape.circle,
              border: Border.all(color: Colors.white30))),
            const SizedBox(width: 8), Text(entry.value),
          ]),
        )).toList(),
        onChanged: (v) { if (v != null) onChanged(v); },
      ),
    );
  }

  static String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

class _LiveVideoPreview extends StatelessWidget {
  const _LiveVideoPreview({
    required this.project,
    required this.ayat,
    required this.positionMs,
  });

  final StudioProject project;
  final List<String> ayat;
  final int positionMs;

  int? get _activeAyah {
    for (final timing in project.ayahTimings) {
      final end = timing.endMs;
      if (end != null && positionMs >= timing.startMs && positionMs < end) {
        return timing.ayah;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = switch (project.background) {
      'Desert' => [const Color(0xFF806044), const Color(0xFF30251E)],
      'Forest' => [const Color(0xFF285646), const Color(0xFF101F1B)],
      'Plain' => [const Color(0xFF55585B), const Color(0xFF202326)],
      _ => [const Color(0xFF24434C), const Color(0xFF10191F)],
    };
    final ratio = switch (project.aspectRatio) {
      '16:9' => 16 / 9,
      '1:1' => 1.0,
      '4:5' => 4 / 5,
      _ => 9 / 16,
    };
    final active = _activeAyah;
    final index = active == null ? -1 : active - project.verseStart;
    final verseText = index >= 0 && index < ayat.length ? ayat[index] : null;

    return Center(
      child: AspectRatio(
        aspectRatio: ratio,
        child: Container(
          constraints: const BoxConstraints(maxHeight: 390),
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white24),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 14,
                left: 12,
                right: 12,
                child: Text(
                  'سُورَةُ ${project.surahName}',
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    color: Color(project.surahTextColor),
                    fontWeight: FontWeight.w700,
                    fontSize: project.surahFontSize,
                    fontFamily: (project.surahCustomFontPath ?? project.customFontPath) != null ? FontCatalog.familyForPath(project.surahCustomFontPath ?? project.customFontPath, FontCatalog.surahFamily) : FontCatalog.familyFor(project.surahFontStyle),
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 48),
                  child: verseText == null
                      ? const Text(
                          'شغّل التلاوة بعد تسجيل توقيت الآيات\nلتظهر الآية الحالية هنا',
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(color: Colors.white70, height: 1.8),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              verseText,
                              textAlign: TextAlign.center,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                color: Color(project.quranTextColor),
                                fontSize: project.quranFontSize,
                                height: 1.9,
                                fontWeight: FontWeight.w600,
                                fontFamily: (project.quranCustomFontPath ?? project.customFontPath) != null ? FontCatalog.familyForPath(project.quranCustomFontPath ?? project.customFontPath, FontCatalog.quranFamily) : FontCatalog.familyFor(project.quranFontStyle),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              '۝ $active',
                              style: TextStyle(
                                color: Color(project.markerTextColor), fontSize: project.markerFontSize,
                                fontFamily: (project.markerCustomFontPath ?? project.customFontPath) != null ? FontCatalog.familyForPath(project.markerCustomFontPath ?? project.customFontPath, FontCatalog.markerFamily) : FontCatalog.familyFor(project.reciterFontStyle)),
                            ),
                          ],
                        ),
                ),
              ),
              Positioned(
                bottom: 10,
                left: 12,
                right: 12,
                child: Text(
                  '${_clock(positionMs)}  •  معاينة مباشرة',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _clock(int ms) {
    final total = ms ~/ 1000;
    final minutes = (total ~/ 60).toString().padLeft(2, '0');
    final seconds = (total % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
  });
  final String label;
  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: ValueKey('$label-$value'),
      initialValue: value.toString(),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label, helperText: '1 إلى $max'),
      onChanged: (text) {
        final parsed = int.tryParse(text);
        if (parsed != null && parsed >= 1 && parsed <= max) onChanged(parsed);
      },
    );
  }
}

class _AyahPreview extends StatelessWidget {
  const _AyahPreview({required this.ayat, required this.start});
  final List<String> ayat;
  final int start;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2222),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          const Text('معاينة نص الآيات المستوردة',
              style: TextStyle(color: Color(0xFFE1B86F))),
          const SizedBox(height: 10),
          ...List.generate(ayat.length, (index) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Text(
              '${ayat[index]}  ۝${start + index}',
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19, height: 1.8, color: Color(0xFFF1E8D8),
                fontFamily: FontCatalog.familyFor('خط النسخ (أميري)')),
            ),
          )),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Text(
        title,
        textDirection: TextDirection.rtl,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      );
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF202729),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white60),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text, textDirection: TextDirection.rtl,
                  style: const TextStyle(color: Colors.white70, height: 1.5)),
            ),
          ],
        ),
      );
}

class _FeatureStatus extends StatelessWidget {
  const _FeatureStatus({
    required this.title,
    required this.detail,
    required this.done,
  });
  final String title;
  final String detail;
  final bool done;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          done ? Icons.check_circle : Icons.radio_button_unchecked,
          color: done ? Colors.greenAccent : Colors.white54,
        ),
        title: Text(title, textDirection: TextDirection.rtl),
        subtitle: Text(detail, textDirection: TextDirection.rtl),
      );
}
