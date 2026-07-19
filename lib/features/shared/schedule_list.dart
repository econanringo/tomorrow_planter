import 'package:flutter/material.dart';

import '../../data/models.dart';

class ScheduleList extends StatelessWidget {
  const ScheduleList({
    super.key,
    required this.schedule,
    this.topPriority,
  });

  final List<ScheduleItem> schedule;
  final String? topPriority;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        if (topPriority != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '最重要: $topPriority',
                style: textTheme.titleSmall?.copyWith(
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
        ...schedule.map((item) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Text(
              item.time,
              style: textTheme.labelLarge?.copyWith(
                color: scheme.primary,
              ),
            ),
            title: Text(item.title),
            subtitle: item.notes != null ? Text(item.notes!) : null,
            trailing: item.isPriority
                ? Icon(Icons.star, color: scheme.tertiary)
                : null,
          );
        }),
      ],
    );
  }
}
