/// Documentation.

import 'dart:async';
import '../core/ffi/native_bridge.dart';
import '../core/models/process_info.dart';

/// Documentation.
class ProcessService {
  final NativeBridge _bridge;

  /// Documentation.
  ProcessInfo? _attachedProcess;

  /// Documentation.
  final _processListController =
      StreamController<List<ProcessInfo>>.broadcast();

  /// Documentation.
  final _attachStateController = StreamController<ProcessInfo?>.broadcast();

  ProcessService({required NativeBridge bridge}) : _bridge = bridge;

  /// Documentation.
  Stream<List<ProcessInfo>> get processListStream =>
      _processListController.stream;

  /// Documentation.
  Stream<ProcessInfo?> get attachStateStream => _attachStateController.stream;

  /// Documentation.
  ProcessInfo? get attachedProcess => _attachedProcess;

  /// whether Attachedprocess
  bool get isAttached => _attachedProcess != null;

  /// Documentation.
  Future<List<ProcessInfo>> getProcessList() async {
    final processes = await _bridge.getProcessList();
    _processListController.add(processes);
    return processes;
  }

  /// Documentation.
  Future<bool> attachProcess(ProcessInfo process) async {
    final success = await _bridge.attachProcess(process.pid);
    if (success) {
      _attachedProcess = process;
      _attachStateController.add(_attachedProcess);
    }
    return success;
  }

  /// Detachcurrent process
  Future<bool> detachProcess() async {
    final success = await _bridge.detachProcess();
    if (success) {
      _attachedProcess = null;
      _attachStateController.add(null);
    }
    return success;
  }

  /// Documentation.
  Future<bool> checkRootAccess() async {
    return await _bridge.checkRootAccess();
  }

  /// Documentation.
  Future<bool> requestRootAccess() async {
    return await _bridge.requestRootAccess();
  }

  /// Documentation.
  void dispose() {
    _processListController.close();
    _attachStateController.close();
  }
}
