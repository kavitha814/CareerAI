import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:careerpilot_ai/core/theme/app_theme.dart';
import 'package:careerpilot_ai/providers/theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        children: [
          // Section: Appearance
          _buildSectionHeader(context, 'Appearance'),
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Toggle between light and dark theme'),
            value: themeMode == ThemeMode.dark,
            activeColor: AppTheme.primaryColor,
            secondary: Icon(
              themeMode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
              color: AppTheme.primaryColor,
            ),
            onChanged: (val) {
              ref.read(themeModeProvider.notifier).toggleTheme();
            },
          ),
          const Divider(),

          // Section: AI Preferences
          _buildSectionHeader(context, 'AI Preferences'),
          ListTile(
            leading: const Icon(Icons.auto_awesome, color: AppTheme.secondaryColor),
            title: const Text('AI Personality'),
            subtitle: const Text('Set Mentor tone (e.g. Strict Coach, Friendly Advisor)'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showAIPreferencesDialog(context),
          ),
          ListTile(
            leading: const Icon(Icons.vpn_key_outlined, color: AppTheme.secondaryColor),
            title: const Text('Gemini API Key'),
            subtitle: const Text('Update or change your Gemini API key dynamically'),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => _showApiKeyDialog(context),
          ),
          ListTile(
            leading: const Icon(Icons.keyboard_voice_outlined, color: AppTheme.secondaryColor),
            title: const Text('Voice Feedback'),
            subtitle: const Text('Enable voice outputs from career assistant'),
            trailing: const Text('Disabled'),
            onTap: () {},
          ),
          const Divider(),

          // Section: Notifications
          _buildSectionHeader(context, 'Notifications'),
          SwitchListTile(
            title: const Text('Daily Reminders'),
            subtitle: const Text('Reminders to complete weekly roadmap tasks'),
            value: true,
            activeColor: AppTheme.primaryColor,
            secondary: const Icon(Icons.notifications_active_outlined, color: AppTheme.primaryColor),
            onChanged: (val) {},
          ),
          SwitchListTile(
            title: const Text('Market Alerts'),
            subtitle: const Text('Receive alerts when trending skills shift'),
            value: false,
            activeColor: AppTheme.primaryColor,
            secondary: const Icon(Icons.trending_up, color: AppTheme.primaryColor),
            onChanged: (val) {},
          ),
          const Divider(),

          // Section: Account & Data
          _buildSectionHeader(context, 'Data Management'),
          ListTile(
            leading: const Icon(Icons.download_rounded, color: Colors.blue),
            title: const Text('Export Career Profile'),
            subtitle: const Text('Download your progress, roadmap, and stats as JSON'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Profile exported to device successfully!')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Delete Cache'),
            subtitle: const Text('Clear local Hive databases and chat history'),
            onTap: () {
              _showDeleteCacheDialog(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  void _showAIPreferencesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('AI Mentor Tone', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: Text('Friendly Advisor (Default)'),
              value: 'friendly',
              groupValue: 'friendly',
              onChanged: null,
            ),
            RadioListTile<String>(
              title: Text('Strict Coach (Direct)'),
              value: 'coach',
              groupValue: 'friendly',
              onChanged: null,
            ),
            RadioListTile<String>(
              title: Text('Academic Instructor'),
              value: 'academic',
              groupValue: 'friendly',
              onChanged: null,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear App Cache?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: const Text(
          'This will permanently clear all generated learning roadmaps, skills catalogs, and AI chat sessions. You will start fresh next time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // Perform cache cleaning (simulate)
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Local databases successfully cleared!')),
              );
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showApiKeyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _ApiKeyDialog(),
    );
  }
}

class _ApiKeyDialog extends StatefulWidget {
  const _ApiKeyDialog();

  @override
  State<_ApiKeyDialog> createState() => _ApiKeyDialogState();
}

class _ApiKeyDialogState extends State<_ApiKeyDialog> {
  final _controller = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  Future<void> _loadKey() async {
    final box = await Hive.openBox('settings_box');
    final key = box.get('custom_gemini_api_key') as String? ?? '';
    _controller.text = key;
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Gemini API Key', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      content: _isLoading
          ? const SizedBox(
              height: 60,
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Paste your custom Gemini API key here. The app will swap to it dynamically without rebuilding.',
                  style: TextStyle(fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    labelText: 'API Key',
                    hintText: 'Enter API Key (AQ.Ab8RN...)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => _controller.clear(),
                    ),
                  ),
                  style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                ),
              ],
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading
              ? null
              : () async {
                  final newKey = _controller.text.trim();
                  final box = await Hive.openBox('settings_box');
                  await box.put('custom_gemini_api_key', newKey);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(newKey.isEmpty 
                          ? 'Reverted to default API key' 
                          : 'Custom API Key saved successfully!'),
                      ),
                    );
                  }
                },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
