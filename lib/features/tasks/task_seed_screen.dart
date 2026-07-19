import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api_provider.dart';
import '../../data/models.dart';
import 'widgets/decompose_thinking_panel.dart';
import 'widgets/editable_subtask_draft_card.dart';

enum _SeedUiState { idle, thinking, revealing, review, error }

/// 日中の Task Seed 画面。
///
/// Backend の SSE が未接続の間は、decompose の各 stage を
/// 最低 400ms ずつ進めるローカルシミュレーションで thinking UI を駆動する。
/// 直接追加・提案採用は `POST /v1/tasks` で Firestore に保存する。
class TaskSeedScreen extends ConsumerStatefulWidget {
  const TaskSeedScreen({super.key});

  @override
  ConsumerState<TaskSeedScreen> createState() => _TaskSeedScreenState();
}

class _TaskSeedScreenState extends ConsumerState<TaskSeedScreen> {
  final _titleController = TextEditingController();
  DateTime? _deadline;
  _SeedUiState _uiState = _SeedUiState.idle;
  DecomposeStage _stage = DecomposeStage.inspect;
  List<SubTaskDraft> _subtasks = [];
  List<ParentTask> _savedTasks = [];
  String? _error;
  bool _cancelled = false;
  bool _loadingList = true;
  bool _saving = false;

  String _formatYmd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String _formatSlash(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/'
      '${d.day.toString().padLeft(2, '0')}';

  String _slashFromYmd(String ymd) {
    final parts = ymd.split('-');
    if (parts.length != 3) return ymd;
    return '${parts[0]}/${parts[1]}/${parts[2]}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTasks());
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    setState(() {
      _loadingList = true;
      _error = null;
    });
    try {
      final tasks = await ref.read(apiClientProvider).listTasks();
      if (!mounted) return;
      setState(() {
        _savedTasks = tasks;
        _loadingList = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingList = false;
        _error = 'タスク一覧の取得に失敗しました: $e';
      });
    }
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now.add(const Duration(days: 5)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _deadline = picked);
    }
  }

  bool _validateInput() {
    final title = _titleController.text.trim();
    if (title.isEmpty || _deadline == null) {
      setState(() {
        _error = 'タイトルと期限を入力してください';
        _uiState = _SeedUiState.error;
      });
      return false;
    }
    return true;
  }

