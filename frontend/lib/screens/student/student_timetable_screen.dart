import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/beast_tokens.dart';
import '../../models/timetable_model.dart';
import '../../providers/student_provider.dart';
import '../../widgets/beast_components.dart';

class StudentTimetableScreen extends StatefulWidget {
  const StudentTimetableScreen({super.key});

  @override
  State<StudentTimetableScreen> createState() => _StudentTimetableScreenState();
}

class _StudentTimetableScreenState extends State<StudentTimetableScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  final List<String> _dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

  @override
  void initState() {
    super.initState();
    final todayJs = DateTime.now().weekday;
    final initialIndex = (todayJs >= 1 && todayJs <= 6) ? todayJs - 1 : 0;
    _tabController = TabController(length: 6, vsync: this, initialIndex: initialIndex);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<StudentProvider>(context, listen: false).fetchTimetable();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _isOngoing(String startTime, String endTime) {
    try {
      final now = DateTime.now();
      final nowMinutes = now.hour * 60 + now.minute;

      final startParts = startTime.split(':').map((p) => int.parse(p.trim())).toList();
      final endParts = endTime.split(':').map((p) => int.parse(p.trim())).toList();

      final startMinutes = startParts[0] * 60 + startParts[1];
      final endMinutes = endParts[0] * 60 + endParts[1];

      return nowMinutes >= startMinutes && nowMinutes <= endMinutes;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final student = Provider.of<StudentProvider>(context);
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: BeastColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Academic Timetable'),
        bottom: isDesktop
            ? null
            : TabBar(
                controller: _tabController,
                labelColor: BeastColors.dark900,
                unselectedLabelColor: BeastColors.textSecondary,
                indicatorColor: BeastColors.brandPrimary,
                indicatorWeight: 2.5,
                tabs: _days.map((d) => Tab(text: d)).toList(),
              ),
      ),
      body: student.isLoading && student.schedule.isEmpty
          ? const BeastLoadingState(message: 'Loading weekly schedule...')
          : student.errorMessage != null && student.schedule.isEmpty
              ? BeastErrorState(
                  message: student.errorMessage!,
                  onRetry: () => student.fetchTimetable(),
                )
              : isDesktop
                  ? _buildDesktopWeeklyMatrix(student.schedule)
                  : _buildMobileDayView(student.schedule),
    );
  }

  Widget _buildMobileDayView(List<TimetableSlot> schedule) {
    return TabBarView(
      controller: _tabController,
      children: List.generate(6, (index) {
        final dayNumber = index + 1; // 1: Mon .. 6: Sat
        final slots = schedule.where((s) => s.dayOfWeek == dayNumber).toList();

        if (slots.isEmpty) {
          return BeastEmptyState(
            icon: Icons.calendar_today_outlined,
            title: 'No Classes on ${_dayNames[index]}',
            message: 'No lectures are scheduled for this day.',
          );
        }

        return RefreshIndicator(
          onRefresh: () => Provider.of<StudentProvider>(context, listen: false).fetchTimetable(),
          color: BeastColors.brandPrimary,
          child: ListView.separated(
            padding: const EdgeInsets.all(BeastSpacing.lg),
            itemCount: slots.length,
            separatorBuilder: (_, __) => const SizedBox(height: BeastSpacing.md),
            itemBuilder: (ctx, i) {
              return _buildSlotCard(slots[i]);
            },
          ),
        );
      }),
    );
  }

  Widget _buildDesktopWeeklyMatrix(List<TimetableSlot> schedule) {
    return RefreshIndicator(
      onRefresh: () => Provider.of<StudentProvider>(context, listen: false).fetchTimetable(),
      color: BeastColors.brandPrimary,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(BeastSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BeastPageHeader(
              title: 'Weekly Master Schedule',
              subtitle: 'Comprehensive view of all enrolled batch lecture slots across the week.',
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(6, (index) {
                final dayNumber = index + 1;
                final slots = schedule.where((s) => s.dayOfWeek == dayNumber).toList();
                final isToday = DateTime.now().weekday == dayNumber;

                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.all(BeastSpacing.sm),
                    decoration: BoxDecoration(
                      color: isToday ? BeastColors.surfaceWarm.withValues(alpha: 0.3) : BeastColors.white,
                      borderRadius: BorderRadius.circular(BeastRadius.md),
                      border: Border.all(
                        color: isToday ? BeastColors.peach400 : BeastColors.borderSubtle,
                        width: isToday ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isToday ? BeastColors.brandPrimary : BeastColors.neutral100,
                            borderRadius: BorderRadius.circular(BeastRadius.xs),
                          ),
                          child: Text(
                            _days[index].toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: isToday ? BeastColors.white : BeastColors.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: BeastSpacing.md),
                        if (slots.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                              'Off',
                              style: TextStyle(fontSize: 12, color: BeastColors.textMuted),
                              textAlign: TextAlign.center,
                            ),
                          )
                        else
                          ...slots.map((s) => Padding(
                                padding: const EdgeInsets.only(bottom: BeastSpacing.sm),
                                child: _buildCompactSlotCard(s),
                              )),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlotCard(TimetableSlot slot) {
    final isLive = _isOngoing(slot.startTime, slot.endTime);

    return BeastCard(
      backgroundColor: isLive ? BeastColors.peach100 : BeastColors.white,
      borderColor: isLive ? BeastColors.peach400 : BeastColors.borderSubtle,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isLive ? BeastColors.brandPrimary : BeastColors.neutral100,
              borderRadius: BorderRadius.circular(BeastRadius.sm),
            ),
            child: Column(
              children: [
                Text(
                  slot.startTime,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: isLive ? BeastColors.white : BeastColors.dark900,
                  ),
                ),
                Text(
                  'to',
                  style: TextStyle(
                    fontSize: 10,
                    color: isLive ? BeastColors.peach200 : BeastColors.textMuted,
                  ),
                ),
                Text(
                  slot.endTime,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: isLive ? BeastColors.white : BeastColors.dark900,
                  ),
                ),
              ],
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
                    Text(
                      (slot.subjectCode != null && slot.subjectCode!.isNotEmpty) ? slot.subjectCode! : 'LEC',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: BeastColors.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (isLive)
                      const BeastBadge(
                        label: 'ONGOING',
                        backgroundColor: BeastColors.dangerLight,
                        textColor: BeastColors.danger,
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  slot.subjectName ?? 'Subject',
                  style: BeastTypography.headline.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.person_outline_rounded, size: 14, color: BeastColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(slot.teacherName ?? 'Faculty', style: BeastTypography.caption),
                    const SizedBox(width: 12),
                    const Icon(Icons.room_outlined, size: 14, color: BeastColors.textSecondary),
                    const SizedBox(width: 4),
                    Text('Room ${slot.roomNumber}', style: BeastTypography.caption),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactSlotCard(TimetableSlot slot) {
    final isLive = _isOngoing(slot.startTime, slot.endTime);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isLive ? BeastColors.peach200 : BeastColors.white,
        borderRadius: BorderRadius.circular(BeastRadius.xs),
        border: Border.all(
          color: isLive ? BeastColors.peach400 : BeastColors.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${slot.startTime} - ${slot.endTime}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isLive ? BeastColors.dark900 : BeastColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            slot.subjectName ?? 'Subject',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '${slot.teacherName ?? "Faculty"} • ${slot.roomNumber}',
            style: const TextStyle(fontSize: 10, color: BeastColors.textMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
