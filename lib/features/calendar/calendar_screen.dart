import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/app_scope.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';
import '../../widgets/shaker.dart';

/// 04 カレンダー：振った日・乾杯した日のスタンプが並ぶ
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime? _month; // 表示中の月（1日）
  DateTime? _selected;

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context);
    final today = repo.today;
    final month = _month ?? DateTime(today.year, today.month);
    // 表示する月の記録がまだ無ければ取りに行く（届くと描き直される。2 回目以降は何もしない）
    repo.ensureMonthLoaded(month);
    final logs = repo.logs;

    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final monthLogs = [
      for (var d = 1; d <= daysInMonth; d++)
        ?logs[DateTime(month.year, month.month, d)],
    ];
    final cheers = monthLogs.fold(0, (sum, l) => sum + l.cheerWith.length);
    final longest = _longestStreak(month, daysInMonth, logs);

    final selected = _selected;
    final selectedLog = selected != null ? logs[selected] : null;

    return Scaffold(
      appBar: AppBar(title: const Text('カレンダー')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _NavButton(
                icon: Icons.chevron_left_rounded,
                tooltip: '前の月',
                onTap: () => setState(() {
                  _month = DateTime(month.year, month.month - 1);
                  _selected = null;
                }),
              ),
              Text(
                '${month.year}年 ${month.month}月',
                style: AppFonts.heading(20),
              ),
              _NavButton(
                icon: Icons.chevron_right_rounded,
                tooltip: '次の月',
                onTap: () => setState(() {
                  _month = DateTime(month.year, month.month + 1);
                  _selected = null;
                }),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Stat(
                leading: const ShakerIcon(
                  size: 18,
                  liquidColor: AppColors.cocoa,
                ),
                label: '今月振った日',
                value: '${monthLogs.length}日',
              ),
              const SizedBox(width: 10),
              _Stat(
                leading: const Icon(
                  AppIcons.cheer,
                  size: 18,
                  color: AppColors.primary,
                ),
                label: '乾杯',
                value: '$cheers回',
              ),
              const SizedBox(width: 10),
              _Stat(
                leading: const Icon(
                  AppIcons.flame,
                  size: 18,
                  color: AppColors.primary,
                ),
                label: '最長連続',
                value: '$longest日',
              ),
            ],
          ),
          const SizedBox(height: 14),
          AppCard(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    for (final d in const ['日', '月', '火', '水', '木', '金', '土'])
                      Expanded(
                        child: Center(
                          child: Text(
                            d,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                _MonthGrid(
                  month: month,
                  today: today,
                  logs: logs,
                  selected: selected,
                  onSelect: (day) => setState(() => _selected = day),
                ),
                const SizedBox(height: 8),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Legend(color: AppColors.primary, label: '振った日'),
                    SizedBox(width: 14),
                    _Legend(color: AppColors.cheer, label: '乾杯した日'),
                  ],
                ),
              ],
            ),
          ),
          if (selected != null) ...[
            const SizedBox(height: 14),
            _DayDetail(day: selected, log: selectedLog),
          ],
        ],
      ),
    );
  }

  static int _longestStreak(
    DateTime month,
    int daysInMonth,
    Map<DateTime, ShakeLog> logs,
  ) {
    var best = 0, current = 0;
    for (var d = 1; d <= daysInMonth; d++) {
      if (logs.containsKey(DateTime(month.year, month.month, d))) {
        current++;
        if (current > best) best = current;
      } else {
        current = 0;
      }
    }
    return best;
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.today,
    required this.logs,
    required this.selected,
    required this.onSelect,
  });

  final DateTime month;
  final DateTime today;
  final Map<DateTime, ShakeLog> logs;
  final DateTime? selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = DateTime(month.year, month.month, 1).weekday % 7; // 日曜はじまり
    final rows = ((leading + daysInMonth) / 7).ceil();

    return Column(
      children: [
        for (var r = 0; r < rows; r++)
          Row(
            children: [
              for (var c = 0; c < 7; c++)
                Expanded(child: _cell(r * 7 + c - leading + 1, daysInMonth)),
            ],
          ),
      ],
    );
  }

  Widget _cell(int dayNumber, int daysInMonth) {
    if (dayNumber < 1 || dayNumber > daysInMonth) {
      return const SizedBox(height: 56);
    }
    final day = DateTime(month.year, month.month, dayNumber);
    final log = logs[day];
    final isToday = day == today;
    final isFuture = day.isAfter(today);
    final isSelected = day == selected;

    final Widget dot;
    if (log != null) {
      dot = log.cheered
          ? const IconBadge(
              icon: AppIcons.cheer,
              size: 36,
              background: AppColors.cheer,
              foreground: AppColors.ink,
            )
          : const IconBadge(
              size: 36,
              background: AppColors.primary,
              child: ShakerIcon(
                size: 22,
                color: Colors.white,
                liquidColor: AppColors.milk,
              ),
            );
    } else {
      dot = Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isFuture
              ? Colors.transparent
              : (isToday
                    ? AppColors.surface
                    : AppColors.line.withValues(alpha: 0.5)),
          border: isToday
              ? Border.all(color: AppColors.primary, width: 2)
              : null,
        ),
        child: Text(
          '$dayNumber',
          style: TextStyle(
            fontSize: 13,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
            color: isToday
                ? AppColors.primary
                : (isFuture ? AppColors.muted : AppColors.ink),
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      label:
          '${month.month}月$dayNumber日'
          '${log == null ? '' : (log.cheered ? ' 乾杯した日' : ' 振った日')}',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onSelect(day),
        child: Container(
          height: 56,
          decoration: isSelected
              ? BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                )
              : null,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              dot,
              Text(
                log != null ? '$dayNumber' : '',
                style: const TextStyle(fontSize: 10, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayDetail extends StatelessWidget {
  const _DayDetail({required this.day, required this.log});

  final DateTime day;
  final ShakeLog? log;

  @override
  Widget build(BuildContext context) {
    final log = this.log;
    final title = log == null
        ? 'この日は振っていません'
        : (log.cheered
              ? '${log.cheerWith.join('さん・')}さんと乾杯しました'
              : 'プロテインを振りました');
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          log?.cheered == true
              ? const IconBadge(
                  icon: AppIcons.cheer,
                  size: 40,
                  background: AppColors.cheerSoft,
                  foreground: AppColors.ink,
                )
              : const IconBadge(
                  size: 40,
                  background: AppColors.primarySoft,
                  child: ShakerIcon(size: 22, liquidColor: AppColors.cocoa),
                ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${day.month}月${day.day}日（${weekdayLabels[day.weekday - 1]}）',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (log?.cheered == true)
            Avatar(
              initial: log!.cheerWith.first.substring(0, 1),
              color: Avatar.colorFor(log.cheerWith.first),
              size: 32,
            ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton.outlined(
      onPressed: onTap,
      tooltip: tooltip,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: AppColors.surface,
        side: const BorderSide(color: AppColors.line),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.leading,
    required this.label,
    required this.value,
  });

  final Widget leading;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            leading,
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
            Text(value, style: AppFonts.heading(20)),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.muted),
        ),
      ],
    );
  }
}
