/// Documentation.
/// Documentation.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/process_info.dart';

/// Documentation.
final attachedProcessProvider = StateProvider<ProcessInfo?>((ref) => null);

/// Documentation.
final processListProvider = StateProvider<List<ProcessInfo>>((ref) => []);

/// Documentation.
class ProcessSelectorPage extends ConsumerStatefulWidget {
  const ProcessSelectorPage({super.key});

  @override
  ConsumerState<ProcessSelectorPage> createState() =>
      _ProcessSelectorPageState();
}

class _ProcessSelectorPageState extends ConsumerState<ProcessSelectorPage> {
  bool _isLoading = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProcessList();
    _checkAttachedProcess();
  }

  Future<void> _checkAttachedProcess() async {
    try {
      const channel = MethodChannel('com.yl.aigg/bridge');
      final pid = await channel.invokeMethod('getAttachedPid');

      if (pid != null && pid > 0 && mounted) {
        // Implementation detail.
        final result = await channel.invokeMethod('getProcessList');
        if (result != null) {
          final List<dynamic> list = result as List<dynamic>;
          final processes = list.map((item) {
            final map = Map<String, dynamic>.from(item as Map);
            return ProcessInfo.fromJson(map);
          }).toList();

          // Implementation detail.
          final attachedProcess = processes.firstWhere(
            (p) => p.pid == pid,
            orElse: () => processes.first,
          );

          if (mounted) {
            ref.read(attachedProcessProvider.notifier).state = attachedProcess;
          }
        }
      }
    } catch (e) {
      // Implementation detail.
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProcessList() async {
    setState(() => _isLoading = true);

    try {
      const channel = MethodChannel('com.yl.aigg/bridge');
      final result = await channel.invokeMethod('getProcessList');

      if (result != null && mounted) {
        final List<dynamic> list = result as List<dynamic>;
        final processes = list.map((item) {
          final map = Map<String, dynamic>.from(item as Map);
          return ProcessInfo.fromJson(map);
        }).toList();

        // Implementation detail.
        final appProcesses = processes
            .where(
              (p) =>
                  !p.isSystem &&
                  p.packageName.isNotEmpty &&
                  !p.packageName.startsWith('com.android.') &&
                  !p.packageName.startsWith('android.') &&
                  p.packageName != 'system' &&
                  p.packageName != 'zygote' &&
                  p.packageName != 'zygote64' &&
                  p.packageName.contains('.'),
            )
            .toList();

        if (mounted) {
          ref.read(processListProvider.notifier).state = appProcesses;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to get process list: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _attachProcess(ProcessInfo process) async {
    try {
      const channel = MethodChannel('com.yl.aigg/bridge');
      final result = await channel.invokeMethod('attachProcess', {
        'pid': process.pid,
      });

      if (result == true && mounted) {
        ref.read(attachedProcessProvider.notifier).state = process;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Attached to ${process.displayName}')),
        );
        Navigator.pop(context, process);
      } else if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('❌ Failed to attach to process')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Failed to attach to process: $e')));
      }
    }
  }

  List<ProcessInfo> get _filteredProcesses {
    final processes = ref.read(processListProvider);
    if (_searchQuery.isEmpty) return processes;
    return processes
        .where(
          (p) =>
              p.displayName.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ||
              p.packageName.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final attachedProcess = ref.watch(attachedProcessProvider);
    final processes = ref.watch(processListProvider);
    final filteredProcesses = _filteredProcesses;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select game process'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadProcessList,
          ),
        ],
      ),
      body: Column(
        children: [
          // Implementation detail.
          if (attachedProcess != null)
            Container(
              padding: const EdgeInsets.all(12),
              color: const Color(0xFFFFFFFF),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Currently attached: ${attachedProcess.displayName}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${attachedProcess.packageName} (PID: ${attachedProcess.pid})',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF4A6572),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      try {
                        const channel = MethodChannel('com.yl.aigg/bridge');
                        await channel.invokeMethod('detachProcess');
                        ref.read(attachedProcessProvider.notifier).state = null;
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Process detached')),
                          );
                        }
                      } catch (_) {}
                    },
                    child: const Text(
                      'Detach',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),

          // Implementation detail.
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search game name or package name...',
                prefixIcon: const Icon(Icons.search, size: 16),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),

          // Implementation detail.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Text(
                  'Found ${filteredProcesses.length} app processes',
                  style: const TextStyle(color: Color(0xFF4A6572), fontSize: 12),
                ),
                const Spacer(),
                if (_isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Implementation detail.
          Expanded(
            child: _isLoading && processes.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Scanning processes...', style: TextStyle(color: Color(0xFF4A6572))),
                      ],
                    ),
                  )
                : filteredProcesses.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.apps, size: 64, color: Color(0xFF4A6572)),
                        SizedBox(height: 16),
                        Text('No app processes found', style: TextStyle(color: Color(0xFF4A6572))),
                        SizedBox(height: 8),
                        Text(
                          'Make sure the game is open',
                          style: TextStyle(color: Color(0xFF4A6572), fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredProcesses.length,
                    itemBuilder: (context, index) {
                      final process = filteredProcesses[index];
                      final isAttached = attachedProcess?.pid == process.pid;

                      return ListTile(
                        leading: Icon(
                          isAttached ? Icons.check_circle : Icons.apps,
                          color: isAttached
                              ? Colors.green
                              : const Color(0xFF3D5AFE),
                        ),
                        title: Text(
                          process.displayName,
                          style: TextStyle(
                            fontWeight: isAttached
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          '${process.packageName}  |  PID: ${process.pid}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF4A6572),
                          ),
                        ),
                        trailing: isAttached
                            ? const Chip(
                                label: Text(
                                  'Attached',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF213333),
                                  ),
                                ),
                                backgroundColor: Colors.green,
                                padding: EdgeInsets.zero,
                              )
                            : const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: isAttached
                            ? null
                            : () => _attachProcess(process),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
