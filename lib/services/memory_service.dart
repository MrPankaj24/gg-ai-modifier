/// Documentation.
///
/// Documentation.

import 'dart:async';
import '../core/ffi/native_bridge.dart';
import '../core/models/memory_result.dart';

/// Documentation.
class MemoryService {
  final NativeBridge _bridge;

  /// current Search results
  List<MemoryResult> _searchResults = [];

  /// Documentation.
  final _searchResultsController =
      StreamController<List<MemoryResult>>.broadcast();

  /// Documentation.
  final Map<int, MemoryResult> _frozenAddresses = {};

  /// Documentation.
  final _frozenController = StreamController<List<MemoryResult>>.broadcast();

  MemoryService({required NativeBridge bridge}) : _bridge = bridge;

  /// Documentation.
  Stream<List<MemoryResult>> get searchResultsStream =>
      _searchResultsController.stream;

  /// Documentation.
  Stream<List<MemoryResult>> get frozenStream => _frozenController.stream;

  /// current Search results
  List<MemoryResult> get searchResults => List.unmodifiable(_searchResults);

  /// Documentation.
  List<MemoryResult> get frozenAddresses =>
      List.unmodifiable(_frozenAddresses.values);

  /// Documentation.
  int get searchResultCount => _searchResults.length;

  /// Documentation.
  int get frozenCount => _frozenAddresses.length;

  // ==================== Searchoperation  ====================

  /// ExactSearch
  Future<List<MemoryResult>> searchExact(dynamic value, DataType type) async {
    _searchResults = await _bridge.searchExact(value, type);
    _searchResultsController.add(_searchResults);
    return _searchResults;
  }

  /// Documentation.
  Future<List<MemoryResult>> filterResults(
    dynamic newValue,
    DataType type,
  ) async {
    _searchResults = await _bridge.filterResults(
      _searchResults,
      newValue,
      type,
    );
    _searchResultsController.add(_searchResults);
    return _searchResults;
  }

  /// RangeSearch
  Future<List<MemoryResult>> searchByRange(
    int minValue,
    int maxValue,
    DataType type,
  ) async {
    _searchResults = await _bridge.searchByRange(minValue, maxValue, type);
    _searchResultsController.add(_searchResults);
    return _searchResults;
  }

  /// Documentation.
  void resetSearch() {
    _searchResults = [];
    _searchResultsController.add(_searchResults);
  }

  // Implementation detail.

  /// read memoryvalue
  Future<dynamic> readMemory(int address, DataType type) async {
    return await _bridge.readMemory(address, type);
  }

  /// write memoryvalue
  Future<bool> writeMemory(int address, dynamic value, DataType type) async {
    return await _bridge.writeMemory(address, value, type);
  }

  /// Documentation.
  Future<bool> writeBatch(List<WriteRequest> requests) async {
    return await _bridge.writeBatch(requests);
  }

  // ==================== Freezeoperation  ====================

  /// Freezememoryaddress
  Future<bool> freezeMemory(int address, dynamic value, DataType type) async {
    final success = await _bridge.freezeMemory(address, value, type);
    if (success) {
      // UpdateSearch results in  of Freezestatus
      _searchResults = _searchResults.map((r) {
        if (r.addressInt == address) {
          return r.copyWith(isFrozen: true, frozenValue: value);
        }
        return r;
      }).toList();
      _searchResultsController.add(_searchResults);

      // Implementation detail.
      final result = _searchResults.firstWhere(
        (r) => r.addressInt == address,
        orElse: () => MemoryResult(
          address: '0x${address.toRadixString(16).toUpperCase()}',
          addressInt: address,
          value: value,
          type: type,
          isFrozen: true,
          frozenValue: value,
        ),
      );
      _frozenAddresses[address] = result;
      _frozenController.add(frozenAddresses);
    }
    return success;
  }

  /// Documentation.
  Future<bool> unfreezeMemory(int address) async {
    final success = await _bridge.unfreezeMemory(address);
    if (success) {
      // UpdateSearch results
      _searchResults = _searchResults.map((r) {
        if (r.addressInt == address) {
          return r.copyWith(isFrozen: false);
        }
        return r;
      }).toList();
      _searchResultsController.add(_searchResults);

      // Implementation detail.
      _frozenAddresses.remove(address);
      _frozenController.add(frozenAddresses);
    }
    return success;
  }

  /// Documentation.
  void toggleFavorite(int address) {
    _searchResults = _searchResults.map((r) {
      if (r.addressInt == address) {
        return r.copyWith(isFavorite: !r.isFavorite);
      }
      return r;
    }).toList();
    _searchResultsController.add(_searchResults);
  }

  /// Documentation.
  List<MemoryResult> get favorites =>
      _searchResults.where((r) => r.isFavorite).toList();

  // Implementation detail.

  /// Documentation.
  Future<List<MemoryRegion>> getMemoryRegions() async {
    return await _bridge.getMemoryRegions();
  }

  /// Documentation.
  Future<Map<String, dynamic>> analyzeMemoryRegion(
    int address, {
    int range = 256,
  }) async {
    return await _bridge.analyzeMemoryRegion(address, range: range);
  }

  /// Documentation.
  void dispose() {
    _searchResultsController.close();
    _frozenController.close();
  }
}
