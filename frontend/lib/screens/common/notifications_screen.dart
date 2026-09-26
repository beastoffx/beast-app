import 'package:flutter/material.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/beast_tokens.dart';
import '../../widgets/beast_components.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _notifications = [];

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await _api.get(ApiConstants.notificationsMy, useCache: false);
    if (!mounted) return;

    if (res.success && res.data != null) {
      setState(() {
        _notifications = res.data as List? ?? [];
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = res.error ?? 'Failed to load notifications.';
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(String id) async {
    final res = await _api.put('/api/notifications/$id/read', {});
    if (res.success && mounted) {
      setState(() {
        final idx = _notifications.indexWhere((n) => n['id'] == id);
        if (idx != -1) {
          _notifications[idx]['is_read'] = 1;
        }
      });
    }
  }

  Future<void> _markAllAsRead() async {
    final res = await _api.put('/api/notifications/read-all', {});
    if (res.success && mounted) {
      setState(() {
        for (var n in _notifications) {
          n['is_read'] = 1;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All notifications marked as read.'),
          backgroundColor: BeastColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BeastColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (_notifications.any((n) => n['is_read'] == 0 || n['is_read'] == false))
            TextButton.icon(
              icon: const Icon(Icons.done_all_rounded, size: 18),
              label: const Text('Mark all read'),
              onPressed: _markAllAsRead,
              style: TextButton.styleFrom(
                foregroundColor: BeastColors.textSecondary,
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const BeastLoadingState(message: 'Loading notifications...');
    }

    if (_errorMessage != null) {
      return BeastErrorState(
        message: _errorMessage!,
        onRetry: _fetchNotifications,
      );
    }

    if (_notifications.isEmpty) {
      return const BeastEmptyState(
        icon: Icons.notifications_none_rounded,
        title: 'No Notifications',
        message: 'Academic circulars, class updates, and schedule changes will appear here.',
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchNotifications,
      color: BeastColors.brandPrimary,
      child: ListView.separated(
        padding: const EdgeInsets.all(BeastSpacing.lg),
        itemCount: _notifications.length,
        separatorBuilder: (_, __) => const SizedBox(height: BeastSpacing.sm),
        itemBuilder: (context, index) {
          final item = _notifications[index];
          final bool isRead = item['is_read'] == 1 || item['is_read'] == true;
          final title = item['title'] ?? 'Notification';
          final message = item['message'] ?? '';
          final createdAt = item['created_at'] ?? '';
          final id = item['id']?.toString() ?? '';

          return BeastCard(
            backgroundColor: isRead ? BeastColors.white : BeastColors.surfaceWarm.withValues(alpha: 0.35),
            borderColor: isRead ? BeastColors.borderSubtle : BeastColors.peach400,
            onTap: isRead ? null : () => _markAsRead(id),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isRead ? BeastColors.neutral100 : BeastColors.peach200,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isRead ? Icons.notifications_outlined : Icons.notifications_active_rounded,
                    size: 18,
                    color: isRead ? BeastColors.textMuted : BeastColors.dark900,
                  ),
                ),
                const SizedBox(width: BeastSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: BeastTypography.bodyMedium.copyWith(
                                fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                              ),
                            ),
                          ),
                          if (!isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: BeastColors.danger,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message,
                        style: BeastTypography.body.copyWith(
                          color: BeastColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      if (createdAt.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt,
                          style: BeastTypography.caption,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
