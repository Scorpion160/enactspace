import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/notification_model.dart';
import '../services/notifications_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationsService _service = NotificationsService();

  bool _loading = true;
  String? _error;

  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;

  bool _unreadOnly = false;
  String _type = 'all';

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final notifications = await _service.getNotifications(
        unreadOnly: _unreadOnly ? true : null,
        type: _type,
      );
      final unreadCount = await _service.getUnreadCount();

      if (!mounted) return;

      setState(() {
        _notifications = notifications;
        _unreadCount = unreadCount;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _markAsRead(NotificationModel notification) async {
    if (notification.isRead) return;

    try {
      await _service.markAsRead(notification.id);
      await _loadNotifications();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification marquée comme lue.')),
      );
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final updated = await _service.markAllAsRead();
      await _loadNotifications();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$updated notification(s) marquée(s) comme lues.'),
        ),
      );
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _deleteNotification(NotificationModel notification) async {
    try {
      await _service.deleteNotification(notification.id);
      await _loadNotifications();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Notification supprimée.')));
    } catch (e) {
      _showError(e);
    }
  }

  void _showError(Object e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red.shade700,
        content: Text(e.toString().replaceAll('Exception: ', '')),
      ),
    );
  }

  int get _readCount {
    return _notifications.where((n) => n.isRead).length;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _NotificationsHeader(
            total: _notifications.length,
            unread: _unreadCount,
            read: _readCount,
            onRefresh: _loadNotifications,
            onMarkAllRead: _markAllAsRead,
          ),
          const SizedBox(height: 18),
          _NotificationsFilters(
            unreadOnly: _unreadOnly,
            type: _type,
            onUnreadOnlyChanged: (value) async {
              setState(() => _unreadOnly = value);
              await _loadNotifications();
            },
            onTypeChanged: (value) async {
              setState(() => _type = value);
              await _loadNotifications();
            },
          ),
          const SizedBox(height: 22),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            _ErrorCard(message: _error!, onRetry: _loadNotifications)
          else if (_notifications.isEmpty)
            const _EmptyNotificationsCard()
          else
            _NotificationsList(
              notifications: _notifications,
              onMarkAsRead: _markAsRead,
              onDelete: _deleteNotification,
            ),
        ],
      ),
    );
  }
}

class _NotificationsHeader extends StatelessWidget {
  final int total;
  final int unread;
  final int read;
  final VoidCallback onRefresh;
  final VoidCallback onMarkAllRead;

