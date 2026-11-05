/// Documentation.
/// Documentation.

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/models/skill_model.dart';
import '../../main.dart';

/// Documentation.
final skillsProvider = StateProvider<List<SkillModel>>((ref) => []);

/// Documentation.
class PluginCenterPage extends ConsumerStatefulWidget {
  const PluginCenterPage({super.key});

  @override
  ConsumerState<PluginCenterPage> createState() => _PluginCenterPageState();
}

class _PluginCenterPageState extends ConsumerState<PluginCenterPage> {
  /// Built-in Skill
  static final _builtinSkill = SkillModel(
    id: 'builtin_beginner_guide',
    name: 'Beginner Guide Expert',
    content: '''You are a patient, friendly, and professional GG-AI beginner guide.

Your goal is to help people with no memory-editing experience learn to use this modifier safely with single-player games.

### Principles
- Be friendly, patient, and explain one step at a time.
- Assume the user is new to memory editing, GG, and searches.
- Before risky actions, remind the user to back up save data.
- Refuse online-game assistance and explain why.
- Invite questions and confirm each step succeeded.

### Topics
1. Selecting and attaching a game process
2. Exact, fuzzy, range, and AOB searches
3. Searching known and unknown values
4. Editing and freezing results
5. Saving addresses and exporting scripts
6. Troubleshooting too many results, stale addresses, and crashes

### Style
- Use plain, friendly English and numbered steps.
- Ask whether each step worked and what the user sees.
- Use Markdown lists and code blocks, but avoid complex tables.
- End by asking what the user wants to do next.

### Workflow
1. Confirm the game is open and the relevant screen is visible.
2. Teach the user to attach the process.
3. Ask what value they want to edit.
4. Give the safest, simplest plan and wait for feedback after each step.
5. After success, explain how to save the address or create a one-tap script.

Begin helping the user learn memory editing from the basics.''',
    isBuiltin: true,
    isEnabled: false,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSkills();
    });
  }

  void _loadSkills() {
    final storage = ref.read(storageServiceProvider);
    final userSkills = storage.getAllSkills();

    // Implementation detail.
    final builtinEnabled = storage.getSetting('skill_${_builtinSkill.id}_enabled', defaultValue: false) as bool;
    final builtinWithState = _builtinSkill.copyWith(isEnabled: builtinEnabled);

    // Implementation detail.
    final allSkills = <SkillModel>[builtinWithState];

    // Implementation detail.
    for (final skill in userSkills) {
      if (skill.id != _builtinSkill.id) {
        allSkills.add(skill);
      }
    }

    ref.read(skillsProvider.notifier).state = allSkills;
  }

  /// Documentation.
  Future<void> _importSkill() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['md'],
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      String content;

      if (file.bytes != null) {
        content = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        final fileObj = File(file.path!);
        content = await fileObj.readAsString();
      } else {
        _showSnackBar('❌ Unable to read file');
        return;
      }

      if (!mounted) return;

      // Implementation detail.
      _showNameDialog(content, file.name, file.path);
    } catch (e) {
      _showSnackBar('❌ Import failed: $e');
    }
  }

  /// Documentation.
  void _showNameDialog(String content, String fileName, String? filePath) {
    final nameController = TextEditingController(
      text: fileName.replaceAll('.md', ''),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFFFFF),
        title: const Text('Import Skill'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Skill name',
                hintText: 'Enter a display name',
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F3F8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.description, size: 16, color: Color(0xFF4A6572)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      fileName,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF4A6572)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                _showSnackBar('Enter a name');
                return;
              }
              _saveSkill(name, content, filePath);
              Navigator.pop(context);
            },
            child: const Text('import '),
          ),
        ],
      ),
    );
  }

  /// Save Skill
  Future<void> _saveSkill(String name, String content, String? filePath) async {
    final storage = ref.read(storageServiceProvider);
    final now = DateTime.now();

    // Implementation detail.
    String savedPath = '';
    if (filePath != null) {
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final skillsDir = Directory('${appDir.path}/skills');
        if (!await skillsDir.exists()) {
          await skillsDir.create(recursive: true);
        }
        final skillFile = File('${skillsDir.path}/${now.millisecondsSinceEpoch}.md');
        await skillFile.writeAsString(content);
        savedPath = skillFile.path;
      } catch (e) {
        savedPath = filePath;
      }
    }

    final skill = SkillModel(
      id: 'skill_${now.millisecondsSinceEpoch}',
      name: name,
      content: content,
      filePath: savedPath,
      isEnabled: false,
      createdAt: now,
      updatedAt: now,
    );

    await storage.saveSkill(skill);
    _loadSkills();
    _showSnackBar('✅ Skill "$name" Imported');
  }

  /// Delete Skill
  void _deleteSkill(SkillModel skill) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFFFFF),
        title: const Text('Delete Skill'),
        content: Text('Delete "${skill.name}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final storage = ref.read(storageServiceProvider);
              await storage.deleteSkill(skill.id);
              _loadSkills();
              Navigator.pop(context);
              _showSnackBar('✅ Delete "${skill.name}"');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// Documentation.
  Future<void> _toggleSkill(SkillModel skill) async {
    final storage = ref.read(storageServiceProvider);

    if (skill.isBuiltin) {
      // Implementation detail.
      final newValue = !skill.isEnabled;
      await storage.saveSetting('skill_${skill.id}_enabled', newValue);
    } else {
      await storage.toggleSkill(skill.id);
    }

    _loadSkills();

    // Implementation detail.
    final allSkills = ref.read(skillsProvider);
    final enabledSkills = allSkills.where((s) => s.isEnabled).toList();
    _syncSkillsToNative(enabledSkills);
  }

  /// Documentation.
  void _syncSkillsToNative(List<SkillModel> enabledSkills) {
    try {
      final skillsJson = enabledSkills.map((s) => {
        'id': s.id,
        'name': s.name,
        'content': s.content,
      }).toList();
      const channel = MethodChannel('com.yl.aigg/bridge');
      channel.invokeMethod('syncSkills', {'skills': jsonEncode(skillsJson)});
    } catch (_) {}
  }

  /// Documentation.
  void _showExportDialog() {
    final storage = ref.read(storageServiceProvider);
    final skills = storage.getAllSkills();

    if (skills.isEmpty) {
      _showSnackBar('No skills available to export');
      return;
    }

    final selectedToExport = <String>{};

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFFFFFFFF),
          title: const Text('Export Skill'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: skills.map((skill) {
                return CheckboxListTile(
                  title: Text(skill.name),
                  subtitle: Text(
                    skill.isBuiltin ? 'Built-in' : 'User imported',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF4A6572)),
                  ),
                  value: selectedToExport.contains(skill.id),
                  onChanged: (value) {
                    setDialogState(() {
                      if (value == true) {
                        selectedToExport.add(skill.id);
                      } else {
                        selectedToExport.remove(skill.id);
                      }
                    });
                  },
                  activeColor: const Color(0xFF3D5AFE),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedToExport.isEmpty
                  ? null
                  : () {
                      Navigator.pop(context);
                      _exportSelectedSkills(selectedToExport);
                    },
              child: const Text('export '),
            ),
          ],
        ),
      ),
    );
  }

  /// Documentation.
  Future<void> _exportSelectedSkills(Set<String> selectedIds) async {
    final storage = ref.read(storageServiceProvider);
    final allSkills = storage.getAllSkills();
    final skillsToExport = allSkills.where((s) => selectedIds.contains(s.id)).toList();

    if (skillsToExport.isEmpty) return;

    try {
      const channel = MethodChannel('com.yl.aigg/bridge');
      int successCount = 0;

      for (final skill in skillsToExport) {
        final fileName = '${skill.name}.md';
        final filePath = await channel.invokeMethod('exportSkillToFile', {
          'fileName': fileName,
          'content': skill.content,
        });
        if (filePath != null) {
          successCount++;
        }
      }

      _showSnackBar('✅ Exported $successCount skills');
    } catch (e) {
      _showSnackBar('❌ Export failed: $e');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final skills = ref.watch(skillsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F8),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.extension, color: Color(0xFF3D5AFE)),
            SizedBox(width: 8),
            Text('Plugin Center'),
          ],
        ),
        actions: [
          // export button
          IconButton(
            icon: const Icon(Icons.upload),
            tooltip: 'Export Skill',
            onPressed: _showExportDialog,
          ),
          // Implementation detail.
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Import Skill',
            onPressed: _importSkill,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Implementation detail.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF3D5AFE).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.layers, color: Color(0xFF3D5AFE), size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Skill Manager',
                          style: TextStyle(
                            color: Color(0xFF213333),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${skills.length} skills imported; ${skills.where((s) => s.isEnabled).length} enabled',
                          style: const TextStyle(color: Color(0xFF4A6572), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Implementation detail.
            Row(
              children: [
                const Text(
                  '📋 Imported Skills',
                  style: TextStyle(
                    color: Color(0xFF213333),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  'Toggle to enable or disable',
                  style: TextStyle(
                    color: const Color(0xFF4A6572).withOpacity(0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Implementation detail.
            Expanded(
              child: skills.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.extension_off_outlined,
                            size: 64,
                            color: const Color(0xFF4A6572).withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No skills',
                            style: TextStyle(color: Color(0xFF4A6572), fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Tap + in the upper-right to import a .md file',
                            style: TextStyle(color: Color(0xFF4A6572), fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: skills.length,
                      itemBuilder: (context, index) {
                        return _buildSkillCard(skills[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillCard(SkillModel skill) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: const Color(0xFFFFFFFF),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Implementation detail.
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: skill.isEnabled
                    ? const Color(0xFF3D5AFE).withOpacity(0.1)
                    : const Color(0xFFF2F3F8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                skill.isBuiltin ? Icons.school : Icons.description,
                color: skill.isEnabled
                    ? const Color(0xFF3D5AFE)
                    : const Color(0xFF4A6572),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),

            // name  and information
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        skill.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: skill.isEnabled
                              ? const Color(0xFF213333)
                              : const Color(0xFF4A6572),
                        ),
                      ),
                      if (skill.isBuiltin) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3D5AFE).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Built-in',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF3D5AFE),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${skill.content.length} characters · ${skill.isEnabled ? "Enabled" : "Disabled"}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF4A6572),
                    ),
                  ),
                ],
              ),
            ),

            // Implementation detail.
            Switch(
              value: skill.isEnabled,
              onChanged: (_) => _toggleSkill(skill),
              activeColor: const Color(0xFF3D5AFE),
            ),

            // Implementation detail.
            if (!skill.isBuiltin)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                color: const Color(0xFF4A6572),
              onPressed: () => _deleteSkill(skill),
            ),
          ],
        ),
      ),
    );
  }
}
