import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/api/api_client.dart';

/// Session 7.7 (part 1) — Settings Screen
///
/// Auto-caption toggle, AI disclosure editor, posting limits,
/// response preferences, business hours, persona editor, theme toggle.

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _autoCaption = true;
  bool _biometricEnabled = false;
  int _dailyPostLimit = 5;
  int _dailyReplyLimit = 50;
  int _hourlyReplyLimit = 30;
  String _businessStart = '8:00 AM';
  String _businessEnd = '9:00 PM';
  String _aiDisclosure = 'AI-assisted post \u2022 Real content, smart delivery';
  final _disclosureCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _disclosureCtrl.text = _aiDisclosure;
    _loadBiometricPref();
  }

  Future<void> _loadBiometricPref() async {
    // Would read from flutter_secure_storage
    setState(() => _biometricEnabled = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Content generation
          _SectionHeader('Content Generation'),
          SwitchListTile(
            title: const Text('Auto-Generate Captions'),
            subtitle: const Text('AI generates captions for new posts'),
            value: _autoCaption,
            onChanged: (v) => setState(() => _autoCaption = v),
          ),
          ListTile(
            title: const Text('AI Disclosure Text'),
            subtitle: Text(_aiDisclosure, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.edit),
            onTap: _editDisclosure,
          ),

          // Posting limits
          _SectionHeader('Posting Limits'),
          ListTile(
            title: const Text('Daily Post Limit'),
            trailing: DropdownButton<int>(
              value: _dailyPostLimit,
              items: [3, 5, 10, 15, 20].map((n) => DropdownMenuItem(value: n, child: Text('$n'))).toList(),
              onChanged: (v) => setState(() => _dailyPostLimit = v ?? 5),
            ),
          ),

          // Response limits
          _SectionHeader('Auto-Response'),
          ListTile(
            title: const Text('Daily Reply Cap'),
            trailing: DropdownButton<int>(
              value: _dailyReplyLimit,
              items: [20, 30, 50, 75, 100].map((n) => DropdownMenuItem(value: n, child: Text('$n'))).toList(),
              onChanged: (v) => setState(() => _dailyReplyLimit = v ?? 50),
            ),
          ),
          ListTile(
            title: const Text('Hourly Reply Cap'),
            trailing: DropdownButton<int>(
              value: _hourlyReplyLimit,
              items: [10, 20, 30, 50].map((n) => DropdownMenuItem(value: n, child: Text('$n'))).toList(),
              onChanged: (v) => setState(() => _hourlyReplyLimit = v ?? 30),
            ),
          ),

          // Business hours
          _SectionHeader('Business Hours (MST)'),
          ListTile(
            title: const Text('DM Auto-Reply Hours'),
            subtitle: Text('$_businessStart – $_businessEnd'),
            trailing: const Icon(Icons.schedule),
          ),

          // Persona
          _SectionHeader('Persona'),
          ListTile(
            title: const Text('Voice & Tone'),
            subtitle: const Text('Edit persona configuration'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _openPersonaEditor,
          ),
          ListTile(
            title: const Text('Test Voice'),
            subtitle: const Text('Generate a test caption with your persona'),
            trailing: const Icon(Icons.play_arrow),
            onTap: _testVoice,
          ),

          // Appearance
          _SectionHeader('Appearance'),
          ListTile(
            title: const Text('Theme'),
            trailing: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode, size: 16)),
                ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode, size: 16)),
                ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.settings_brightness, size: 16)),
              ],
              selected: {themeMode},
              onSelectionChanged: (s) => ref.read(themeModeProvider.notifier).setTheme(s.first),
            ),
          ),

          // Security
          _SectionHeader('Security'),
          SwitchListTile(
            title: const Text('Face ID / Biometric Lock'),
            subtitle: const Text('Require biometrics on app launch'),
            value: _biometricEnabled,
            onChanged: (v) async {
              await ref.read(authProvider.notifier).enableBiometrics(v);
              setState(() => _biometricEnabled = v);
            },
          ),

          // Account
          _SectionHeader('Account'),
          ListTile(
            title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
            leading: const Icon(Icons.logout, color: Colors.red),
            onTap: () => ref.read(authProvider.notifier).logout(),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _editDisclosure() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('AI Disclosure Text'),
        content: TextField(
          controller: _disclosureCtrl,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Appended to AI-generated captions'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              setState(() => _aiDisclosure = _disclosureCtrl.text);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _openPersonaEditor() {
    // Navigate to persona editing screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Persona editor — coming soon')),
    );
  }

  Future<void> _testVoice() async {
    try {
      final resp = await ApiClient().post('/persona/test', data: {
        'prompt': 'Write a short Instagram caption about your morning coffee.',
        'persona_name': 'Andre',
      });
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Voice Test'),
            content: Text(resp.data['response'] ?? 'No response'),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
      child: Text(text.toUpperCase(), style: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.primary,
        letterSpacing: 1.2,
      )),
    );
  }
}
