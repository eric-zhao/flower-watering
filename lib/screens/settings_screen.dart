import 'package:flutter/material.dart';

import '../i18n/strings.dart';
import '../services/settings_service.dart';
import '../services/sync_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.settings,
    required this.syncService,
  });

  final SettingsService settings;
  final SyncService syncService;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _passcodeCtrl;
  late final TextEditingController _serverCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.settings.userName);
    _passcodeCtrl =
        TextEditingController(text: widget.settings.householdPasscode);
    _serverCtrl = TextEditingController(text: widget.settings.serverUrl);
    widget.settings.addListener(_onChange);
    widget.syncService.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.settings.removeListener(_onChange);
    widget.syncService.removeListener(_onChange);
    _nameCtrl.dispose();
    _passcodeCtrl.dispose();
    _serverCtrl.dispose();
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
          const SizedBox(height: 16),
          _SectionHeader(label: S.familySync),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _passcodeCtrl,
                  maxLength: 64,
                  decoration: InputDecoration(
                    labelText: S.householdPasscode,
                    helperText: S.householdPasscodeHint,
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (v) =>
                      widget.settings.setHouseholdPasscode(v),
                  onChanged: (v) {
                    // Save on every change so other text fields don't lose the new value.
                    widget.settings.setHouseholdPasscode(v);
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _serverCtrl,
                  decoration: InputDecoration(
                    labelText: S.serverUrl,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (v) => widget.settings.setServerUrl(v),
                ),
                const SizedBox(height: 12),
                _SyncStatusLine(syncService: widget.syncService),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonalIcon(
                    onPressed: widget.settings.syncEnabled
                        ? () => widget.syncService.runSync()
                        : null,
                    icon: const Icon(Icons.sync),
                    label: Text(S.syncNow),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncStatusLine extends StatelessWidget {
  const _SyncStatusLine({required this.syncService});
  final SyncService syncService;

  @override
  Widget build(BuildContext context) {
    final pending = syncService.queue.length;
    final last = syncService.lastWallClock;
    final status = syncService.lastStatus;
    final settings = SettingsService.instance;

    String text;
    Color color;
    IconData icon;

    if (!settings.syncEnabled) {
      text = S.notJoined;
      color = Colors.grey.shade600;
      icon = Icons.cloud_off;
    } else if (status == 'error') {
      text = S.syncFailed(syncService.lastMessage);
      color = Colors.red.shade700;
      icon = Icons.error_outline;
    } else if (pending > 0) {
      text = S.pendingChanges(pending);
      color = Colors.orange.shade700;
      icon = Icons.cloud_upload_outlined;
    } else if (last > 0) {
      final mins = ((DateTime.now().millisecondsSinceEpoch - last) / 60000)
          .floor();
      text = mins == 0 ? S.syncedJustNow : S.syncedNMinAgo(mins);
      color = Colors.green.shade700;
      icon = Icons.cloud_done_outlined;
    } else {
      text = S.notJoined;
      color = Colors.grey.shade600;
      icon = Icons.cloud_off;
    }

    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: TextStyle(color: color)),
        ),
      ],
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
