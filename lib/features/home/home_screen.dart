import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth_provider.dart';
import '../../data/api_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  bool get _isMorning {
    final hour = DateTime.now().hour;
    return hour >= 5 && hour < 11;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tomorrow Planter'),
        actions: [
          IconButton(
            tooltip: 'サインアウト',
            onPressed: () => ref.read(firebaseAuthProvider).signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isMorning ? 'Good Morning' : '今夜、明日の種を植えよう',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                user?.email ?? '',
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isMorning
                    ? '昨日いっしょに決めた予定を確認しましょう。'
                    : '5〜10分の雑談から、AIチームと明日を設計します。',
                style: textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              if (_isMorning)
                FilledButton.icon(
                  onPressed: () => context.push('/morning'),
                  icon: const Icon(Icons.wb_sunny_outlined),
                  label: const Text('Morning Briefing'),
                )
              else
                FilledButton.icon(
                  onPressed: () => context.push('/reflection'),
                  icon: const Icon(Icons.nightlight_round),
                  label: const Text('今夜の振り返りをはじめる'),
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => context.push(
                  _isMorning ? '/reflection' : '/morning',
                ),
                icon: Icon(
                  _isMorning
                      ? Icons.nightlight_round
                      : Icons.wb_sunny_outlined,
                ),
                label: Text(
                  _isMorning ? '夜の振り返り（デモ）' : 'Morning Briefing（デモ）',
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await ref.read(apiClientProvider).seedDemo();
                    messenger.showSnackBar(
                      const SnackBar(content: Text('デモ用メモリをシードしました')),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('シード失敗: $e')),
                    );
                  }
                },
                child: const Text('デモ用メモリをシード'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
