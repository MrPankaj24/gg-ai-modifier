/// Documentation.
///
/// Documentation.
/// Documentation.
/// Documentation.

import 'dart:async';
import 'package:flutter/services.dart';
import '../models/memory_result.dart';
import '../models/process_info.dart';

/// Documentation.
/// Documentation.
class NativeBridge {
  static const MethodChannel _channel = MethodChannel('com.yl.aigg/bridge');

  static NativeBridge? _instance;
  static NativeBridge get instance => _instance ??= NativeBridge._();

  NativeBridge._();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Documentation.
  Future<bool> initialize() async {
    try {
      _channel.setMethodCallHandler(_handleMethodCall);
      _isInitialized = true;
      return true;
    } catch (e) {
      print('NativeBridge initialization failed: $e');
      return false;
    }
  }

  /// Documentation.
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onMemoryChanged':
        // Implementation detail.
        break;
      case 'onProcessDied':
        // Implementation detail.
        break;
      default:
        throw MissingPluginException('Method not implemented: ${call.method}');
    }
  }

  // Implementation detail.

  /// Documentation.
  Future<List<ProcessInfo>> getProcessList() async {
    try {
      final result = await _channel.invokeMethod('getProcessList');
      if (result == null) return [];

      final List<dynamic> list = result as List<dynamic>;
      return list.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return ProcessInfo.fromJson(map);
      }).toList();
    } catch (e) {
      print('Failed to get process list: $e');
      return [];
    }
  }

  /// Documentation.
  Future<bool> attachProcess(int pid) async {
    try {
      final result = await _channel.invokeMethod('attachProcess', {'pid': pid});
      return result == true;
    } catch (e) {
      print('Failed to attach to process: $e');
      return false;
    }
  }

  /// Detachcurrent process
  Future<bool> detachProcess() async {
    try {
      final result = await _channel.invokeMethod('detachProcess');
      return result == true;
    } catch (e) {
      print('Detachprocess failed : $e');
      return false;
    }
  }

  /// Documentation.
  Future<int?> getAttachedPid() async {
    try {
      final result = await _channel.invokeMethod('getAttachedPid');
      return result as int?;
    } catch (e) {
      return null;
    }
  }

  // ==================== Memory search ====================

  /// ExactSearchmemory
  Future<List<MemoryResult>> searchExact(dynamic value, DataType type) async {
    try {
      final result = await _channel.invokeMethod('searchExact', {
        'value': value,
        'type': type.name,
      });
      if (result == null) return [];

      final List<dynamic> list = result as List<dynamic>;
      return list.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return MemoryResult.fromJson(map);
      }).toList();
    } catch (e) {
      print('ExactSearch failed: $e');
      return [];
    }
  }

  /// Documentation.
  Future<List<MemoryResult>> filterResults(
    List<MemoryResult> previousResults,
    dynamic newValue,
    DataType type,
  ) async {
    try {
      final result = await _channel.invokeMethod('filterResults', {
        'previousAddresses': previousResults.map((r) => r.addressInt).toList(),
        'value': newValue,
        'type': type.name,
      });
      if (result == null) return [];

      final List<dynamic> list = result as List<dynamic>;
      return list.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return MemoryResult.fromJson(map);
      }).toList();
    } catch (e) {
      print('Filtering results failed: $e');
      return [];
    }
  }

  /// RangeSearch
  Future<List<MemoryResult>> searchByRange(
    int minValue,
    int maxValue,
    DataType type,
  ) async {
    try {
      final result = await _channel.invokeMethod('searchByRange', {
        'minValue': minValue,
        'maxValue': maxValue,
        'type': type.name,
      });
      if (result == null) return [];

      final List<dynamic> list = result as List<dynamic>;
      return list.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return MemoryResult.fromJson(map);
      }).toList();
    } catch (e) {
      print('RangeSearch failed: $e');
      return [];
    }
  }

  /// FuzzySearch (Unknownvalue Search)
  /// comparison: changed, unchanged, increased, decreased, greater, less, equal, not_equal
  Future<List<MemoryResult>> searchFuzzy(
    String comparison,
    DataType type,
  ) async {
    try {
      final result = await _channel.invokeMethod('searchFuzzy', {
        'comparison': comparison,
        'type': type.name,
      });
      if (result == null) return [];

      final List<dynamic> list = result as List<dynamic>;
      return list.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return MemoryResult.fromJson(map);
      }).toList();
    } catch (e) {
      print('FuzzySearch failed: $e');
      return [];
    }
  }

  /// SignatureSearch (AOB Scan)
  Future<List<MemoryResult>> searchAob(String pattern, {String? mask}) async {
    try {
      final result = await _channel.invokeMethod('searchAob', {
        'pattern': pattern,
        'mask': mask,
      });
      if (result == null) return [];

      final List<dynamic> list = result as List<dynamic>;
      return list.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return MemoryResult.fromJson(map);
      }).toList();
    } catch (e) {
      print('SignatureSearch failed: $e');
      return [];
    }
  }

  /// Documentation.
  Future<List<MemoryResult>> relocateAob() async {
    try {
      final result = await _channel.invokeMethod('relocateAob');
      if (result == null) return [];

      final List<dynamic> list = result as List<dynamic>;
      return list.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return MemoryResult.fromJson(map);
      }).toList();
    } catch (e) {
      print('Signature relocation failed: $e');
      return [];
    }
  }

  // Implementation detail.

  /// read memoryvalue
  Future<dynamic> readMemory(int address, DataType type) async {
    try {
      final result = await _channel.invokeMethod('readMemory', {
        'address': address,
        'type': type.name,
      });
      return result;
    } catch (e) {
      print('read memoryfailed : $e');
      return null;
    }
  }

  /// write memoryvalue
  Future<bool> writeMemory(int address, dynamic value, DataType type) async {
    try {
      final result = await _channel.invokeMethod('writeMemory', {
        'address': address,
        'value': value,
        'type': type.name,
      });
      return result == true;
    } catch (e) {
      print('write memoryfailed : $e');
      return false;
    }
  }

  /// Documentation.
  Future<bool> writeBatch(List<WriteRequest> requests) async {
    try {
      final result = await _channel.invokeMethod('writeBatch', {
        'requests': requests.map((r) => r.toJson()).toList(),
      });
      return result == true;
    } catch (e) {
      print('Batch write failed: $e');
      return false;
    }
  }

  // ==================== memoryFreeze ====================

  /// Freezememoryaddress
  Future<bool> freezeMemory(int address, dynamic value, DataType type) async {
    try {
      final result = await _channel.invokeMethod('freezeMemory', {
        'address': address,
        'value': value,
        'type': type.name,
      });
      return result == true;
    } catch (e) {
      print('Freezememoryfailed : $e');
      return false;
    }
  }

  /// Documentation.
  Future<bool> unfreezeMemory(int address) async {
    try {
      final result = await _channel.invokeMethod('unfreezeMemory', {
        'address': address,
      });
      return result == true;
    } catch (e) {
      print('Unfreeze failed: $e');
      return false;
    }
  }

  /// Documentation.
  Future<List<MemoryResult>> getFrozenAddresses() async {
    try {
      final result = await _channel.invokeMethod('getFrozenAddresses');
      if (result == null) return [];

      final List<dynamic> list = result as List<dynamic>;
      return list.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return MemoryResult.fromJson(map);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // Implementation detail.

  /// Documentation.
  Future<List<MemoryRegion>> getMemoryRegions() async {
    try {
      final result = await _channel.invokeMethod('getMemoryRegions');
      if (result == null) return [];

      final List<dynamic> list = result as List<dynamic>;
      return list.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return MemoryRegion.fromJson(map);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Documentation.
  Future<Map<String, dynamic>> analyzeMemoryRegion(
    int address, {
    int range = 256,
  }) async {
    try {
      final result = await _channel.invokeMethod('analyzeMemoryRegion', {
        'address': address,
        'range': range,
      });
      return Map<String, dynamic>.from(result as Map? ?? {});
    } catch (e) {
      return {};
    }
  }

  // ==================== Root Permission ====================

  /// Documentation.
  Future<bool> checkRootAccess() async {
    try {
      final result = await _channel.invokeMethod('checkRootAccess');
      return result == true;
    } catch (e) {
      return false;
    }
  }

  /// Documentation.
  Future<bool> requestRootAccess() async {
    try {
      final result = await _channel.invokeMethod('requestRootAccess');
      return result == true;
    } catch (e) {
      return false;
    }
  }

  /// Documentation.
  void dispose() {
    _isInitialized = false;
  }
}
