/// Documentation.
///
/// Documentation.

import '../ffi/native_bridge.dart';
import '../models/memory_result.dart';

/// Documentation.
class FunctionHandler {
  final NativeBridge _bridge;

  FunctionHandler({required NativeBridge bridge}) : _bridge = bridge;

  /// Documentation.
  List<Map<String, dynamic>> getToolDefinitions() {
    return [
      {
        'type': 'function',
        'function': {
          'name': 'search_memory',
          'description': 'Searchprocess memory in a specified value in process memory, used to find game data (coins, health, etc.) of memoryaddress .',
          'parameters': {
            'type': 'object',
            'properties': {
              'value': {'type': 'number', 'description': 'Search of Value'},
              'data_type': {
                'type': 'string',
                'enum': ['dword', 'qword', 'float', 'double', 'byte', 'word'],
                'description': 'data type; game coins and health usually use dword',
              },
            },
            'required': ['value', 'data_type'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'search_fuzzy',
          'description': 'FuzzySearch (Unknownvalue Search).Used for encrypted or changing values. The first search saves a snapshot; later searches compare changes.',
          'parameters': {
            'type': 'object',
            'properties': {
              'comparison': {
                'type': 'string',
                'enum': [
                  'changed',
                  'unchanged',
                  'increased',
                  'decreased',
                  'greater',
                  'less',
                  'equal',
                  'not_equal',
                ],
                'description':
                    'Comparison operations: changed, unchanged, increased, decreased',
              },
              'data_type': {
                'type': 'string',
                'enum': ['dword', 'qword', 'float', 'double', 'byte', 'word'],
                'description': 'data type ',
              },
            },
            'required': ['comparison', 'data_type'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'search_aob',
          'description': 'Signature search (AOB scan). Used to find specific byte patterns and supports relocation after restart.',
          'parameters': {
            'type': 'object',
            'properties': {
              'pattern': {
                'type': 'string',
                'description': 'Signature pattern (e.g.: "48 89 5C 24 ? 48 89 74 24")',
              },
            },
            'required': ['pattern'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'write_memory',
          'description': 'Write a value to a specified memory address to edit game data.',
          'parameters': {
            'type': 'object',
            'properties': {
              'address': {
                'type': 'string',
                'description': 'Memory address (hexadecimal, e.g. "0x7F3A4B2C80")',
              },
              'value': {'type': 'number', 'description': 'write  of value '},
              'data_type': {'type': 'string', 'description': 'data type '},
            },
            'required': ['address', 'value', 'data_type'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'freeze_memory',
          'description': 'Freeze a memory address value (continuous writes) to prevent automatic game changes.',
          'parameters': {
            'type': 'object',
            'properties': {
              'address': {'type': 'string', 'description': 'memoryaddress '},
              'value': {'type': 'number', 'description': 'Freeze of value '},
              'data_type': {'type': 'string', 'description': 'data type '},
            },
            'required': ['address', 'value', 'data_type'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'get_process_list',
          'description': 'Get running processes so the user can select a game to edit.',
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'attach_process',
          'description': 'Attach to a target game process; memory can be read and written after attachment.',
          'parameters': {
            'type': 'object',
            'properties': {
              'pid': {'type': 'integer', 'description': 'process  ID'},
              'package_name': {'type': 'string', 'description': 'app package name'},
            },
            'required': ['package_name'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'analyze_memory_region',
          'description': 'Analyze the memory region around an address to help identify its data structure.',
          'parameters': {
            'type': 'object',
            'properties': {
              'address': {'type': 'string', 'description': 'memoryaddress '},
              'range': {
                'type': 'integer',
                'description': 'Analyze a range (bytes before and after); default 256',
                'default': 256,
              },
            },
            'required': ['address'],
          },
        },
      },
    ];
  }

  /// Documentation.
  Future<dynamic> executeFunction(
    String functionName,
    Map<String, dynamic> arguments,
  ) async {
    switch (functionName) {
      case 'search_memory':
        return _searchMemory(arguments);
      case 'search_fuzzy':
        return _searchFuzzy(arguments);
      case 'search_aob':
        return _searchAob(arguments);
      case 'write_memory':
        return _writeMemory(arguments);
      case 'freeze_memory':
        return _freezeMemory(arguments);
      case 'get_process_list':
        return _getProcessList();
      case 'attach_process':
        return _attachProcess(arguments);
      case 'analyze_memory_region':
        return _analyzeMemoryRegion(arguments);
      default:
        return {'error': 'Unknown function : $functionName'};
    }
  }

  /// Searchmemory
  Future<Map<String, dynamic>> _searchMemory(Map<String, dynamic> args) async {
    final value = args['value'];
    final dataTypeStr = args['data_type'] as String;
    final type = DataType.fromString(dataTypeStr);

    final results = await _bridge.searchExact(value, type);

    return {
      'success': true,
      'count': results.length,
      'results': results.take(100).map((r) => r.toJson()).toList(),
      'message': results.isEmpty ? 'No matching memory addresses' : 'Found ${results.length} matching addresses',
    };
  }

  /// FuzzySearch
  Future<Map<String, dynamic>> _searchFuzzy(Map<String, dynamic> args) async {
    final comparison = args['comparison'] as String;
    final dataTypeStr = args['data_type'] as String;
    final type = DataType.fromString(dataTypeStr);

    final results = await _bridge.searchFuzzy(comparison, type);

    return {
      'success': true,
      'count': results.length,
      'results': results.take(100).map((r) => r.toJson()).toList(),
      'message': results.isEmpty ? 'No matching memory addresses' : 'Found ${results.length} matching addresses',
    };
  }

  /// SignatureSearch
  Future<Map<String, dynamic>> _searchAob(Map<String, dynamic> args) async {
    final pattern = args['pattern'] as String;

    final results = await _bridge.searchAob(pattern);

    return {
      'success': true,
      'count': results.length,
      'results': results.take(100).map((r) => r.toJson()).toList(),
      'message': results.isEmpty ? 'No matching signature' : 'Found ${results.length} matching addresses',
    };
  }

  /// write memory
  Future<Map<String, dynamic>> _writeMemory(Map<String, dynamic> args) async {
    final addressStr = args['address'] as String;
    final value = args['value'];
    final dataTypeStr = args['data_type'] as String;
    final type = DataType.fromString(dataTypeStr);

    // Implementation detail.
    final address = int.parse(
      addressStr.replaceFirst('0x', '').replaceFirst('0X', ''),
      radix: 16,
    );

    final success = await _bridge.writeMemory(address, value, type);

    return {
      'success': success,
      'message': success ? 'write succeeded ' : 'write failed ',
      'address': addressStr,
      'value': value,
    };
  }

  /// Freezememory
  Future<Map<String, dynamic>> _freezeMemory(Map<String, dynamic> args) async {
    final addressStr = args['address'] as String;
    final value = args['value'];
    final dataTypeStr = args['data_type'] as String;
    final type = DataType.fromString(dataTypeStr);

    final address = int.parse(
      addressStr.replaceFirst('0x', '').replaceFirst('0X', ''),
      radix: 16,
    );

    final success = await _bridge.freezeMemory(address, value, type);

    return {
      'success': success,
      'message': success ? 'Freezesucceeded ' : 'Freezefailed ',
      'address': addressStr,
    };
  }

  /// Documentation.
  Future<Map<String, dynamic>> _getProcessList() async {
    final processes = await _bridge.getProcessList();

    return {
      'success': true,
      'count': processes.length,
      'processes': processes.map((p) => p.toJson()).toList(),
    };
  }

  /// Attach Process
  Future<Map<String, dynamic>> _attachProcess(Map<String, dynamic> args) async {
    final pid = args['pid'] as int?;
    final packageName = args['package_name'] as String;

    if (pid == null) {
      return {'success': false, 'message': 'need provide process  ID (pid)'};
    }

    final success = await _bridge.attachProcess(pid);

    return {
      'success': success,
      'message': success ? 'Attached to $packageName (PID: $pid)' : 'Attach failed',
      'pid': pid,
      'package_name': packageName,
    };
  }

  /// Documentation.
  Future<Map<String, dynamic>> _analyzeMemoryRegion(
    Map<String, dynamic> args,
  ) async {
    final addressStr = args['address'] as String;
    final range = args['range'] as int? ?? 256;

    final address = int.parse(
      addressStr.replaceFirst('0x', '').replaceFirst('0X', ''),
      radix: 16,
    );

    final result = await _bridge.analyzeMemoryRegion(address, range: range);

    return {'success': true, 'address': addressStr, 'analysis': result};
  }
}