  const _NotificationsHeader({
    required this.total,
    required this.unread,
    required this.read,
    required this.onRefresh,
    required this.onMarkAllRead,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 760;

    final actions = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        OutlinedButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Actualiser'),
        ),
        ElevatedButton.icon(
          onPressed: unread > 0 ? onMarkAllRead : null,
          icon: const Icon(Icons.done_all_rounded),
          label: const Text('Tout lire'),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: AppTheme.softBlack,
        borderRadius: BorderRadius.circular(24),
      ),
      child: isWide
          ? Row(
              children: [
                _HeaderIcon(unread: unread),
                const SizedBox(width: 18),
                Expanded(
                  child: _HeaderText(total: total, unread: unread, read: read),
                ),
                actions,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _HeaderIcon(unread: unread),
                    const SizedBox(width: 18),
                    Expanded(
                      child: _HeaderText(
                        total: total,
                        unread: unread,
                        read: read,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                actions,
              ],
            ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  final int unread;

  const _HeaderIcon({required this.unread});

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: unread > 0,
      label: Text(unread.toString()),
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: AppTheme.enactusYellow,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(
          Icons.notifications_rounded,
          color: AppTheme.softBlack,
          size: 34,
        ),
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  final int total;
  final int unread;
  final int read;

  const _HeaderText({
    required this.total,
    required this.unread,
    required this.read,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Notifications',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$total notification(s) affichée(s) • $unread non lue(s) • $read lue(s)',
          style: const TextStyle(color: Colors.white70, height: 1.4),
        ),
      ],
    );
  }
}

class _NotificationsFilters extends StatelessWidget {
  final bool unreadOnly;
  final String type;
  final ValueChanged<bool> onUnreadOnlyChanged;
  final ValueChanged<String> onTypeChanged;

  const _NotificationsFilters({
    required this.unreadOnly,
    required this.type,
    required this.onUnreadOnlyChanged,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ChoiceChip(
              selected: !unreadOnly,
              label: const Text('Toutes'),
              avatar: const Icon(Icons.list_rounded, size: 18),
              onSelected: (_) => onUnreadOnlyChanged(false),
            ),
            ChoiceChip(
              selected: unreadOnly,
              label: const Text('Non lues'),
              avatar: const Icon(Icons.mark_email_unread_rounded, size: 18),
              onSelected: (_) => onUnreadOnlyChanged(true),
            ),
            SizedBox(
              width: 260,
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Tous les types')),
                  DropdownMenuItem(
                    value: 'task_assigned',
                    child: Text('Tâche assignée'),
                  ),
                  DropdownMenuItem(
                    value: 'deadline_near',
                    child: Text('Échéance proche'),
                  ),
                  DropdownMenuItem(
                    value: 'attendance',
                    child: Text('Présence'),
                  ),
                  DropdownMenuItem(value: 'payment', child: Text('Paiement')),
                  DropdownMenuItem(value: 'document', child: Text('Document')),
                  DropdownMenuItem(
                    value: 'recruitment',
                    child: Text('Recrutement'),
                  ),
                  DropdownMenuItem(value: 'system', child: Text('Système')),
                ],
                onChanged: (value) {
                  if (value != null) onTypeChanged(value);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationsList extends StatelessWidget {
  final List<NotificationModel> notifications;
  final ValueChanged<NotificationModel> onMarkAsRead;
  final ValueChanged<NotificationModel> onDelete;

  const _NotificationsList({
    required this.notifications,
    required this.onMarkAsRead,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: notifications.map((notification) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _NotificationCard(
            notification: notification,
            onMarkAsRead: onMarkAsRead,
            onDelete: onDelete,
          ),
        );
      }).toList(),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final ValueChanged<NotificationModel> onMarkAsRead;
  final ValueChanged<NotificationModel> onDelete;

  const _NotificationCard({
    required this.notification,
    required this.onMarkAsRead,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final icon = _iconForType(notification.type);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => onMarkAsRead(notification),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: notification.isRead
                    ? Colors.grey.shade200
                    : AppTheme.enactusYellow,
                foregroundColor: AppTheme.softBlack,
                child: Icon(icon),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: notification.isRead
                            ? FontWeight.w600
                            : FontWeight.w900,
                      ),
                    ),
                    if (notification.message != null &&
                        notification.message!.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        notification.message!,
                        style: const TextStyle(
                          color: Colors.black54,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text(notification.typeLabel)),
                        Chip(
                          label: Text(notification.isRead ? 'Lue' : 'Non lue'),
                        ),
                        Chip(label: Text(notification.createdAtLabel)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Wrap(
                spacing: 6,
                children: [
                  if (!notification.isRead)
                    IconButton(
                      onPressed: () => onMarkAsRead(notification),
                      icon: const Icon(Icons.mark_email_read_rounded),
                      tooltip: 'Marquer comme lue',
                    ),
                  IconButton(
                    onPressed: () => onDelete(notification),
                    icon: const Icon(Icons.delete_rounded),
                    tooltip: 'Supprimer',
                    color: Colors.red,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'task_assigned':
        return Icons.task_alt_rounded;
      case 'deadline_near':
        return Icons.timer_rounded;
      case 'attendance':
        return Icons.fact_check_rounded;
      case 'payment':
        return Icons.payments_rounded;
      case 'document':
        return Icons.description_rounded;
      case 'recruitment':
        return Icons.how_to_reg_rounded;
      case 'system':
        return Icons.info_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }
}

class _EmptyNotificationsCard extends StatelessWidget {
  const _EmptyNotificationsCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(26),
        child: Center(
          child: Text(
            'Aucune notification trouvée.',
            style: TextStyle(color: Colors.black54),
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Colors.red.shade600,
              size: 44,
            ),
            const SizedBox(height: 12),
            const Text(
              'Erreur de chargement',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}
