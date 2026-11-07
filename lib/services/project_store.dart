import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/studio_project.dart';

class ProjectStore {
  static const _storageKey = 'tarteel_studio_projects_v1';

  Future<List<StudioProject>> loadProjects() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((item) => StudioProject.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveProjects(List<StudioProject> projects) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(projects.map((p) => p.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }

  Future<void> deleteProject(String id) async {
    final projects = await loadProjects();
    projects.removeWhere((project) => project.id == id);
    await saveProjects(projects);
  }

  Future<void> saveProject(StudioProject updated) async {
    final projects = await loadProjects();
    final index = projects.indexWhere((project) => project.id == updated.id);
    if (index == -1) {
      projects.insert(0, updated);
    } else {
      projects[index] = updated;
    }
    await saveProjects(projects);
  }
}
