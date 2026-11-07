import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:ffmpeg_kit_flutter_new_video/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_video/return_code.dart';
import 'package:path_provider/path_provider.dart';

import '../models/studio_project.dart';
import 'font_catalog.dart';

class VideoExportResult {
  const VideoExportResult({required this.path, required this.ayahCount});
  final String path;
  final int ayahCount;
}

/// Renders one Arabic PNG card per timed ayah, then muxes the cards with audio.
/// Output is intentionally saved in app documents until a gallery-save flow is added.
class VideoExportService {
  Future<VideoExportResult> export({
    required StudioProject project,
    required List<String> ayat,
    required String audioPath,
    required String outputName,
  }) async {
    await FontCatalog.loadCustomFont(project.quranCustomFontPath ?? project.customFontPath, family: FontCatalog.familyForPath(project.quranCustomFontPath ?? project.customFontPath, FontCatalog.quranFamily));
    await FontCatalog.loadCustomFont(project.surahCustomFontPath ?? project.customFontPath, family: FontCatalog.familyForPath(project.surahCustomFontPath ?? project.customFontPath, FontCatalog.surahFamily));
    await FontCatalog.loadCustomFont(project.markerCustomFontPath ?? project.customFontPath, family: FontCatalog.familyForPath(project.markerCustomFontPath ?? project.customFontPath, FontCatalog.markerFamily));
    if (!await File(audioPath).exists()) {
      throw const FormatException('ملف التلاوة غير موجود.');
    }
    if (ayat.length != project.verseEnd - project.verseStart + 1) {
      throw const FormatException('نص الآيات لا يطابق النطاق المحدد.');
    }

    final timings = <AyahTiming>[];
    for (var ayah = project.verseStart; ayah <= project.verseEnd; ayah++) {
      final matches = project.ayahTimings.where((item) => item.ayah == ayah);
      if (matches.isEmpty || matches.first.endMs == null) {
        throw FormatException('أكمل توقيت بداية ونهاية الآية $ayah أولًا.');
      }
      final timing = matches.first;
      if (timing.startMs < 0 || timing.endMs! <= timing.startMs) {
        throw FormatException('توقيت الآية $ayah غير صحيح.');
      }
      timings.add(timing);
    }
    for (var i = 1; i < timings.length; i++) {
      if (timings[i].startMs < timings[i - 1].endMs!) {
        throw FormatException('توقيت الآية ${timings[i].ayah} يتداخل مع الآية السابقة.');
      }
    }

    final docs = await getApplicationDocumentsDirectory();
    final safeName = outputName
        .replaceAll(RegExp(r'[^\w\-\u0600-\u06FF]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final folder = Directory('${docs.path}/exports/${project.id}');
    await folder.create(recursive: true);
    final frames = Directory('${folder.path}/frames');
    if (await frames.exists()) await frames.delete(recursive: true);
    await frames.create(recursive: true);

    final (width, height) = _dimensions(project.aspectRatio);
    final manifest = File('${folder.path}/frames.txt');
    final lines = <String>['ffconcat version 1.0'];
    for (var i = 0; i < ayat.length; i++) {
      final frame = File('${frames.path}/ayah_${i.toString().padLeft(4, '0')}.png');
      await _renderCard(
        file: frame,
        width: width,
        height: height,
        text: ayat[i],
        surah: project.surahName,
        ayah: project.verseStart + i,
        background: project.background,
        quranFontFamily: (project.quranCustomFontPath ?? project.customFontPath) != null
            ? FontCatalog.familyForPath(project.quranCustomFontPath ?? project.customFontPath, FontCatalog.quranFamily) : FontCatalog.familyFor(project.quranFontStyle),
        headingFontFamily: (project.surahCustomFontPath ?? project.customFontPath) != null
            ? FontCatalog.familyForPath(project.surahCustomFontPath ?? project.customFontPath, FontCatalog.surahFamily) : FontCatalog.familyFor(project.surahFontStyle),
        markerFontFamily: (project.markerCustomFontPath ?? project.customFontPath) != null
            ? FontCatalog.familyForPath(project.markerCustomFontPath ?? project.customFontPath, FontCatalog.markerFamily) : FontCatalog.familyFor(project.reciterFontStyle),
        quranFontSize: project.quranFontSize,
        surahFontSize: project.surahFontSize,
        markerFontSize: project.markerFontSize,
        quranTextColor: Color(project.quranTextColor),
        surahTextColor: Color(project.surahTextColor),
        markerTextColor: Color(project.markerTextColor),
      );
      final path = frame.path.replaceAll("'", "'\\''");
      lines.add("file '$path'");
      final nextStart = i + 1 < timings.length ? timings[i + 1].startMs : timings[i].endMs!;
      final duration = (nextStart - timings[i].startMs) / 1000.0;
      lines.add('duration ${duration.toStringAsFixed(3)}');
    }
    // concat demuxer needs a final file entry for the last duration to be honored.
    final lastPath = '${frames.path}/ayah_${(ayat.length - 1).toString().padLeft(4, '0')}.png'
        .replaceAll("'", "'\\''");
    lines.add("file '$lastPath'");
    await manifest.writeAsString('${lines.join('\n')}\n', flush: true);

    final output = File('${folder.path}/$safeName.mp4');
    if (await output.exists()) await output.delete();
    final command = '-y -f concat -safe 0 -i ${_quote(manifest.path)} '
        '-ss ${(timings.first.startMs / 1000).toStringAsFixed(3)} -i ${_quote(audioPath)} '
        '-map 0:v:0 -map 1:a:0 -c:v mpeg4 -q:v 5 -r 30 '
        '-pix_fmt yuv420p -c:a aac -b:a 128k -shortest -movflags +faststart '
        '${_quote(output.path)}';
    final session = await FFmpegKit.execute(command);
    final code = await session.getReturnCode();
    if (!ReturnCode.isSuccess(code) || !await output.exists() || await output.length() == 0) {
      final logs = (await session.getOutput()) ?? 'لا توجد تفاصيل إضافية.';
      throw Exception('فشل إنشاء الفيديو. تفاصيل FFmpeg: $logs');
    }
    return VideoExportResult(path: output.path, ayahCount: ayat.length);
  }

  String _quote(String value) => '"${value.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}"';

  (int, int) _dimensions(String ratio) => switch (ratio) {
        '16:9' => (1280, 720),
        '1:1' => (900, 900),
        '4:5' => (864, 1080),
        _ => (720, 1280),
      };

  Future<void> _renderCard({
    required File file,
    required int width,
    required int height,
    required String text,
    required String surah,
    required int ayah,
    required String background,
    required String quranFontFamily,
    required String headingFontFamily,
    required String markerFontFamily,
    required double quranFontSize,
    required double surahFontSize,
    required double markerFontSize,
    required Color quranTextColor,
    required Color surahTextColor,
    required Color markerTextColor,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));
    final colors = switch (background) {
      'Desert' => [const Color(0xFF6C4C32), const Color(0xFF241B17)],
      'Forest' => [const Color(0xFF244A3B), const Color(0xFF101F1B)],
      'Plain' => [const Color(0xFF242424), const Color(0xFF111111)],
      _ => [const Color(0xFF172D3A), const Color(0xFF090F1B)],
    };
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..shader = ui.Gradient.linear(
        Offset.zero, Offset(0, height.toDouble()), colors),
    );
    final margin = width * 0.09;
    final border = Paint()
      ..color = const Color(0x66E7C987)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * 0.002;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(margin, margin, width - margin * 2, height - margin * 2),
        Radius.circular(width * 0.035)),
      border,
    );

    _drawText(canvas, 'سورة $surah', width, height * 0.22,
        width * (surahFontSize / 390), surahTextColor, FontWeight.w600, 1,
        fontFamily: headingFontFamily);
    final verseFontScale = text.runes.length > 260 ? 0.032 :
        text.runes.length > 160 ? 0.040 : 0.052;
    _drawText(canvas, text, width, height * 0.49,
        width * (quranFontSize / 390), quranTextColor, FontWeight.w600, 12,
        horizontalPadding: width * 0.13, fontFamily: quranFontFamily);
    _drawText(canvas, '۝ $ayah', width, height * 0.78,
        width * (markerFontSize / 390), markerTextColor, FontWeight.w600, 1,
        fontFamily: markerFontFamily);

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw Exception('تعذر إنشاء صورة الآية رقم $ayah.');
    await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    image.dispose();
    picture.dispose();
  }

  void _drawText(Canvas canvas, String text, int width, double centerY,
      double fontSize, Color color, FontWeight weight, int maxLines,
      {double? horizontalPadding, String? fontFamily}) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(
        fontSize: fontSize,
        fontFamily: fontFamily,
        color: color, height: 1.8, fontWeight: weight)),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.center,
      maxLines: maxLines,
      ellipsis: '…',
    )..layout(maxWidth: width - (horizontalPadding ?? width * 0.16) * 2);
    painter.paint(canvas, Offset((width - painter.width) / 2, centerY - painter.height / 2));
  }
}
