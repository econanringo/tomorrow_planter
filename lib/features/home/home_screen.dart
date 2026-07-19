import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth_provider.dart';
import '../../data/api_provider.dart';
import '../../data/models.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  List<ParentTask> _tasks = [];
  bool _loadingTasks = true;
  bool _updating = false;
  String? _tasksError;

  bool get _isMorning {
    final hour = DateTime.now().hour;
    return hour >= 5 && hour < 11;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTasks());
  }

  Future<void> _loadTasks() async {
    setState(() {
      _loadingTasks = true;
      _tasksError = null;
    });
    try {
      final tasks = await ref.read(apiClientProvider).listTasks();
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _loadingTasks = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingTasks = false;
        _tasksError = '$e';
      });
    }
  }

  String _formatYmd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String _slashFromYmd(String ymd) {
    final parts = ymd.split('-');
    if (parts.length != 3) return ymd;
    return '${parts[0]}/${parts[1]}/${parts[2]}';
  }

  List<_HomeSubtaskRow> get _todoRows {
    final rows = <_HomeSubtaskRow>[];
    for (final task in _tasks) {
      for (final sub in task.subtasks) {
        if (sub.status == 'skipped') continue;
        rows.add(_HomeSubtaskRow(parent: task, subtask: sub));
      }
    }
    rows.sort((a, b) {
      if (a.subtask.isDone != b.subtask.isDone) {
        return a.subtask.isDone ? 1 : -1;
      }
      final da = a.subtask.scheduledDate ?? a.subtask.suggestedDate;
      final db = b.subtask.scheduledDate ?? b.subtask.suggestedDate;
      final byDate = da.compareTo(db);
      if (byDate != 0) return byDate;
      return a.subtask.order.compareTo(b.subtask.order);
    });
    return rows;
  }

  Future<void> _toggleSubtask(_HomeSubtaskRow row) async {
    if (_updating) return;
    final next = row.subtask.isDone ? 'accepted' : 'done';
    setState(() => _updating = true);
    try {
      await ref.read(apiClientProvider).updateSubTask(
            taskId: row.parent.id,
            subtaskId: row.subtask.id,
            status: next,
          );
      if (!mounted) return;
      setState(() => _updating = false);
      await _loadTasks();
    } catch (e) {
      if (!mounted) return;
      setState(() => _updating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新に失敗しました: $e')),
      );
    }
  }

  Future<void> _toggleParent(ParentTask task) async {
    if (_updating) return;
    final next = task.status == 'done' ? 'open' : 'done';
    setState(() => _updating = true);
    try {
      await ref.read(apiClientProvider).updateTask(
            taskId: task.id,
            status: next,
          );
      if (!mounted) return;
      setState(() => _updating = false);
      await _loadTasks();
    } catch (e) {
      if (!mounted) return;
      setState(() => _updating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新に失敗しました: $e')),
      );
    }
  }

  Future<void> _editSubtask(_HomeSubtaskRow row) async {
    final sub = row.subtask;
    final titleController = TextEditingController(text: sub.title);
    final minutesController = TextEditingController(
      text: sub.estimateMinutes?.toString() ?? '',
    );
    var dateYmd = sub.scheduledDate ?? sub.suggestedDate;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: const Text('サブタスクを編集'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'タイトル',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final parts = dateYmd.split('-');
                        var initial = DateTime.now();
                        if (parts.length == 3) {
                          initial = DateTime(
                            int.parse(parts[0]),
                            int.parse(parts[1]),
                            int.parse(parts[2]),
                          );
                        }
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: initial,
                          firstDate:
                              DateTime.now().subtract(const Duration(days: 30)),
                          lastDate:
                              DateTime.now().add(const Duration(days: 730)),
                        );
                        if (picked != null) {
                          setLocal(() => dateYmd = _formatYmd(picked));
                        }
                      },
                      icon: const Icon(Icons.event_outlined),
                      label: Text(dateYmd),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: minutesController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '所要時間（分）',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('キャンセル'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );

    final title = titleController.text.trim();
    titleController.dispose();
    final minutesText = minutesController.text.trim();
    minutesController.dispose();
    if (saved != true || title.isEmpty) return;

    setState(() => _updating = true);
    try {
      await ref.read(apiClientProvider).updateSubTask(
            taskId: row.parent.id,
            subtaskId: sub.id,
            title: title,
            suggestedDate: dateYmd,
            scheduledDate: dateYmd,
            estimateMinutes: int.tryParse(minutesText),
          );
      if (!mounted) return;
      setState(() => _updating = false);
      await _loadTasks();
    } catch (e) {
      if (!mounted) return;
      setState(() => _updating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('編集の保存に失敗しました: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final user = ref.watch(currentUserProvider);
    final todos = _todoRows;
    final seeds = _tasks.where((t) => t.subtasks.isEmpty).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tomorrow Planter'),
        actions: [
          IconButton(
            tooltip: 'タスクを更新',
            onPressed: _loadingTasks ? null : _loadTasks,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'サインアウト',
            onPressed: () => ref.read(firebaseAuthProvider).signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadTasks,
          child: ListView(
            padding: const EdgeInsets.all(24),
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
              const SizedBox(height: 28),
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
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  await context.push('/tasks');
                  if (mounted) await _loadTasks();
                },
                icon: const Icon(Icons.eco_outlined),
                label: const Text('Task Seed（AIでタスクを分解）'),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'ToDo（サブタスク）',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await context.push('/tasks');
                      if (mounted) await _loadTasks();
                    },
                    child: const Text('すべて'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'チェックで完了。鉛筆アイコンからタイトル・日付・所要時間を変更できます。',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              if (_loadingTasks)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_tasksError != null)
                Text(
                  'タスクの読み込みに失敗しました',
                  style: textTheme.bodyMedium?.copyWith(color: scheme.error),
                )
              else if (todos.isEmpty && seeds.isEmpty)
                Text(
                  'まだタスクがありません。Task Seed から種を植えましょう。',
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                )
              else if (todos.isEmpty)
                Text(
                  '分解済みのサブタスクはまだありません。',
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                )
              else
                ...todos.take(20).map((row) {
                  final date =
                      row.subtask.scheduledDate ?? row.subtask.suggestedDate;
                  final minutes = row.subtask.estimateMinutes;
                  final done = row.subtask.isDone;
                  return CheckboxListTile(
                    value: done,
                    onChanged: _updating ? null : (_) => _toggleSubtask(row),
                    secondary: IconButton(
                      tooltip: '編集',
                      onPressed: _updating ? null : () => _editSubtask(row),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    title: Text(
                      row.subtask.title,
                      style: done
                          ? TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: scheme.onSurfaceVariant,
                            )
                          : textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                    ),
                    subtitle: Text(
                      '${_slashFromYmd(date)}'
                      '${minutes != null ? ' · 約$minutes分' : ''}'
                      ' · ${row.parent.title}',
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  );
                }),
              if (!_loadingTasks && seeds.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  '直接追加した種',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                ...seeds.map((task) {
                  final done = task.status == 'done';
                  return CheckboxListTile(
                    value: done,
                    onChanged: _updating ? null : (_) => _toggleParent(task),
                    title: Text(
                      task.title,
                      style: done
                          ? TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: scheme.onSurfaceVariant,
                            )
                          : null,
                    ),
                    subtitle: Text('期限 ${_slashFromYmd(task.deadline)}'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  );
                }),
              ],
              const SizedBox(height: 24),
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

class _HomeSubtaskRow {
  const _HomeSubtaskRow({required this.parent, required this.subtask});

  final ParentTask parent;
  final SavedSubTask subtask;
}
