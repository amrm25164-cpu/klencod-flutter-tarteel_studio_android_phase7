import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

class AudioImportService {
  Future<String?> pickAndCopyAudio() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'm4a', 'aac', 'wav', 'ogg', 'flac'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return null;

    final sourcePath = result.files.single.path;
    if (sourcePath == null) {
      throw const FileSystemException('تعذر الوصول إلى مسار الملف الصوتي.');
    }
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const FileSystemException('الملف الصوتي غير موجود.');
    }

    final docs = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${docs.path}/audio');
    if (!await audioDir.exists()) await audioDir.create(recursive: true);

    final extension = result.files.single.extension ?? 'audio';
    final safeName = 'recitation_${DateTime.now().microsecondsSinceEpoch}.$extension';
    final destination = File('${audioDir.path}/$safeName');
    await source.copy(destination.path);
    return destination.path;
  }
}
