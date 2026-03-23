import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:refilc/helpers/notification_helper.dart';
import 'package:refilc/theme/colors/colors.dart';

class NotificationDebugScreen extends StatefulWidget {
  const NotificationDebugScreen({super.key});

  @override
  State<NotificationDebugScreen> createState() =>
      _NotificationDebugScreenState();
}

class _NotificationDebugScreenState extends State<NotificationDebugScreen> {
  bool _running = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    NotificationsHelper().refreshDebugLogsFromStore();
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      NotificationsHelper().refreshDebugLogsFromStore();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _runCheckNow() async {
    if (_running) return;

    setState(() => _running = true);
    try {
      await NotificationsHelper().runDebugCheckNow();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification check finished.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Notification check failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _copyLogs(List<String> logs) async {
    await Clipboard.setData(ClipboardData(text: logs.join('\n')));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logs copied to clipboard.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Theme.of(context).scaffoldBackgroundColor,
        leading: BackButton(color: AppColors.of(context).text),
        title: Text(
          'Notification Debug Logs',
          style: TextStyle(color: AppColors.of(context).text),
        ),
      ),
      body: ValueListenableBuilder<List<String>>(
        valueListenable: NotificationsHelper().debugLogsListenable,
        builder: (context, logs, _) {
          final reversed = logs.reversed.toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _running ? null : _runCheckNow,
                        icon: _running
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.play_arrow_rounded),
                        label: Text(
                            _running ? 'Running...' : 'Run notification check'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      tooltip: 'Copy logs',
                      onPressed: logs.isEmpty ? null : () => _copyLogs(logs),
                      icon: const Icon(Icons.copy_rounded),
                    ),
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      tooltip: 'Clear logs',
                      onPressed: logs.isEmpty
                          ? null
                          : () async {
                              await NotificationsHelper().clearDebugLogs();
                            },
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: reversed.isEmpty
                    ? const Center(
                        child: Text(
                          'No debug logs yet.\nRun a notification check to collect logs.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                        itemBuilder: (context, index) {
                          final line = reversed[index];
                          return SelectableText(
                            line,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.of(context).text,
                            ),
                          );
                        },
                        separatorBuilder: (_, __) => Divider(
                          height: 14,
                          color:
                              AppColors.of(context).text.withValues(alpha: .15),
                        ),
                        itemCount: reversed.length,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
