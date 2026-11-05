/// Documentation.
/// Documentation.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/script_model.dart';
import '../../main.dart';

/// Documentation.
final scriptsProvider = StateProvider<List<ScriptModel>>((ref) => []);

/// Run log Provider
final scriptLogsProvider = StateProvider<List<Map<String, String>>>(
  (ref) => [],
);

/// Documentation.
class ScriptPage extends ConsumerStatefulWidget {
  const ScriptPage({super.key});

  @override
  ConsumerState<ScriptPage> createState() => _ScriptPageState();
}

class _ScriptPageState extends ConsumerState<ScriptPage> {
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadScripts();
      _loadLogs();
    });
  }

  /// Documentation.
  void _loadScripts() {
    final storage = ref.read(storageServiceProvider);
    final savedScripts = storage.getAllScripts();

    final builtinScripts = [
      ScriptModel(
        id: 'builtin_test',
        name: 'Run Test',
        description: 'Lua menu and data search test script',
        content: _builtinTestScript,
        isBuiltin: true,
        tags: ['Test', 'Menu'],
      ),
    ];

    final mergedMap = <String, ScriptModel>{};
    for (final s in builtinScripts) {
      mergedMap[s.id] = s;
    }
    for (final s in savedScripts) {
      mergedMap[s.id] = s;
    }

    ref.read(scriptsProvider.notifier).state = mergedMap.values.toList();

    // Implementation detail.
    _syncScriptsToNative(mergedMap.values.toList());
  }

  /// Documentation.
  void _syncScriptsToNative(List<ScriptModel> scripts) {
    try {
      final scriptsJson = scripts
          .map(
            (s) => {
              'id': s.id,
              'name': s.name,
              'content': s.content,
              'description': s.description,
            },
          )
          .toList();
      const channel = MethodChannel('com.yl.aigg/bridge');
      channel.invokeMethod('syncScripts', {'scripts': jsonEncode(scriptsJson)});
    } catch (_) {}
  }

  /// Documentation.
  void _loadLogs() {
    final storage = ref.read(storageServiceProvider);
    final allLogs = <Map<String, String>>[];

    // Implementation detail.
    try {
      final logsJson =
          storage.getSetting('script_logs', defaultValue: '[]') as String;
      final List<dynamic> decoded = jsonDecode(logsJson);
      for (final e in decoded) {
        allLogs.add(Map<String, String>.from(e as Map));
      }
    } catch (_) {}

    // Implementation detail.
    try {
      const channel = MethodChannel('com.yl.aigg/bridge');
      channel
          .invokeMethod('getOverlayScriptLogs')
          .then((result) {
            if (result != null && result is List) {
              for (final log in result) {
                if (log is Map) {
                  final logMap = Map<String, String>.from(log);
                  // Implementation detail.
                  final exists = allLogs.any(
                    (l) => l['name'] == logMap['name'],
                  );
                  if (!exists) {
                    allLogs.add(logMap);
                  }
                }
              }
            }
            // Implementation detail.
            allLogs.sort(
              (a, b) => (b['time'] ?? '').compareTo(a['time'] ?? ''),
            );
            ref.read(scriptLogsProvider.notifier).state = allLogs;
          })
          .catchError((_) {
            allLogs.sort(
              (a, b) => (b['time'] ?? '').compareTo(a['time'] ?? ''),
            );
            ref.read(scriptLogsProvider.notifier).state = allLogs;
          });
    } catch (_) {
      allLogs.sort((a, b) => (b['time'] ?? '').compareTo(a['time'] ?? ''));
      ref.read(scriptLogsProvider.notifier).state = allLogs;
    }
  }

  /// SaveRun log
  Future<void> _saveLog(String scriptName, String output) async {
    final storage = ref.read(storageServiceProvider);
    final now = DateTime.now();
    final timeStr =
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}';
    final logName = '${timeStr}_$scriptName';

    final currentLogs = ref.read(scriptLogsProvider);
    final newLog = {
      'name': logName,
      'scriptName': scriptName,
      'time': now.toIso8601String(),
      'output': output,
    };
    final updatedLogs = [newLog, ...currentLogs];
    ref.read(scriptLogsProvider.notifier).state = updatedLogs;

    // Implementation detail.
    await storage.saveSetting('script_logs', jsonEncode(updatedLogs));
  }

  /// RunScript
  Future<void> _runScript(ScriptModel script) async {
    if (_isRunning) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('⚠️ A script is already running')));
      return;
    }

    setState(() {
      _isRunning = true;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('🚀 Running: ${script.name}')));

    try {
      const channel = MethodChannel('com.yl.aigg/bridge');
      final result = await channel.invokeMethod('executeLuaScript', {
        'scriptId': script.id,
        'scriptContent': script.content,
      });

      final output = result?.toString() ?? 'Execution complete';

      // Implementation detail.
      await _saveLog(script.name, output);

      // Implementation detail.
      final scripts = ref.read(scriptsProvider);
      final updatedScripts = scripts.map((s) {
        if (s.id == script.id) {
          return s.copyWith(
            executionCount: s.executionCount + 1,
            lastExecutedAt: DateTime.now(),
          );
        }
        return s;
      }).toList();
      ref.read(scriptsProvider.notifier).state = updatedScripts;

      setState(() {
        _isRunning = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('✅ ${script.name} completed; log saved')));
      }
    } catch (e) {
      final errorOutput = 'Execution failed: $e';
      await _saveLog(script.name, errorOutput);

      setState(() {
        _isRunning = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Execution failed: $e')));
      }
    }
  }

  /// Documentation.
  void _refresh() {
    _loadScripts();
    _loadLogs();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Script list and run log refreshed'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scripts = ref.watch(scriptsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.code, color: Color(0xFF3D5AFE)),
            SizedBox(width: 8),
            Text('Script Library'),
          ],
        ),
        actions: [
          // Script Run Logbutton
          IconButton(
            icon: const Icon(Icons.receipt_long),
            tooltip: 'Script Run Log',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ScriptLogPage()),
              );
            },
          ),
          // refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh script list',
            onPressed: _refresh,
          ),
          // Implementation detail.
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Create new script',
            onPressed: () {
              _showCreateScriptDialog();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Runstatus
          if (_isRunning)
            Container(
              padding: const EdgeInsets.all(12),
              color: const Color(0xFFFFFFFF),
              child: const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('Script is running...', style: TextStyle(color: Colors.orange)),
                ],
              ),
            ),
          // Implementation detail.
          Expanded(
            child: scripts.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.code_off, size: 64, color: Color(0xFF4A6572)),
                        SizedBox(height: 16),
                        Text('No scripts', style: TextStyle(color: Color(0xFF4A6572))),
                        SizedBox(height: 8),
                        Text(
                          'Tap + in the upper-right to create a script',
                          style: TextStyle(color: Color(0xFF4A6572), fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: scripts.length,
                    itemBuilder: (context, index) {
                      return _buildScriptCard(scripts[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildScriptCard(ScriptModel script) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          _showScriptDetail(script);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    script.isBuiltin
                        ? Icons.inventory_2
                        : script.isAiGenerated
                        ? Icons.smart_toy
                        : Icons.person,
                    color: script.isBuiltin
                        ? const Color(0xFF536DFE)
                        : script.isAiGenerated
                        ? const Color(0xFF3D5AFE)
                        : Color(0xFF4A6572),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      script.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  PopupMenuButton(
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'run',
                        child: Row(
                          children: [
                            Icon(Icons.play_arrow, size: 16),
                            SizedBox(width: 8),
                            Text('Run'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 16),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      if (!script.isBuiltin)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 16, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                    ],
                    onSelected: (value) {
                      switch (value) {
                        case 'run':
                          _runScript(script);
                          break;
                        case 'edit':
                          _showScriptEditor(script);
                          break;
                        case 'delete':
                          _deleteScript(script);
                          break;
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                script.description,
                style: const TextStyle(color: Color(0xFF4A6572), fontSize: 13),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ...script.tags.map(
                    (tag) => Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3D5AFE).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF3D5AFE),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (script.executionCount > 0)
                    Text(
                      'Executed ${script.executionCount} times',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF4A6572)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showScriptDetail(ScriptModel script) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF2F3F8),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Color(0xFF4A6572),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      script.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _runScript(script);
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Run'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F3F8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: SelectableText(
                    script.content,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: Color(0xFF536DFE),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showScriptEditor(ScriptModel? script) {
    final nameController = TextEditingController(text: script?.name ?? '');
    final descController = TextEditingController(
      text: script?.description ?? '',
    );
    final contentController = TextEditingController(
      text: script?.content ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFFFFF),
        title: Text(script == null ? 'Create Script' : 'Edit Script'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Script name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentController,
                decoration: const InputDecoration(
                  labelText: 'Lua code',
                  alignLabelWithHint: true,
                ),
                maxLines: 10,
                minLines: 5,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final desc = descController.text.trim();
              final content = contentController.text.trim();

              if (name.isEmpty) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Enter a script name')));
                return;
              }
              if (content.isEmpty) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Enter script content')));
                return;
              }

              final storage = ref.read(storageServiceProvider);
              final scripts = ref.read(scriptsProvider);

              if (script != null) {
                final updated = script.copyWith(
                  name: name,
                  description: desc,
                  content: content,
                  updatedAt: DateTime.now(),
                );
                ref.read(scriptsProvider.notifier).state = scripts.map((s) {
                  return s.id == script.id ? updated : s;
                }).toList();
                await storage.saveScript(updated);
              } else {
                final newScript = ScriptModel(
                  id: 'user_${DateTime.now().millisecondsSinceEpoch}',
                  name: name,
                  description: desc,
                  content: content,
                );
                ref.read(scriptsProvider.notifier).state = [
                  ...scripts,
                  newScript,
                ];
                await storage.saveScript(newScript);
              }

              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('✅ Script saved: $name')));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showCreateScriptDialog() {
    _showScriptEditor(null);
  }

  void _deleteScript(ScriptModel script) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFFFFF),
        title: const Text('DeleteScript'),
        content: Text('Delete "${script.name}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final scripts = ref.read(scriptsProvider);
              ref.read(scriptsProvider.notifier).state = scripts
                  .where((s) => s.id != script.id)
                  .toList();
              final storage = ref.read(storageServiceProvider);
              await storage.deleteScript(script.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // Implementation detail.

  static const String _builtinTestScript = '''
-- ============================================
-- game modifier Lua test script
-- Script implementation detail.
-- ============================================

-- Script implementation detail.
function searchData(value, valueType)
    gg.clearResults()
    gg.searchNumber(value, valueType)
    local count = gg.getResultCount()
    gg.toast("Search complete; found " .. count .. " results")
    return count
end

-- Script implementation detail.
function menu1_search()
    local choice = gg.choice({
        " Search integer 9999",
        " Search float 1.0",
        " Search double 3.14"
    }, nil, "【Value search】Choose a search type")

    if choice == nil then
        gg.toast("Cancelled")
        return
    end

    if choice == 1 then
        searchData(9999, gg.TYPE_DWORD)
        gg.toast("Search integer 9999 complete")
    elseif choice == 2 then
        searchData("1.0", gg.TYPE_FLOAT)
        gg.toast("Search float 1.0 complete")
    elseif choice == 3 then
        searchData("3.14", gg.TYPE_DOUBLE)
        gg.toast("Search double 3.14 complete")
    end
end

-- Script implementation detail.
function menu2_advanced()
    local choice = gg.choice({
        " Change search results to 88888",
        " Freeze current results",
        " Clear all results"
    }, nil, "【Advanced operations】Choose an operation")

    if choice == nil then
        gg.toast("Cancelled")
        return
    end

    if choice == 1 then
        local count = gg.getResultCount()
        if count > 0 then
            local results = gg.getResults(count)
            for i, v in ipairs(results) do
                results[i].value = 88888
                results[i].flags = gg.TYPE_DWORD
            end
            gg.setValues(results)
            gg.toast("Updated " .. count .. " items to 88888")
        else
            gg.toast("No search results,search first")
        end
    elseif choice == 2 then
        local count = gg.getResultCount()
        if count > 0 then
            local results = gg.getResults(count)
            for i, v in ipairs(results) do
                results[i].freeze = true
            end
            gg.addListItems(results)
            gg.toast("Froze " .. count .. " items")
        else
            gg.toast("No search results,search first")
        end
    elseif choice == 3 then
        gg.clearResults()
        gg.clearList()
        gg.toast("All results and frozen addresses cleared")
    end
end

-- Script implementation detail.
function mainMenu()
    while true do
        local main = gg.choice({
            " Value search",
            " Advanced operations",
            " Exit script"
        }, nil, "=== Lua test script v1.0 ===")

        if main == nil or main == 3 then
            gg.toast("Script exited")
            break
        elseif main == 1 then
            menu1_search()
        elseif main == 2 then
            menu2_advanced()
        end
    end
end

-- Script implementation detail.
gg.toast("Lua test script loaded ")
gg.sleep(1000)
mainMenu()
''';
}

/// Documentation.
class ScriptLogPage extends ConsumerStatefulWidget {
  const ScriptLogPage({super.key});

  @override
  ConsumerState<ScriptLogPage> createState() => _ScriptLogPageState();
}

class _ScriptLogPageState extends ConsumerState<ScriptLogPage> {
  @override
  Widget build(BuildContext context) {
    final logs = ref.watch(scriptLogsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.receipt_long, color: Color(0xFF3D5AFE)),
            SizedBox(width: 8),
            Text('Script Run Log'),
          ],
        ),
        actions: [
          // Clear logs
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear all logs',
            onPressed: logs.isEmpty
                ? null
                : () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: const Color(0xFFFFFFFF),
                        title: const Text('Clear logs'),
                        content: const Text('Clear all run logs?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      ref.read(scriptLogsProvider.notifier).state = [];
                      final storage = ref.read(storageServiceProvider);
                      await storage.saveSetting('script_logs', '[]');
                    }
                  },
          ),
        ],
      ),
      body: logs.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 64, color: Color(0xFF4A6572)),
                  SizedBox(height: 16),
                  Text('No run logs', style: TextStyle(color: Color(0xFF4A6572))),
                  SizedBox(height: 8),
                  Text(
                    'Logs are saved after running a script',
                    style: TextStyle(color: Color(0xFF4A6572), fontSize: 12),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: logs.length,
              itemBuilder: (context, index) {
                final log = logs[index];
                return _buildLogCard(log);
              },
            ),
    );
  }

  Widget _buildLogCard(Map<String, String> log) {
    final name = log['name'] ?? 'Unknown';
    final scriptName = log['scriptName'] ?? 'Unknown';
    final time = log['time'] ?? '';
    final output = log['output'] ?? '';

    // Implementation detail.
    String formattedTime = '';
    try {
      final dt = DateTime.parse(time);
      formattedTime =
          '${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      formattedTime = time;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: const Color(0xFFFFFFFF),
      child: InkWell(
        onTap: () {
          _showLogDetail(log);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.description,
                    color: Color(0xFF3D5AFE),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                    onPressed: () async {
                      final logs = ref.read(scriptLogsProvider);
                      ref.read(scriptLogsProvider.notifier).state = logs
                          .where((l) => l['name'] != name)
                          .toList();
                      final storage = ref.read(storageServiceProvider);
                      await storage.saveSetting(
                        'script_logs',
                        jsonEncode(ref.read(scriptLogsProvider)),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'Script: $scriptName',
                    style: const TextStyle(color: Color(0xFF4A6572), fontSize: 12),
                  ),
                  const Spacer(),
                  Icon(Icons.access_time, size: 12, color: Color(0xFF4A6572)),
                  const SizedBox(width: 4),
                  Text(
                    formattedTime,
                    style: TextStyle(color: Color(0xFF4A6572), fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F3F8),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  output.length > 150
                      ? '${output.substring(0, 150)}...'
                      : output,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: Color(0xFF536DFE),
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogDetail(Map<String, String> log) {
    final name = log['name'] ?? 'Unknown';
    final output = log['output'] ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF2F3F8),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Color(0xFF4A6572),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    tooltip: 'Copy log',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: output));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('✅ Log copied to clipboard')),
                      );
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F3F8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: SelectableText(
                    output,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: Color(0xFF536DFE),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
