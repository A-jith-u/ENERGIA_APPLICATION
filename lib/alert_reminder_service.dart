// alert_reminder_service.dart
//
// In-app anomaly alert reminder system — no Firebase, no extra packages.
//
// ── Reminder schedule (minutes from detection moment) ───────────────────────
//   0 min  → immediate popup (alert detected)        badge += 1  ← only here
//   +3 min → Reminder #1 popup                       badge unchanged
//   +5 min → Reminder #2 popup                       badge unchanged
//   +7 min → Reminder #3 popup (final, then stops)   badge unchanged
//
// Badge rule: badge increments ONLY when a brand-new alert ID is seen.
//             Reminder popups for the same alert never change the badge.
//
// Timing rule: all delays are measured from the moment the alert is first
//              detected (createdAt), NOT from the previous reminder.
//              e.g. if alert arrives at 18:00:
//                18:03 → reminder 1
//                18:05 → reminder 2
//                18:07 → reminder 3  → STOP
//
// Each alert has independent timers.  Resolve cancels all timers for that alert.

import 'dart:async';
import 'package:flutter/material.dart';

// ── Schedule (absolute minutes from detection) ────────────────────────────────
const List<int> _kScheduleMinutes = [3, 5, 7];

// ─────────────────────────────────────────────────────────────────────────────

class AlertReminderService {
  final BuildContext Function() _contextGetter;
  final void Function(int count) onBadgeUpdate;
  final Future<void> Function(dynamic alertId) onResolve;
  final void Function() onViewAlerts;

  // Keyed per alert ID
  final Map<String, _AlertState> _states = {};

  // Badge = number of distinct UNRESOLVED alerts seen since last clearBadge()
  final Set<String> _badgedKeys = {};
  int get badgeCount => _badgedKeys.length;

  bool _disposed = false;

  AlertReminderService({
    required BuildContext Function() contextGetter,
    required this.onBadgeUpdate,
    required this.onResolve,
    required this.onViewAlerts,
  }) : _contextGetter = contextGetter;

  // ── Called every poll cycle with the latest active anomaly list ────────────
  void syncAlerts(List<Map<String, dynamic>> anomalies) {
    if (_disposed) return;

    final incomingKeys = <String>{};

    for (final alert in anomalies) {
      final key = _alertKey(alert);
      incomingKeys.add(key);

      if (!_states.containsKey(key)) {
        // ── Brand-new alert ───────────────────────────────────────────────
        final now = DateTime.now();
        final detectedAt = _extractDetectedAt(alert) ?? now;
        final state = _AlertState(
          alert: Map<String, dynamic>.from(alert),
          createdAt: detectedAt,
        );
        _states[key] = state;

        // Badge: only increment for genuinely new alert IDs
        if (!_badgedKeys.contains(key)) {
          _badgedKeys.add(key);
          onBadgeUpdate(_badgedKeys.length);
        }

        // Immediate popup (step 0)
        Future.microtask(() => _showPopup(key, 0));

        // Schedule reminders at absolute offsets from anomaly detection time
        _scheduleReminders(key, state, detectedAt);
      }
    }

    // ── Alerts that disappeared from the API (resolved externally) ────────
    final gone = _states.keys.where((k) => !incomingKeys.contains(k)).toList();
    for (final k in gone) {
      _cancelState(k, decrementBadge: true);
    }
  }

  // ── User taps Resolve in the popup or in the list ─────────────────────────
  void resolveAlert(Map<String, dynamic> alert) {
    final key = _alertKey(alert);
    _cancelState(key, decrementBadge: true);
  }

  // ── User opens the Alerts tab ─────────────────────────────────────────────
  void clearBadge() {
    _badgedKeys.clear();
    onBadgeUpdate(0);
  }

  // ── Dispose all timers (call from widget dispose()) ───────────────────────
  void dispose() {
    _disposed = true;
    for (final s in _states.values) {
      s.cancelTimers();
    }
    _states.clear();
    _badgedKeys.clear();
  }

  // ── Internal helpers ──────────────────────────────────────────────────────

  void _cancelState(String key, {required bool decrementBadge}) {
    _states[key]?.cancelTimers();
    _states.remove(key);
    if (decrementBadge && _badgedKeys.remove(key)) {
      onBadgeUpdate(_badgedKeys.length);
    }
  }

  /// Schedule all reminder timers.
  /// Delay = kScheduleMinutes[i] minutes from [detectedAt], not from previous reminder.
  void _scheduleReminders(String key, _AlertState state, DateTime detectedAt) {
    for (int i = 0; i < _kScheduleMinutes.length; i++) {
      final targetTime = detectedAt.add(Duration(minutes: _kScheduleMinutes[i]));
      final delay = targetTime.difference(DateTime.now());
      final reminderStep = i + 1; // 1-based: #1, #2, #3, #4

      if (delay.isNegative) continue; // already past — skip

      final t = Timer(delay, () {
        if (_disposed) return;
        if (!_states.containsKey(key)) return; // resolved in the meantime

        // Do NOT bump badge here — it's a reminder, not a new alert
        _showPopup(key, reminderStep);
      });

      state.timers.add(t);
    }
  }

