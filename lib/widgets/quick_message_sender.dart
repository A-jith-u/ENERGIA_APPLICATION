// ignore_for_file: deprecated_member_use, file_names
import 'package:flutter/material.dart';
import 'package:energia/services/notification_service.dart';

/// Quick Message Sender Widget - Admin tool to send push notifications to all users
class QuickMessageSender extends StatefulWidget {
  const QuickMessageSender({super.key});

  @override
  State<QuickMessageSender> createState() => _QuickMessageSenderState();
}

class _QuickMessageSenderState extends State<QuickMessageSender> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and message cannot be empty')),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final success = await NotificationService().quickSendToAll(
        title: title,
        body: body,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Message sent to all users'),
              backgroundColor: Colors.green,
            ),
          );
          _titleController.clear();
          _bodyController.clear();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✗ Failed to send message'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.send, size: 28, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  'Quick Message to All Users',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Title field
            TextField(
              controller: _titleController,
              enabled: !_isSending,
              maxLength: 100,
              decoration: InputDecoration(
                labelText: 'Message Title',
                hintText: 'e.g., System Maintenance',
                prefixIcon: const Icon(Icons.title),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Body field
            TextField(
              controller: _bodyController,
              enabled: !_isSending,
              maxLength: 500,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Message Body',
                hintText: 'Enter your message here...',
                prefixIcon: const Icon(Icons.message),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed:
                      _isSending
                          ? null
                          : () {
                            _titleController.clear();
                            _bodyController.clear();
                          },
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isSending ? null : _sendMessage,
                  icon:
                      _isSending
                          ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(
                                theme.colorScheme.onPrimary,
                              ),
                            ),
                          )
                          : const Icon(Icons.send),
                  label: Text(_isSending ? 'Sending...' : 'Send to All'),
                ),
              ],
            ),

            // Info text
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This message will be sent to all app users via Firebase Cloud Messaging.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
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
}
