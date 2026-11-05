/// Documentation.
///
/// Documentation.

import 'dart:async';
import '../models/script_model.dart';
import '../ffi/native_bridge.dart';

/// Documentation.
class LuaService {
  /// Documentation.
  final _executionController = StreamController<LuaExecutionEvent>.broadcast();

  LuaService({required NativeBridge bridge});

  /// Documentation.
  Stream<LuaExecutionEvent> get executionStream => _executionController.stream;

  /// Documentation.
  bool _isExecuting = false;
  bool get isExecuting => _isExecuting;

  /// Documentation.
  Future<List<ScriptModel>> loadBuiltinScripts() async {
    // Implementation detail.
    return [
      ScriptModel(
        id: 'builtin_auto_gold',
        name: 'Auto-edit coins',
        description: 'Automatically search and edit game coins',
        content: _builtinAutoGoldScript,
        isBuiltin: true,
        tags: ['coins', 'auto'],
      ),
      ScriptModel(
        id: 'builtin_auto_heal',
        name: 'Auto-heal',
        description: 'Freeze health for unlimited life',
        content: _builtinAutoHealScript,
        isBuiltin: true,
        tags: ['health', 'freeze'],
      ),
      ScriptModel(
        id: 'builtin_speed_hack',
        name: 'Speed script',
        description: 'Edit game speed',
        content: _builtinSpeedHackScript,
        isBuiltin: true,
        tags: ['speed', 'boost'],
      ),
    ];
  }

  /// execute  Lua Script
  Future<bool> executeScript(ScriptModel script) async {
    if (_isExecuting) {
      _executionController.add(
        LuaExecutionEvent(
          scriptId: script.id,
          status: LuaExecutionStatus.error,
          message: 'A script is already running',
        ),
      );
      return false;
    }

    _isExecuting = true;
    _executionController.add(
      LuaExecutionEvent(
        scriptId: script.id,
        status: LuaExecutionStatus.running,
        message: 'Running script: ${script.name}',
      ),
    );

    try {
      // Implementation detail.
      // Implementation detail.
      await Future.delayed(const Duration(seconds: 1));

      _executionController.add(
        LuaExecutionEvent(
          scriptId: script.id,
          status: LuaExecutionStatus.completed,
          message: 'ScriptExecution complete',
        ),
      );
      return true;
    } catch (e) {
      _executionController.add(
        LuaExecutionEvent(
          scriptId: script.id,
          status: LuaExecutionStatus.error,
          message: 'ScriptExecution failed: $e',
        ),
      );
      return false;
    } finally {
      _isExecuting = false;
    }
  }

  /// Documentation.
  void stopScript() {
    _isExecuting = false;
    _executionController.add(
      LuaExecutionEvent(
        scriptId: '',
        status: LuaExecutionStatus.stopped,
        message: 'Script stopped',
      ),
    );
  }

  /// Documentation.
  void dispose() {
    _executionController.close();
  }

  // Implementation detail.

  static const String _builtinAutoGoldScript = '''
-- Auto-edit coinsScript
-- Script implementation detail.

function modifyGold(targetValue)
    gg.toast("Starting coin search...")

    -- Script implementation detail.
    local currentGold = gg.prompt("Enter the current coin value:", {"0"})
    gg.searchNumber(tonumber(currentGold[1]), gg.TYPE_DWORD)

    local count = gg.getResultsCount()
    gg.toast("Found " .. count .. "  results")

    if count > 1 then
        gg.alert("Spend some coins in the game, then tap OK")
        local newGold = gg.prompt("Enter the new coin value:", {"0"})
        gg.refineNumber(tonumber(newGold[1]))

        count = gg.getResultsCount()
        gg.toast("Narrowed to " .. count .. "  results")
    end

    if count == 1 then
        local results = gg.getResults(1)
        gg.writeMemory(results[1].address, targetValue, gg.TYPE_DWORD)
        gg.toast("✅ Coins updated to " .. targetValue)
    else
        gg.alert("Could not identify an exact address; found " .. count .. "  results")
    end
end

modifyGold(999999)
''';

  static const String _builtinAutoHealScript = '''
-- Auto-healScript
-- Script implementation detail.

function freezeHealth()
    gg.toast("Starting health search...")

    local currentHealth = gg.prompt("Enter the current health value:", {"100"})
    gg.searchNumber(tonumber(currentHealth[1]), gg.TYPE_FLOAT)

    local count = gg.getResultsCount()
    gg.toast("Found " .. count .. "  results")

    if count > 1 then
        gg.alert("Take damage in the game, then tap OK")
        local newHealth = gg.prompt("Enter the health value after damage:", {"80"})
        gg.refineNumber(tonumber(newHealth[1]))

        count = gg.getResultsCount()
        gg.toast("Narrowed to " .. count .. "  results")
    end

    if count <= 5 then
        local results = gg.getResults(count)
        for i = 1, count do
            gg.freeze(results[i].address, tonumber(currentHealth[1]), gg.TYPE_FLOAT)
        end
        gg.toast("✅ Health frozen at " .. currentHealth[1])
    else
        gg.alert("Found " .. count .. "  results,Please narrow the range further")
    end
end

freezeHealth()
''';

  static const String _builtinSpeedHackScript = '''
-- Speed script
-- Script implementation detail.

function speedHack()
    local speed = gg.prompt("Enter the speed multiplier:", {"2.0"})
    local multiplier = tonumber(speed[1])

    gg.toast("Searching for speed...")

    -- Script implementation detail.
    gg.searchNumber("1.0", gg.TYPE_FLOAT)

    local count = gg.getResultsCount()
    gg.toast("Found " .. count .. "  results")

    if count > 0 and count <= 100 then
        local results = gg.getResults(count)
        for i = 1, count do
            gg.writeMemory(results[i].address, multiplier, gg.TYPE_FLOAT)
        end
        gg.toast("✅ Speed updated to " .. multiplier .. "x")
    else
        gg.alert("Too many results; use another method to identify the speed address")
    end
end

speedHack()
''';
}

/// Documentation.
class LuaExecutionEvent {
  final String scriptId;
  final LuaExecutionStatus status;
  final String message;

  const LuaExecutionEvent({
    required this.scriptId,
    required this.status,
    required this.message,
  });
}

/// Lua execute status
enum LuaExecutionStatus { running, completed, error, stopped }
