import 'package:flutter/material.dart';

import '../i18n/strings.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.settings});

  final SettingsService settings;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.settings.userName);
    widget.settings.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.settings.removeListener(_onChange);
    _nameCtrl.dispose();
    super.dispose();
  }

  void _onChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.settings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader(label: S.language),
          RadioListTile<String>(
            value: 'zh',
            groupValue: widget.settings.language,
            onChanged: (v) =>
                v == null ? null : widget.settings.setLanguage(v),
            title: Text(S.chinese),
          ),
          RadioListTile<String>(
            value: 'en',
            groupValue: widget.settings.language,
            onChanged: (v) =>
                v == null ? null : widget.settings.setLanguage(v),
            title: Text(S.english),
          ),
          const SizedBox(height: 16),
          _SectionHeader(label: S.yourName),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _nameCtrl,
              maxLength: 30,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                helperText: S.yourNameHint,
              ),
              textCapitalization: TextCapitalization.words,
              onChanged: (v) => widget.settings.setUserName(v),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Colors.green.shade700,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
