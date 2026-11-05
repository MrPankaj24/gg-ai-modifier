/// Documentation.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart' as genai;
import '../../core/llm/llm_config.dart';
import '../../core/llm/prompt_builder.dart';
import '../../main.dart';

/// Documentation.
final llmConfigProvider = StateProvider<LlmConfig>((ref) {
  // Implementation detail.
  final storage = ref.read(storageServiceProvider);
  final saved = storage.getLlmConfig();
  return saved ??
      const LlmConfig(baseUrl: '', apiKey: '', model: 'deepseek-chat');
});

/// Documentation.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late TextEditingController _baseUrlController;
  late TextEditingController _apiKeyController;
  late TextEditingController _modelController;
  late TextEditingController _temperatureController;
  late TextEditingController _maxTokensController;

  String _selectedPreset = 'custom';
  bool _isTesting = false;
  String? _testResult;
  AiReadDepth _selectedReadDepth = AiReadDepth.sample50;

  /// Documentation.
  final Map<String, LlmConfig> _customPresets = {};

  @override
  void initState() {
    super.initState();
    final config = ref.read(llmConfigProvider);
    _baseUrlController = TextEditingController(text: config.baseUrl);
    _apiKeyController = TextEditingController(text: config.apiKey);
    _modelController = TextEditingController(text: config.model);
    _temperatureController = TextEditingController(
      text: config.temperature.toString(),
    );
    _maxTokensController = TextEditingController(
      text: config.maxTokens.toString(),
    );

    // Implementation detail.
    final storage = ref.read(storageServiceProvider);

    // Implementation detail.
    _loadCustomPresets(storage);

    // Implementation detail.
    final savedPreset = storage.getSetting('llm_preset') as String?;
    if (savedPreset != null) {
      _selectedPreset = savedPreset;
    } else {
      _selectedPreset = _detectPreset(config);
    }

    // load Overlayauto enable Settings
    _autoStartOverlay =
        storage.getSetting('auto_start_overlay', defaultValue: false) as bool;
    if (_autoStartOverlay) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _toggleOverlay(true);
      });
    }
    // load  AI Read DepthSettings
    final depthIndex =
        storage.getSetting('ai_read_depth', defaultValue: 2) as int;
    _selectedReadDepth =
        AiReadDepth.values[depthIndex.clamp(0, AiReadDepth.values.length - 1)];
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    _temperatureController.dispose();
    _maxTokensController.dispose();
    super.dispose();
  }

  /// Documentation.
  void _loadCustomPresets(dynamic storage) {
    try {
      final json = storage.getSetting('custom_presets') as String?;
      if (json != null) {
        final Map<String, dynamic> decoded = Map<String, dynamic>.from(
          const JsonDecoder().convert(json) as Map,
        );
        for (final entry in decoded.entries) {
          _customPresets[entry.key] = LlmConfig.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          );
        }
      }
    } catch (_) {}
  }

  /// Documentation.
  void _saveCustomPresets() {
    final storage = ref.read(storageServiceProvider);
    final json = _customPresets.map(
      (key, value) => MapEntry(key, value.toJson()),
    );
    storage.saveSetting('custom_presets', const JsonEncoder().convert(json));
  }

  /// Documentation.
  String _detectPreset(LlmConfig config) {
    // Implementation detail.
    for (final entry in LlmConfig.presets.entries) {
      if (entry.value.baseUrl == config.baseUrl &&
          entry.value.model == config.model) {
        return entry.key;
      }
    }
    // Implementation detail.
    for (final entry in _customPresets.entries) {
      if (entry.value.baseUrl == config.baseUrl &&
          entry.value.model == config.model) {
        return entry.key;
      }
    }
    return 'custom';
  }

  /// Documentation.
  Map<String, LlmConfig> get _allPresets => {
    ...LlmConfig.presets,
    ..._customPresets,
  };

  void _applyPreset(String presetName) {
    if (presetName == 'custom') {
      _showAddCustomPresetDialog();
      return;
    }
    final preset = _allPresets[presetName];
    if (preset != null) {
      // Implementation detail.
      _saveCurrentPresetApiKey();
      setState(() {
        _selectedPreset = presetName;
        _baseUrlController.text = preset.baseUrl;
        _modelController.text = preset.model;
        // Implementation detail.
        final storage = ref.read(storageServiceProvider);
        final savedKey =
            storage.getSetting('preset_key_$presetName') as String?;
        _apiKeyController.text = savedKey ?? preset.apiKey;
      });
    }
  }

  /// Documentation.
  void _saveCurrentPresetApiKey() {
    final apiKey = _apiKeyController.text.trim();
    if (_selectedPreset != 'custom' && apiKey.isNotEmpty) {
      final storage = ref.read(storageServiceProvider);
      storage.saveSetting('preset_key_$_selectedPreset', apiKey);
    }
  }

  /// Documentation.
  void _showAddCustomPresetDialog() {
    final nameController = TextEditingController();
    final urlController = TextEditingController();
    final keyController = TextEditingController();
    final modelController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFFFFF),
        title: const Text('Add custom model'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  hintText: 'For example: My API',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlController,
                decoration: const InputDecoration(
                  labelText: 'API Base URL',
                  hintText: 'https://api.example.com/v1',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: keyController,
                decoration: const InputDecoration(
                  labelText: 'API Key',
                  hintText: 'sk-...',
                ),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: modelController,
                decoration: const InputDecoration(
                  labelText: 'Model name',
                  hintText: 'gpt-4o',
                ),
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
            onPressed: () {
              final name = nameController.text.trim();
              final url = urlController.text.trim();
              final key = keyController.text.trim();
              final model = modelController.text.trim();

              if (name.isEmpty || url.isEmpty || model.isEmpty) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Complete all fields')));
                return;
              }

              final keyId = 'custom_$name';
              final config = LlmConfig(baseUrl: url, apiKey: key, model: model);

              setState(() {
                _customPresets[keyId] = config;
                _selectedPreset = keyId;
                _baseUrlController.text = url;
                _apiKeyController.text = key;
                _modelController.text = model;
              });

              _saveCustomPresets();
              _saveCurrentPresetApiKey();
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// Documentation.
  void _showDeleteCustomPresetsDialog() {
    // Implementation detail.
    if (_customPresets.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFFFFFFFF),
          title: const Text('Delete custom model'),
          content: const Text('No custom models to delete.\n\nTap the "+ Add custom" button to add one.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
      return;
    }

    final selectedToDelete = <String>{};

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFFFFFFFF),
          title: const Text('Delete custom model'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _customPresets.entries.map((entry) {
                final displayName = entry.key.replaceFirst('custom_', '');
                return CheckboxListTile(
                  title: Text(displayName),
                  subtitle: Text(
                    entry.value.model,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF4A6572)),
                  ),
                  value: selectedToDelete.contains(entry.key),
                  onChanged: (value) {
                    setDialogState(() {
                      if (value == true) {
                        selectedToDelete.add(entry.key);
                      } else {
                        selectedToDelete.remove(entry.key);
                      }
                    });
                  },
                  activeColor: const Color(0xFFE53935),
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
              onPressed: selectedToDelete.isEmpty
                  ? null
                  : () {
                      final deletedCurrentPreset = selectedToDelete.contains(_selectedPreset);
                      setState(() {
                        for (final key in selectedToDelete) {
                          _customPresets.remove(key);
                        }
                      });
                      _saveCustomPresets();
                      // Implementation detail.
                      if (deletedCurrentPreset) {
                        _applyPreset('deepseek');
                        _saveConfig();
                      }
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('✅ Deleted ${selectedToDelete.length} custom models'),
                        ),
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
              ),
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
    );
  }

  void _saveConfig() {
    final config = LlmConfig(
      baseUrl: _baseUrlController.text.trim(),
      apiKey: _apiKeyController.text.trim(),
      model: _modelController.text.trim(),
      temperature: double.tryParse(_temperatureController.text) ?? 0.7,
      maxTokens: int.tryParse(_maxTokensController.text) ?? 4096,
    );

    ref.read(llmConfigProvider.notifier).state = config;

    // Implementation detail.
    if (_selectedPreset.startsWith('custom_') &&
        _customPresets.containsKey(_selectedPreset)) {
      _customPresets[_selectedPreset] = config;
      _saveCustomPresets();
    }

    // Implementation detail.
    final storage = ref.read(storageServiceProvider);
    storage.saveLlmConfig(config);
    // Implementation detail.
    storage.saveSetting('llm_preset', _selectedPreset);

    // Implementation detail.
    _saveConfigToSharedPreferences(config);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('✅ Configuration saved')));
  }

  /// Documentation.
  Future<void> _saveConfigToSharedPreferences(LlmConfig config) async {
    try {
      const channel = MethodChannel('com.yl.aigg/bridge');
      await channel.invokeMethod('saveLlmConfig', {
        'baseUrl': config.baseUrl,
        'apiKey': config.apiKey,
        'model': config.model,
        'temperature': config.temperature,
        'maxTokens': config.maxTokens,
      });
    } catch (e) {
      // Implementation detail.
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final baseUrl = _baseUrlController.text.trim();
    final apiKey = _apiKeyController.text.trim();
    final model = _modelController.text.trim();

    if (baseUrl.isEmpty || apiKey.isEmpty) {
      setState(() {
        _isTesting = false;
        _testResult = '❌ Enter the API URL and key first';
      });
      return;
    }

    // Implementation detail.
    final isGemini = baseUrl.contains('generativelanguage.googleapis.com');

    try {
      if (isGemini) {
        // Implementation detail.
        await _testGeminiConnection(apiKey, model);
      } else {
        // Implementation detail.
        await _testOpenAIConnection(baseUrl, apiKey, model);
      }
    } catch (e) {
      setState(() {
        if (e.toString().contains('TimeoutException')) {
          _testResult = '❌ Connection timed out; check your network';
        } else if (e.toString().contains('SocketException')) {
          _testResult = '❌ Network unavailable; check your network connection\n\nIf you use a VPN, make sure it is enabled';
        } else {
          _testResult = '❌ Connection failed: $e';
        }
      });
    } finally {
      setState(() {
        _isTesting = false;
      });
    }
  }

  /// Documentation.
  Future<void> _testGeminiConnection(String apiKey, String model) async {
    try {
      // Implementation detail.
      final uri = Uri.parse('https://generativelanguage.googleapis.com/v1beta/openai/chat/completions');
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode({
              'model': model,
              'messages': [
                {'role': 'user', 'content': 'Hi'},
              ],
              'max_tokens': 5,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['choices'] != null) {
          setState(() {
            _testResult = '✅ Gemini Connected! Model: $model';
          });
        } else {
          setState(() {
            _testResult = '⚠️ Gemini Unexpected response format';
          });
        }
      } else if (response.statusCode == 404) {
        setState(() {
          _testResult = '❌ 404 error \n\nURL: ${uri.toString()}\n\nResponse: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}';
        });
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        setState(() {
          _testResult = '❌ Invalid API key (${response.statusCode})';
        });
      } else {
        setState(() {
          _testResult = '❌ Request failed (${response.statusCode}): ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}';
        });
      }
    } catch (e) {
      setState(() {
        if (e.toString().contains('TimeoutException')) {
          _testResult = '❌ Connection timed out; check your network';
        } else if (e.toString().contains('SocketException')) {
          _testResult = '❌ Network unavailable\n\nIf you use a VPN, make sure it is enabled';
        } else {
          _testResult = '❌ Connection failed: $e';
        }
      });
    }
  }

  /// Documentation.
  Future<void> _testOpenAIConnection(String baseUrl, String apiKey, String model) async {
    final uri = Uri.parse('$baseUrl/chat/completions');
    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            'model': model,
            'messages': [
              {'role': 'user', 'content': 'Hi'},
            ],
            'max_tokens': 5,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['choices'] != null) {
        setState(() {
          _testResult = '✅ Connected! Model: $model';
        });
      } else {
        setState(() {
          _testResult = '⚠️ Unexpected response format: ${response.body.substring(0, 100)}';
        });
      }
    } else if (response.statusCode == 401) {
      setState(() {
        _testResult = '❌ Invalid API key (401)';
      });
    } else if (response.statusCode == 404) {
      setState(() {
        _testResult = '❌ Model not found or API URL error  (404)';
      });
    } else {
      setState(() {
        _testResult =
            '❌ Request failed (${response.statusCode}): ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.settings, color: Color(0xFF3D5AFE)),
            SizedBox(width: 8),
            Text('Settings'),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // LLM API Configuration
          _buildSectionTitle('🤖 LLM API Configuration'),
          const SizedBox(height: 12),

          // Implementation detail.
          _buildPresetSelector(),
          const SizedBox(height: 16),

          // API address
          TextField(
            controller: _baseUrlController,
            decoration: const InputDecoration(
              labelText: 'API Base URL',
              hintText: 'https://api.deepseek.com',
              prefixIcon: Icon(Icons.link, size: 16),
            ),
          ),
          const SizedBox(height: 12),

          // API Key
          TextField(
            controller: _apiKeyController,
            decoration: const InputDecoration(
              labelText: 'API Key',
              hintText: 'sk-...',
              prefixIcon: Icon(Icons.key, size: 16),
            ),
            obscureText: true,
          ),
          const SizedBox(height: 12),

          // Model name
          TextField(
            controller: _modelController,
            decoration: const InputDecoration(
              labelText: 'Model name',
              hintText: 'deepseek-chat',
              prefixIcon: Icon(Icons.smart_toy, size: 16),
            ),
          ),
          const SizedBox(height: 12),

          // Temperature and Max tokens
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _temperatureController,
                  decoration: const InputDecoration(
                    labelText: 'Temperature',
                    hintText: '0.7',
                    prefixIcon: Icon(Icons.thermostat, size: 16),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _maxTokensController,
                  decoration: const InputDecoration(
                    labelText: 'Max tokens',
                    hintText: '4096',
                    prefixIcon: Icon(Icons.token, size: 16),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Savebutton
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saveConfig,
              icon: const Icon(Icons.save),
              label: const Text('Save Configuration'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Connection test
          _buildSectionTitle('🔗 Connection test'),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isTesting ? null : _testConnection,
              icon: _isTesting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wifi_find),
              label: Text(_isTesting ? 'Testing...' : 'Test Connection'),
            ),
          ),
          if (_testResult != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _testResult!.startsWith('✅')
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _testResult!.startsWith('✅')
                      ? Colors.green.withOpacity(0.3)
                      : Colors.red.withOpacity(0.3),
                ),
              ),
              child: Text(
                _testResult!,
                style: TextStyle(
                  color: _testResult!.startsWith('✅')
                      ? Colors.green
                      : Colors.red,
                  fontSize: 13,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),

          // AI Read Depth
          _buildSectionTitle('📊 AI Read Depth (Token optimization)'),
          const SizedBox(height: 12),
          _buildReadDepthCard(),
          const SizedBox(height: 24),

          // Overlay
          _buildSectionTitle('🎮 Overlay'),
          const SizedBox(height: 12),
          _buildOverlayCard(),
          const SizedBox(height: 24),

          // Root Permission
          _buildSectionTitle('🔐 Root Permission'),
          const SizedBox(height: 12),
          _buildRootStatusCard(),
          const SizedBox(height: 24),

          // about
          _buildSectionTitle('ℹ️ about '),
          const SizedBox(height: 12),
          _buildInfoCard(
            icon: Icons.info_outline,
            title: 'GG-AI Modifier',
            subtitle: 'Version 2.0.0 | AI-powered game memory modifier',
          ),
          const SizedBox(height: 12),
          // GitHub repository
          Card(
            child: ListTile(
              leading: const Icon(Icons.code, color: Color(0xFF3D5AFE)),
              title: const Text('GitHub repository'),
              subtitle: const Text(
                'https://github.com/yl985211/gg-ai-modifier',
                style: TextStyle(fontSize: 12, color: Color(0xFF3D5AFE)),
              ),
              trailing: const Icon(Icons.open_in_new, color: Color(0xFF4A6572)),
              onTap: () async {
                const url = 'https://github.com/yl985211/gg-ai-modifier';
                try {
                  const channel = MethodChannel('com.yl.aigg/bridge');
                  await channel.invokeMethod('openUrl', {'url': url});
                } catch (_) {}
              },
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '⚠️ This tool is for education, research, and personal single-player games only. Do not use it for online competitive games.',
                    style: TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildPresetSelector() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select API provider',
            style: TextStyle(fontSize: 13, color: Color(0xFF4A6572)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...LlmConfig.presets.entries.map((entry) {
                final isSelected = _selectedPreset == entry.key;
                final labels = {
                  'deepseek': 'DeepSeek',
                  'deepseek-reasoner': 'DeepSeek R1',
                  'xiaomi-mimo': 'Xiaomi MiMo',
                  'openai': 'OpenAI',
                  'gemini': 'Gemini',
                };
                return ChoiceChip(
                  label: Text(labels[entry.key] ?? entry.key),
                  selected: isSelected,
                  onSelected: (_) => _applyPreset(entry.key),
                  selectedColor: const Color(0xFF3D5AFE),
                );
              }),
              ..._customPresets.entries.map((entry) {
                final isSelected = _selectedPreset == entry.key;
                final displayName = entry.key.replaceFirst('custom_', '');
                return ChoiceChip(
                  label: Text(displayName),
                  selected: isSelected,
                  onSelected: (_) => _applyPreset(entry.key),
                  selectedColor: const Color(0xFF536DFE),
                );
              }),
              ActionChip(
                label: const Text('+ Add custom'),
                onPressed: () => _showAddCustomPresetDialog(),
                backgroundColor: const Color(0xFFE8EAF6),
                labelStyle: const TextStyle(color: Color(0xFF4A6572)),
              ),
              ActionChip(
                label: const Text('Delete custom'),
                onPressed: () => _showDeleteCustomPresetsDialog(),
                backgroundColor: const Color(0xFFFFEBEE),
                labelStyle: const TextStyle(color: Color(0xFFE53935)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _rootStatus = 'Not checked';
  bool _isCheckingRoot = false;

  Future<void> _checkRootAccess() async {
    setState(() {
      _isCheckingRoot = true;
      _rootStatus = 'Checking...';
    });

    try {
      const channel = MethodChannel('com.yl.aigg/bridge');
      final result = await channel.invokeMethod('checkRootAccess');
      setState(() {
        _rootStatus = result == true ? 'Root access granted ✅' : 'Root access not granted ❌';
      });
    } catch (e) {
      setState(() {
        _rootStatus = 'Check failed: $e';
      });
    } finally {
      setState(() {
        _isCheckingRoot = false;
      });
    }
  }

  Widget _buildRootStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _rootStatus.contains('✅')
                      ? Icons.check_circle
                      : Icons.security,
                  color: _rootStatus.contains('✅')
                      ? Colors.green
                      : const Color(0xFF3D5AFE),
                ),
                const SizedBox(width: 8),
                Text(
                  'Root status: $_rootStatus',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Root access is required to read and write other process memory.\nTap the button below to open the Magisk authorization prompt.',
              style: TextStyle(fontSize: 12, color: Color(0xFF4A6572)),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isCheckingRoot ? null : _checkRootAccess,
                icon: _isCheckingRoot
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: Text(_isCheckingRoot ? 'Checking...' : 'Check Root access'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _overlayEnabled = false;
  bool _autoStartOverlay = false;

  Future<void> _toggleOverlay(bool enable) async {
    try {
      const channel = MethodChannel('com.yl.aigg/bridge');
      if (enable) {
        final started = await channel.invokeMethod('startOverlay');
        setState(() {
          _overlayEnabled = started == true;
        });
        if (started != true) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Grant overlay permission')));
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('✅ Overlay enabled')));
        }
      } else {
        await channel.invokeMethod('stopOverlay');
        setState(() {
          _overlayEnabled = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Overlay disabled')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Operation failed: $e')));
    }
  }

  void _toggleAutoStart(bool value) {
    setState(() {
      _autoStartOverlay = value;
    });
    final storage = ref.read(storageServiceProvider);
    storage.saveSetting('auto_start_overlay', value);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value ? '✅ Enable overlay at startup' : 'Overlay auto-start disabled')),
    );
  }

  Widget _buildOverlayCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bubble_chart, color: Color(0xFF3D5AFE)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'In-game overlay',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Switch(
                  value: _overlayEnabled,
                  onChanged: _toggleOverlay,
                  activeColor: const Color(0xFF3D5AFE),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'When enabled, an overlay bubble appears on screen for quick access to AI chat and memory search without switching windows.',
              style: TextStyle(fontSize: 12, color: Color(0xFF4A6572)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.autorenew, size: 16, color: Color(0xFF4A6572)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Enable overlay at startup', style: TextStyle(fontSize: 13)),
                ),
                Switch(
                  value: _autoStartOverlay,
                  onChanged: _toggleAutoStart,
                  activeColor: const Color(0xFF3D5AFE),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadDepthCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.data_usage, color: Color(0xFF3D5AFE)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI Read Depth',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Limit search results sent to AI to save tokens and prevent context overflow.'
              'When there are many results, only the first N samples and statistics are sent.',
              style: TextStyle(fontSize: 12, color: Color(0xFF4A6572)),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AiReadDepth.values.map((depth) {
                final isSelected = _selectedReadDepth == depth;
                return ChoiceChip(
                  label: Text(depth.label),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() {
                      _selectedReadDepth = depth;
                    });
                    final storage = ref.read(storageServiceProvider);
                    storage.saveSetting('ai_read_depth', depth.index);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('✅ AI read depth set to: ${depth.label}')),
                    );
                  },
                  selectedColor: const Color(0xFF3D5AFE),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF3D5AFE)),
        title: Text(title),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: trailing,
      ),
    );
  }
}
