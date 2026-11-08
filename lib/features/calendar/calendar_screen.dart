import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/app_scope.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';
import '../../widgets/shaker.dart';

/// 04 カレンダー：振った日がアンバー、乾杯した日が青のマスになる
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime? _month; // 表示中の月（1日）
  DateTime? _selected;

  void _moveMonth(DateTime month, int delta) => setState(() {
        _month = DateTime(month.year, month.month + delta);
        _selected = null;
      });

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context);
    final today = repo.today;
    final month = _month ?? DateTime(today.year, today.month);
    final logs = repo.logs;

    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final monthLogs = [
      for (var d = 1; d <= daysInMonth; d++)
        ?logs[DateTime(month.year, month.month, d)],
    ];
    final cheers = monthLogs.fold(0, (sum, l) => sum + l.cheerWith.length);
    final longest = _longestStreak(month, daysInMonth, logs);
    final selected = _selected;

    return Scaffold(
      appBar: AppBar(title: const Text('カレンダー')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Row(
            children: [
              Text('${month.year}年${month.month}月', style: AppFonts.heading(20)),
              const Spacer(),
              IconButton(
                onPressed: () => _moveMonth(month, -1),
                tooltip: '前の月',
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              IconButton(
                onPressed: () => _moveMonth(month, 1),
                tooltip: '次の月',
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${monthLogs.length}',
                style: AppFonts.heading(76, color: AppColors.primary)
                    .copyWith(height: 0.95),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('日 振った', style: AppFonts.heading(20)),
                    Text(
                      '乾杯 $cheers回　最長 $longest日連続',
                      style: const TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              for (final d in const ['日', '月', '火', '水', '木', '金', '土'])
                Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
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
          const SizedBox(height: 10),
          const Row(
            children: [
              _Legend(color: AppColors.primary, label: '振った日'),
              SizedBox(width: 16),
              _Legend(color: AppColors.cheer, label: '乾杯した日'),
            ],
          ),
          if (selected != null) ...[
            const SizedBox(height: 16),
            _DayDetail(day: selected, log: logs[selected]),
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
      return const SizedBox(height: 48);
    }
    final day = DateTime(month.year, month.month, dayNumber);
    final log = logs[day];
    final isToday = day == today;
    final isFuture = day.isAfter(today);
    final isSelected = day == selected;

    final (Color bg, Color fg) = switch (log) {
      ShakeLog(cheered: true) => (AppColors.cheer, AppColors.ink),
      ShakeLog() => (AppColors.primary, AppColors.onPrimary),
      null => (
          Colors.transparent,
          isToday
              ? AppColors.primary
              : (isFuture ? AppColors.line : AppColors.muted),
        ),
    };

    return Semantics(
      button: true,
      selected: isSelected,
      label: '${month.month}月$dayNumber日'
          '${log == null ? '' : (log.cheered ? ' 乾杯した日' : ' 振った日')}',
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => onSelect(day),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Container(
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(6),
              border: isSelected
                  ? Border.all(color: AppColors.ink, width: 2)
                  : (isToday && log == null
                      ? Border.all(color: AppColors.primary, width: 2)
                      : null),
            ),
            child: Text(
              '$dayNumber',
              style: log != null || isToday
                  ? AppFonts.heading(15, color: fg)
                  : TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: fg),
            ),
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
    final title = switch (log) {
      null => 'この日は振っていない',
      ShakeLog(cheered: true) => '${log.cheerWith.join('・')}と乾杯した',
      _ => 'プロテインを振った',
    };
    return AppCard(
      child: Row(
        children: [
          if (log?.cheered == true)
            const IconBadge(
              icon: AppIcons.cheer,
              size: 40,
              background: AppColors.cheer,
              foreground: AppColors.ink,
            )
          else
            IconBadge(
              size: 40,
              background: AppColors.background,
              child: ShakerIcon(
                size: 22,
                color: log == null ? AppColors.muted : AppColors.primary,
                liquidColor: log == null ? Colors.transparent : AppColors.cocoa,
              ),
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
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
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
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
      ],
    );
  }
}
