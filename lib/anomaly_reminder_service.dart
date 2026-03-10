// anomaly_reminder_service.dart
//
// Shared reminder engine for both CoordinatorDashboard and CR DashboardPage.
//
// Usage:
//   1. Create one instance per dashboard: final _reminders = AnomalyReminderService();
//   2. Call _reminders.mount(context) once in initState.
//   3. Feed it the anomaly list every time you fetch: _reminders.onAnomaliesUpdated(list);
//   4. Call _reminders.dispose() in dispose().
//
// Reminder schedule (minutes after first_detected_at):
//   1 → 5 → 10 → 15 → 30 → 45 → 60 then stop.
//
// Each trigger: shows a full-screen popup overlay AND increments badge count.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';

/// Called by the reminder service when a new popup should be shown.
typedef ReminderPopupCallback = void Function(Map<String, dynamic> alert, int reminderNumber);

/// Called when badge count changes.
typedef BadgeUpdateCallback = void Function(int newCount);

// ─────────────────────────────────────────────────────────────────────────────

class AnomalyReminderService {
  // Reminder schedule in minutes from first_detected_at
  static const List<int> _schedule = [1, 5, 10, 15, 30, 45, 60];

  // Per-alert state: alertKey → _AlertReminderState
  final Map<String, _AlertReminderState> _states = {};

  // Timers that drive the checks
  Timer? _pollTimer;

  // Callbacks wired in by the parent widget
  ReminderPopupCallback? onShowPopup;
  BadgeUpdateCallback?   onBadgeUpdate;

  int _badgeCount = 0;
  int get badgeCount => _badgeCount;