  void _showPopup(String key, int reminderStep) {
    if (_disposed) return;
    final state = _states[key];
    if (state == null) return;
    if (state.popupShowing) return; // don't stack same-alert popups

    BuildContext? ctx;
    try {
      ctx = _contextGetter();
    } catch (_) {
      return;
    }
    if (!ctx.mounted) return;

    state.popupShowing = true;

    showDialog<void>(
      context: ctx,
      barrierDismissible: true,
      barrierColor: Colors.black45,
      builder: (_) => _AnomalyAlertDialog(
        alert: state.alert,
        reminderStep: reminderStep,
        onViewAlerts: () {
          Navigator.of(ctx!, rootNavigator: true).pop();
          clearBadge();
          onViewAlerts();
        },
        onResolve: () async {
          Navigator.of(ctx!, rootNavigator: true).pop();
          resolveAlert(state.alert);
          await onResolve(state.alert['id'] ?? state.alert['_id']);
        },
      ),
    ).whenComplete(() {
      if (_states.containsKey(key)) state.popupShowing = false;
    });
  }

  static String _alertKey(Map<String, dynamic> a) {
    final id = a['id'];
    if (id != null) return 'alert_$id';
    // Fallback for alerts without an id
    return '${a['device_id']}_${a['timestamp'] ?? a['ds']}';
  }

  static DateTime? _extractDetectedAt(Map<String, dynamic> alert) {
    final raw =
        alert['first_detected_at'] ?? alert['timestamp'] ?? alert['ds'];
    if (raw == null) return null;
    try {
      return DateTime.parse(raw.toString()).toLocal();
    } catch (_) {
      return null;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _AlertState {
  final Map<String, dynamic> alert;
  final DateTime createdAt;
  final List<Timer> timers = [];
  bool popupShowing = false;

  _AlertState({required this.alert, required this.createdAt});

  void cancelTimers() {
    for (final t in timers) {
      t.cancel();
    }
    timers.clear();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Popup dialog
// ─────────────────────────────────────────────────────────────────────────────

class _AnomalyAlertDialog extends StatelessWidget {
  final Map<String, dynamic> alert;
  final int reminderStep; // 0 = initial detection, 1-4 = reminders
  final VoidCallback onViewAlerts;
  final VoidCallback onResolve;

  const _AnomalyAlertDialog({
    required this.alert,
    required this.reminderStep,
    required this.onViewAlerts,
    required this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    final isFirst = reminderStep == 0;
    final deviceId = '${alert['device_id'] ?? 'Unknown Room'}';
    final power    = alert['power'] ?? '—';
    final occupancy= alert['occupancy'] ?? '—';
    final score    = alert['score'];
    final sevColor = _sevColor(alert['power']);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: sevColor.withOpacity(0.30),
              blurRadius: 32,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Coloured header ───────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
              decoration: BoxDecoration(
                color: sevColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(
                children: [
                  _PulsingIcon(color: sevColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isFirst
                              ? '⚠  Energy Anomaly Detected'
                              : '⚠  Reminder #$reminderStep — Unresolved',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        if (!isFirst)
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Text(
                              'This alert has not been resolved yet',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Dismiss x
                  InkWell(
                    onTap: () =>
                        Navigator.of(context, rootNavigator: true).pop(),
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.close, color: Colors.white70, size: 20),
                    ),
                  ),
                ],
              ),
            ),

            // ── Details ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Column(
                children: [
                  _DetailRow(Icons.meeting_room_outlined, 'Room', deviceId),
                  const SizedBox(height: 10),
                  _DetailRow(
                    Icons.bolt,
                    'Power',
                    '${power}W while occupancy = $occupancy',
                    valueColor: sevColor,
                  ),
                  if (score != null) ...[
                    const SizedBox(height: 10),
                    _DetailRow(
                      Icons.analytics_outlined,
                      'Anomaly score',
                      '${score is double ? score.toStringAsFixed(3) : score}',
                    ),
                  ],
                  if (!isFirst) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Text(
                        'Please investigate and resolve this alert.',
                        style: TextStyle(
                          color: Colors.orange.shade800,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Reminder step indicator dots ──────────────────────────────
            if (!isFirst)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_kScheduleMinutes.length, (i) {
                    final done = i < reminderStep;
                    final current = i == reminderStep - 1;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: current ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: done ? sevColor : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
              ),

            // ── Buttons ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onViewAlerts,
                      icon: const Icon(Icons.visibility_outlined, size: 16),
                      label: const Text('View Alert'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: sevColor,
                        side: BorderSide(color: sevColor),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onResolve,
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Resolve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Color _sevColor(dynamic power) {
    final p = (power as num?)?.toDouble() ?? 0;
    if (p > 5000) return const Color(0xFFB71C1C);
    if (p > 3000) return const Color(0xFFD32F2F);
    return Colors.orange.shade700;
  }
}

// ── Pulsing warning icon ──────────────────────────────────────────────────────

class _PulsingIcon extends StatefulWidget {
  final Color color;
  const _PulsingIcon({required this.color});
  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 750))
    ..repeat(reverse: true);
  late final Animation<double> _scale =
      Tween<double>(begin: 0.82, end: 1.0).animate(
          CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
        scale: _scale,
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.22),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.warning_amber_rounded,
              color: Colors.white, size: 24),
        ),
      );
}

// ── Detail row ────────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow(this.icon, this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade500),
        const SizedBox(width: 8),
        Text('$label:  ',
            style: const TextStyle(
                fontSize: 13,
                color: Colors.black54,
                fontWeight: FontWeight.w500)),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Badge icon — reusable in both dashboards ──────────────────────────────────

class AlertBadgeIcon extends StatelessWidget {
  final IconData icon;
  final int count;

  const AlertBadgeIcon({
    super.key,
    required this.icon,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return Icon(icon);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        Positioned(
          top: -5,
          right: -7,
          child: AnimatedScale(
            scale: count > 0 ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.elasticOut,
            child: Container(
              constraints:
                  const BoxConstraints(minWidth: 17, minHeight: 17),
              padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: [
                  BoxShadow(
                      color: Colors.red.withOpacity(0.5), blurRadius: 4),
                ],
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
