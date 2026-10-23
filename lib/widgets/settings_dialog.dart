import 'package:flutter/material.dart';

import '../models/ai_provider.dart';
import '../models/ai_settings.dart';
import '../state/app_scope.dart';

/// Dialog for configuring the AI provider.
///
/// The API key is masked and never persisted unless the user explicitly opts
/// in.
class SettingsDialog extends StatefulWidget {
  /// Creates the dialog.
  const SettingsDialog({super.key});

  /// Shows the dialog and returns once it is closed.
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => const SettingsDialog(),
    );
  }

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late final TextEditingController _apiKeyController;
  late final TextEditingController _modelController;
  late final TextEditingController _baseUrlController;

  late String _providerId;
  late bool _persistApiKey;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    final settings = AppScope.read(context).settings;
    _providerId = settings.providerId;
    _persistApiKey = settings.persistApiKey;
    _apiKeyController = TextEditingController(text: settings.apiKey);
    _modelController = TextEditingController(
      text: settings.modelOverride ?? '',
    );
    _baseUrlController = TextEditingController(
      text: settings.baseUrlOverride ?? '',
    );
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _modelController.dispose();
    _baseUrlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final state = AppScope.read(context);
    // Grabbed before the await and before the dialog closes: once it is
    // popped its context is no longer part of the tree, so looking either up
    // afterwards would throw.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final provider = AiProviderCatalog.byId(_providerId);

    final settings = AiSettings(
      providerId: _providerId,
      apiKey: _apiKeyController.text.trim(),
      baseUrlOverride: _normalise(_baseUrlController.text),
      modelOverride: _normalise(_modelController.text),
      persistApiKey: _persistApiKey,
    );

    await state.updateSettings(settings);

    if (!mounted) return;
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text('${provider.label} settings saved.'),
        backgroundColor: const Color(0xFF3D7BFF),
      ),
    );
  }

  static String? _normalise(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final provider = AiProviderCatalog.byId(_providerId);

    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: const Text(
        'AI SETTINGS',
        style: TextStyle(color: Colors.white, letterSpacing: 1.5),
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PROVIDER',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(13),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _providerId,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1E1E1E),
                    items: AiProviderCatalog.all
                        .map(
                          (p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(
                              p.label,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _providerId = value);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                provider.description,
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
              const SizedBox(height: 20),
              if (provider.requiresApiKey) ...[
                const Text(
                  'API KEY',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _apiKeyController,
                  obscureText: _obscureKey,
                  autocorrect: false,
                  enableSuggestions: false,
                  maxLength: 512,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'API KEY',
                    labelStyle: const TextStyle(color: Colors.white54),
                    counterStyle: const TextStyle(color: Colors.white24),
                    suffixIcon: IconButton(
                      tooltip: _obscureKey ? 'Show API key' : 'Hide API key',
                      icon: Icon(
                        _obscureKey
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.white54,
                      ),
                      onPressed: () =>
                          setState(() => _obscureKey = !_obscureKey),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white10),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF3D7BFF)),
                    ),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Remember this key on this device',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  subtitle: const Text(
                    'Off by default. The key is kept in memory for this session '
                    'only.',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                  value: _persistApiKey,
                  activeThumbColor: const Color(0xFF3D7BFF),
                  onChanged: (value) =>
                      setState(() => _persistApiKey = value),
                ),
              ] else
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.greenAccent.withAlpha(60)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock_open, color: Colors.greenAccent, size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'This provider needs no API key. It works the moment '
                          'you press GENERATE WRAP. The free tier allows one '
                          'image every 45 seconds.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              const Text(
                'MODEL (OPTIONAL)',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _modelController,
                autocorrect: false,
                enableSuggestions: false,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: provider.model,
                  hintStyle: const TextStyle(color: Colors.white24),
                  helperText: 'Leave empty to use ${provider.model}',
                  helperStyle: const TextStyle(color: Colors.white38),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.white10),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF3D7BFF)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'BASE URL (OPTIONAL)',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _baseUrlController,
                autocorrect: false,
                enableSuggestions: false,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: provider.baseUrl,
                  hintStyle: const TextStyle(color: Colors.white24),
                  helperText: 'Use HTTPS for secure communication',
                  helperStyle: const TextStyle(color: Colors.white38),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.white10),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF3D7BFF)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3D7BFF),
            foregroundColor: Colors.white,
          ),
          child: const Text('SAVE'),
        ),
      ],
    );
  }
}
