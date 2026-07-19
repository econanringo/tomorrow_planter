import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/api_provider.dart';
import '../../data/models.dart';
import '../shared/schedule_list.dart';

class TomorrowPlanScreen extends ConsumerStatefulWidget {
  const TomorrowPlanScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<TomorrowPlanScreen> createState() => _TomorrowPlanScreenState();
}

class _TomorrowPlanScreenState extends ConsumerState<TomorrowPlanScreen> {
  FinalizeResponse? _result;
  bool _loading = false;
  String? _error;

  Future<void> _finalize() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref.read(apiClientProvider).finalize(
            sessionId: widget.sessionId,
          );
      setState(() => _result = result);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final result = _result;

    return Scaffold(
      appBar: AppBar(title: const Text('Tomorrow Plan')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '明日の予定を保存して、一日を締めくくりましょう。',
                style: textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              if (_error != null)
                Text(_error!, style: TextStyle(color: scheme.error)),
              if (result != null) ...[
                Text(
                  '${result.planDate} のプラン',
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    children: [
                      ScheduleList(schedule: result.schedule),
                      const SizedBox(height: 16),
                      Text(
                        result.coachMessage,
                        style: textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: () => context.go('/'),
                  child: const Text('ホームへ'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => context.go('/morning'),
                  child: const Text('Morning Briefing を見る'),
                ),
              ] else ...[
                const Spacer(),
                FilledButton(
                  onPressed: _loading ? null : _finalize,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('保存して就寝'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