  bool _mounted = false;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  void mount() {
    _mounted = true;
    // Check every 15 seconds whether a reminder is due
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) => _checkReminders());
  }

  void dispose() {
    _mounted = false;
    _pollTimer?.cancel();
    for (final s in _states.values) {
      s.cancelAll();
    }
    _states.clear();
  }

  // ── Feed new anomaly list from API poll ────────────────────────────────────

  void onAnomaliesUpdated(List<Map<String, dynamic>> anomalies) {
    if (!_mounted) return;

    final currentKeys = <String>{};

    for (final alert in anomalies) {
      final key = _alertKey(alert);
      currentKeys.add(key);

      if (!_states.containsKey(key)) {
        // Brand new alert — register it
        _states[key] = _AlertReminderState(
          alert: alert,
          firstDetectedAt: _parseTime(alert['first_detected_at'] ?? alert['timestamp']),
          remindersAlreadySent: (alert['reminder_count'] as int?) ?? 0,
        );
        // Immediately show popup for the very first detection
        _triggerPopup(alert, 0);
        _bumpBadge();
      } else {
        // Update power/score in case it changed
        _states[key]!.alert = alert;
      }
    }

    // Remove resolved alerts from tracking
    final removed = _states.keys.where((k) => !currentKeys.contains(k)).toList();
    for (final k in removed) {
      _states[k]!.cancelAll();
      _states.remove(k);
    }
  }

  /// Called when the user taps Resolve — stops reminders for that alert.
  void onAlertResolved(Map<String, dynamic> alert) {
    final key = _alertKey(alert);
    _states[key]?.cancelAll();
    _states.remove(key);
    _resetBadge();
  }

  /// Called when user opens the Alerts tab — clears badge.
  void onAlertsTabOpened() {
    _resetBadge();
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  void _checkReminders() {
    if (!_mounted) return;
    final now = DateTime.now().toUtc();

    for (final entry in _states.entries) {
      final state = entry.value;
      if (state.stopped) continue;

      final minutesElapsed = now.difference(state.firstDetectedAt).inSeconds / 60.0;

      // Stop after 1 hour
      if (minutesElapsed >= 60) {
        state.stopped = true;
        continue;
      }

      // Check each schedule slot
      final nextSlot = state.remindersAlreadySent; // 0-based index into _schedule
      if (nextSlot >= _schedule.length) {
        state.stopped = true;
        continue;
      }

      final dueMins = _schedule[nextSlot].toDouble();
      if (minutesElapsed >= dueMins) {
        state.remindersAlreadySent++;
        _triggerPopup(state.alert, state.remindersAlreadySent);
        _bumpBadge();
      }
    }
  }

  void _triggerPopup(Map<String, dynamic> alert, int reminderNumber) {
    if (!_mounted) return;
    onShowPopup?.call(alert, reminderNumber);
  }

  void _bumpBadge() {
    _badgeCount++;
    onBadgeUpdate?.call(_badgeCount);
  }

  void _resetBadge() {
    _badgeCount = 0;
    onBadgeUpdate?.call(0);
  }

  static String _alertKey(Map<String, dynamic> a) {
    final id = a['id'] ?? a['_id'];
    if (id != null) return id.toString();
    return '${a['device_id']}_${a['timestamp']}';
  }

  static DateTime _parseTime(dynamic raw) {
    if (raw == null) return DateTime.now().toUtc();
    try {
      return DateTime.parse(raw.toString()).toUtc();
    } catch (_) {
      return DateTime.now().toUtc();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _AlertReminderState {
  Map<String, dynamic> alert;
  final DateTime firstDetectedAt;
  int remindersAlreadySent;
  bool stopped = false;

  _AlertReminderState({
    required this.alert,
    required this.firstDetectedAt,
    required this.remindersAlreadySent,
  });

  void cancelAll() {
    stopped = true;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Popup widget — shown as an overlay dialog
// ─────────────────────────────────────────────────────────────────────────────

class AnomalyReminderPopup extends StatelessWidget {
  final Map<String, dynamic> alert;
  final int reminderNumber;
  final VoidCallback onViewAlerts;
  final Future<void> Function(Map<String, dynamic>) onResolve;

  const AnomalyReminderPopup({
    super.key,
    required this.alert,
    required this.reminderNumber,
    required this.onViewAlerts,
    required this.onResolve,
  });

  /// Show as a dialog. Returns true if the user clicked Resolve.
  static Future<bool> show(
    BuildContext context, {
    required Map<String, dynamic> alert,
    required int reminderNumber,
    required VoidCallback onViewAlerts,
    required Future<void> Function(Map<String, dynamic>) onResolve,
  }) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black54,
          builder: (_) => AnomalyReminderPopup(
            alert: alert,
            reminderNumber: reminderNumber,
            onViewAlerts: onViewAlerts,
            onResolve: onResolve,
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deviceId  = alert['device_id'] ?? 'Unknown Room';
    final power     = alert['power'] ?? '—';
    final occupancy = alert['occupancy'] ?? '—';
    final score     = alert['score'] ?? '—';

    final isFirstAlert = reminderNumber == 0;
    final reminderLabel = isFirstAlert
        ? 'New Anomaly Detected'
        : 'Reminder #$reminderNumber — Anomaly Unresolved';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.25),
              blurRadius: 30,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Red header ──────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
              decoration: const BoxDecoration(
                color: Color(0xFFD32F2F),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.warning_amber_rounded,
                        color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '⚠ Energy Anomaly Detected',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          reminderLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.of(context).pop(false),
                    tooltip: 'Dismiss (alert stays active)',
                  ),
                ],
              ),
            ),

            // ── Alert details ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _DetailRow(Icons.meeting_room_outlined, 'Room', deviceId),
                  const SizedBox(height: 10),
                  _DetailRow(Icons.bolt, 'Power', '${power}W',
                      valueColor: Colors.red.shade700),
                  const SizedBox(height: 10),
                  _DetailRow(Icons.people_outline, 'Occupancy', '$occupancy'),
                  const SizedBox(height: 10),
                  _DetailRow(Icons.analytics_outlined, 'Anomaly Score', '$score'),
                  if (!isFirstAlert) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Text(
                        'This anomaly has not been resolved. '
                        'Please investigate immediately.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // ── Action buttons ─────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop(false);
                            onViewAlerts();
                          },
                          icon: const Icon(Icons.visibility_outlined, size: 18),
                          label: const Text('View Alerts'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFD32F2F),
                            side: const BorderSide(color: Color(0xFFD32F2F)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            Navigator.of(context).pop(true);
                            await onResolve(alert);
                          },
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Resolve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow(this.icon, this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 10),
        Text('$label: ',
            style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
                fontWeight: FontWeight.w500)),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: valueColor ?? Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