  Future<void> _addTaskDirectly() async {
    if (!_validateInput() || _saving) return;

    final title = _titleController.text.trim();
    final deadline = _formatYmd(_deadline!);
    setState(() {
      _error = null;
      _uiState = _SeedUiState.idle;
      _saving = true;
    });

    try {
      await ref.read(apiClientProvider).createTask(
            title: title,
            deadline: deadline,
          );
      if (!mounted) return;
      _titleController.clear();
      setState(() {
        _deadline = null;
        _saving = false;
      });
      await _loadTasks();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('「$title」を保存しました')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '保存に失敗しました: $e';
        _uiState = _SeedUiState.error;
      });
    }
  }

  Future<void> _removeSavedTask(ParentTask task) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).deleteTask(taskId: task.id);
      if (!mounted) return;
      setState(() => _saving = false);
      await _loadTasks();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '削除に失敗しました: $e';
      });
    }
  }

  Future<void> _acceptProposal() async {
    if (_saving || _deadline == null || _subtasks.isEmpty) return;
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final cleaned = _subtasks
        .where((s) => s.title.trim().isNotEmpty)
        .toList()
        .asMap()
        .entries
        .map((e) => e.value.copyWith(order: e.key, title: e.value.title.trim()))
        .toList();
    if (cleaned.isEmpty) {
      setState(() {
        _error = 'タイトル付きのサブタスクを1つ以上残してください';
        _uiState = _SeedUiState.error;
      });
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).createTask(
            title: title,
            deadline: _formatYmd(_deadline!),
            subtasks: cleaned,
          );
      if (!mounted) return;
      _titleController.clear();
      setState(() {
        _deadline = null;
        _saving = false;
      });
      _reset();
      await _loadTasks();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('提案を保存しました')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '提案の保存に失敗しました: $e';
        _uiState = _SeedUiState.error;
      });
    }
  }

  void _updateDraft(int index, SubTaskDraft draft) {
    setState(() {
      _subtasks = List<SubTaskDraft>.from(_subtasks)..[index] = draft;
    });
  }

  void _removeDraft(int index) {
    setState(() {
      _subtasks = List<SubTaskDraft>.from(_subtasks)..removeAt(index);
      for (var i = 0; i < _subtasks.length; i++) {
        _subtasks[i] = _subtasks[i].copyWith(order: i);
      }
    });
  }

  void _addDraft() {
    final base = _deadline != null
        ? _formatYmd(_deadline!)
        : _formatYmd(DateTime.now());
    setState(() {
      _subtasks = [
        ..._subtasks,
        SubTaskDraft(
          title: '',
          suggestedDate: base,
          estimateMinutes: 30,
          order: _subtasks.length,
        ),
      ];
    });
  }

  Future<void> _toggleSubtaskDone(ParentTask task, SavedSubTask sub) async {
    if (_saving) return;
    final next = sub.isDone ? 'accepted' : 'done';
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).updateSubTask(
            taskId: task.id,
            subtaskId: sub.id,
            status: next,
          );
      if (!mounted) return;
      setState(() => _saving = false);
      await _loadTasks();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '更新に失敗しました: $e';
      });
    }
  }

  Future<void> _toggleParentDone(ParentTask task) async {
    if (_saving) return;
    final next = task.status == 'done' ? 'open' : 'done';
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).updateTask(
            taskId: task.id,
            status: next,
          );
      if (!mounted) return;
      setState(() => _saving = false);
      await _loadTasks();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '更新に失敗しました: $e';
      });
    }
  }

  Future<void> _editSavedSubtask(ParentTask task, SavedSubTask sub) async {
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
                          firstDate: DateTime.now()
                              .subtract(const Duration(days: 30)),
                          lastDate:
                              DateTime.now().add(const Duration(days: 730)),
                        );
                        if (picked != null) {
                          setLocal(() {
                            dateYmd = _formatYmd(picked);
                          });
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

    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).updateSubTask(
            taskId: task.id,
            subtaskId: sub.id,
            title: title,
            suggestedDate: dateYmd,
            scheduledDate: dateYmd,
            estimateMinutes: int.tryParse(minutesText),
          );
      if (!mounted) return;
      setState(() => _saving = false);
      await _loadTasks();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '編集の保存に失敗しました: $e';
      });
    }
  }

  Future<void> _decompose() async {
    if (!_validateInput()) return;

    final title = _titleController.text.trim();
    final deadline = _formatYmd(_deadline!);
    _cancelled = false;
    setState(() {
      _error = null;
      _uiState = _SeedUiState.thinking;
      _stage = DecomposeStage.inspect;
      _subtasks = [];
    });

    final stageSeenAt = <DecomposeStage, DateTime>{
      DecomposeStage.inspect: DateTime.now(),
    };

    try {
      final stream = ref.read(apiClientProvider).decomposeTask(
            title: title,
            deadline: deadline,
          );

      await for (final event in stream) {
        if (_cancelled || !mounted) return;

        if (event.type == 'error') {
          setState(() {
            _error = event.message.isNotEmpty
                ? event.message
                : 'AIによる分解に失敗しました';
            _uiState = _SeedUiState.error;
          });
          return;
        }

        final stageName = event.meta?['stage'] as String?;
        final nextStage = DecomposeStageX.fromSse(stageName);
        if (nextStage != null &&
            (event.type == 'decompose_progress' ||
                event.type == 'decompose_started')) {
          final prev = _stage;
          final elapsed = DateTime.now().difference(
            stageSeenAt[prev] ?? DateTime.now(),
          );
          const minStage = Duration(milliseconds: 400);
          if (elapsed < minStage) {
            await Future<void>.delayed(minStage - elapsed);
          }
          if (_cancelled || !mounted) return;
          setState(() => _stage = nextStage);
          stageSeenAt[nextStage] = DateTime.now();
        }

        if (event.type == 'decompose_complete') {
          final raw = event.meta?['subtasks'];
          final drafts = <SubTaskDraft>[];
          if (raw is List) {
            for (final item in raw) {
              if (item is Map<String, dynamic>) {
                drafts.add(SubTaskDraft.fromJson(item));
              } else if (item is Map) {
                drafts.add(
                  SubTaskDraft.fromJson(Map<String, dynamic>.from(item)),
                );
              }
            }
          }
          if (drafts.isEmpty) {
            setState(() {
              _error = 'AIから有効なサブタスクが返りませんでした';
              _uiState = _SeedUiState.error;
            });
            return;
          }

          setState(() {
            _stage = DecomposeStage.schedule;
            _subtasks = drafts;
            _uiState = _SeedUiState.revealing;
          });

          final revealMs = 120 + drafts.length * 100;
          await Future<void>.delayed(Duration(milliseconds: revealMs));
          if (_cancelled || !mounted) return;
          setState(() => _uiState = _SeedUiState.review);
          return;
        }
      }

      if (!mounted || _cancelled) return;
      if (_uiState == _SeedUiState.thinking) {
        setState(() {
          _error = '分解結果を受信できませんでした';
          _uiState = _SeedUiState.error;
        });
      }
    } catch (e) {
      if (!mounted || _cancelled) return;
      setState(() {
        _error = 'AI分解に失敗しました: $e';
        _uiState = _SeedUiState.error;
      });
    }
  }

  void _cancel() {
    _cancelled = true;
    setState(() {
      _uiState = _SeedUiState.idle;
      _subtasks = [];
      _stage = DecomposeStage.inspect;
    });
  }

  void _reset() {
    setState(() {
      _uiState = _SeedUiState.idle;
      _subtasks = [];
      _stage = DecomposeStage.inspect;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final busy = _uiState == _SeedUiState.thinking ||
        _uiState == _SeedUiState.revealing ||
        _saving;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Seed'),
        actions: [
          IconButton(
            tooltip: '再読み込み',
            onPressed: busy ? null : _loadTasks,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              '大きなタスクを種にして、AIと一緒に分解します',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'タイトルと期限を入力し、「AIでタスクを分解」か「タスクを直接追加」を選んでください。',
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _titleController,
              enabled: !busy,
              decoration: const InputDecoration(
                labelText: 'タスク（種）',
                hintText: '例: レポート提出',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: busy ? null : _pickDeadline,
              icon: const Icon(Icons.event_outlined),
              label: Text(
                _deadline == null
                    ? '期限を選ぶ'
                    : '期限: ${_formatSlash(_deadline!)}',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: busy ? null : _decompose,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('AIでタスクを分解'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: busy ? null : _addTaskDirectly,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_task_outlined),
              label: const Text('タスクを直接追加'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Material(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _error!,
                    style: TextStyle(color: scheme.onErrorContainer),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 28),
            Text(
              '保存済みのタスク',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            if (_loadingList)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_savedTasks.isEmpty)
              Text(
                'まだ保存されたタスクはありません。',
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              )
            else
              ..._savedTasks.map((task) {
                final subtitle = task.subtasks.isEmpty
                    ? '期限: ${_slashFromYmd(task.deadline)} · ${task.status}'
                    : '期限: ${_slashFromYmd(task.deadline)} · '
                        'サブタスク ${task.subtasks.length} 件';
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ExpansionTile(
                    leading: task.subtasks.isEmpty
                        ? Checkbox(
                            value: task.status == 'done',
                            onChanged: busy
                                ? null
                                : (_) => _toggleParentDone(task),
                          )
                        : Icon(
                            Icons.account_tree_outlined,
                            color: scheme.primary,
                          ),
                    title: Text(
                      task.title,
                      style: task.status == 'done'
                          ? textTheme.titleMedium?.copyWith(
                              decoration: TextDecoration.lineThrough,
                              color: scheme.onSurfaceVariant,
                            )
                          : null,
                    ),
                    subtitle: Text(subtitle),
                    children: [
                      ...task.subtasks.map(
                        (s) => CheckboxListTile(
                          value: s.isDone,
                          onChanged:
                              busy ? null : (_) => _toggleSubtaskDone(task, s),
                          secondary: IconButton(
                            tooltip: '編集',
                            onPressed:
                                busy ? null : () => _editSavedSubtask(task, s),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          title: Text(
                            s.title,
                            style: s.isDone
                                ? TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                    color: scheme.onSurfaceVariant,
                                  )
                                : null,
                          ),
                          subtitle: Text(
                            '${s.scheduledDate ?? s.suggestedDate}'
                            '${s.estimateMinutes != null ? ' · 約${s.estimateMinutes}分' : ''}',
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ),
                      if (task.subtasks.isEmpty)
                        const ListTile(
                          dense: true,
                          title: Text('サブタスクはまだありません（親タスクをチェックで完了）'),
                        ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed:
                              busy ? null : () => _removeSavedTask(task),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('削除'),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            if (_uiState == _SeedUiState.thinking ||
                _uiState == _SeedUiState.revealing) ...[
              const SizedBox(height: 28),
              DecomposeThinkingPanel(
                stage: _stage,
                subtasks: _subtasks,
                revealing: _uiState == _SeedUiState.revealing,
                onCancel: _cancel,
              ),
            ],
            if (_uiState == _SeedUiState.review) ...[
              const SizedBox(height: 28),
              Text(
                '提案を確認・編集',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'タイトル・日付・所要時間を直してから採用できます。',
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              ...List.generate(_subtasks.length, (index) {
                return EditableSubtaskDraftCard(
                  key: ValueKey('draft-$index'),
                  draft: _subtasks[index],
                  index: index,
                  onChanged: (d) => _updateDraft(index, d),
                  onRemove: () => _removeDraft(index),
                );
              }),
              OutlinedButton.icon(
                onPressed: busy ? null : _addDraft,
                icon: const Icon(Icons.add),
                label: const Text('サブタスクを追加'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: busy || _subtasks.isEmpty ? null : _acceptProposal,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('この提案を採用する'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: busy ? null : _decompose,
                child: const Text('もう一度分解する'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
