import 'package:flutter/material.dart';
import '../models/studio_project.dart';
import '../services/project_store.dart';
import 'project_editor_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ProjectStore _store = ProjectStore();
  List<StudioProject> _projects = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final projects = await _store.loadProjects();
    if (!mounted) return;
    setState(() {
      _projects = projects;
      _loading = false;
    });
  }

  Future<void> _createProject() async {
    final nameController = TextEditingController(text: 'مشروع قرآني جديد');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إنشاء مشروع'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          textDirection: TextDirection.rtl,
          decoration: const InputDecoration(labelText: 'اسم المشروع'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            child: const Text('إنشاء'),
          ),
        ],
      ),
    );
    nameController.dispose();
    if (name == null || name.trim().isEmpty) return;

    final now = DateTime.now();
    final project = StudioProject(
      id: now.microsecondsSinceEpoch.toString(),
      name: name.trim(),
      surahName: 'الفاتحة',
      createdAt: now.toIso8601String(),
    );
    await _store.saveProject(project);
    await _load();
    if (!mounted) return;
    _openProject(project);
  }

  Future<void> _openProject(StudioProject project) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectEditorScreen(project: project),
      ),
    );
    await _load();
  }

  Future<void> _deleteProject(StudioProject project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المشروع؟'),
        content: Text('سيتم حذف "${project.name}" من قائمة المشاريع المحلية.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _store.deleteProject(project.id);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tarteel Studio',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'حول التطبيق',
            onPressed: () => showAboutDialog(
              context: context,
              applicationName: 'Tarteel Studio',
              applicationVersion: '0.1.0',
              applicationLegalese:
                  'استوديو مستقل لإنشاء فيديوهات قرآنية. هذه نسخة تأسيسية.',
            ),
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createProject,
        icon: const Icon(Icons.add),
        label: const Text('مشروع جديد'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  const _WelcomePanel(),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Expanded(
                        child: Text('مشاريعي',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                      ),
                      Text('${_projects.length} مشروع',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_projects.isEmpty)
                    const _EmptyProjects()
                  else
                    ..._projects.map(
                      (project) => Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFF3B3021),
                            child: Icon(Icons.movie_creation_outlined,
                                color: Color(0xFFE0B56C)),
                          ),
                          title: Text(project.name,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                              '${project.surahName} • ${project.aspectRatio}'),
                          onTap: () => _openProject(project),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'delete') _deleteProject(project);
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('حذف المشروع'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 90),
                ],
              ),
            ),
    );
  }
}

class _WelcomePanel extends StatelessWidget {
  const _WelcomePanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFF3D3020), Color(0xFF1D2423)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome, color: Color(0xFFE2B66D), size: 28),
          SizedBox(height: 14),
          Text('اصنع فيديوك القرآني',
              textDirection: TextDirection.rtl,
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text(
            'أنشئ مشروعك واحفظ إعداداته على هاتفك. لا يحتاج هذا الجزء إلى اتصال بالإنترنت.',
            textDirection: TextDirection.rtl,
            style: TextStyle(color: Colors.white70, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _EmptyProjects extends StatelessWidget {
  const _EmptyProjects();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        children: [
          Icon(Icons.video_library_outlined, size: 42, color: Colors.white54),
          SizedBox(height: 12),
          Text('لا توجد مشاريع بعد',
              style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 6),
          Text('اضغط على «مشروع جديد» للبدء.',
              style: TextStyle(color: Colors.white60)),
        ],
      ),
    );
  }
}
