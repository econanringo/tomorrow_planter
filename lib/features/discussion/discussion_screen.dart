import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/api_provider.dart';
import '../../data/models.dart';
import '../shared/agent_bubble.dart';
import '../shared/schedule_list.dart';

const _wideBreakpoint = 900.0;

class DiscussionScreen extends ConsumerStatefulWidget {
  const DiscussionScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<DiscussionScreen> createState() => _DiscussionScreenState();
}

class _DiscussionScreenState extends ConsumerState<DiscussionScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <ChatMessage>[];
  List<ScheduleItem> _schedule = [];
  String? _topPriority;
  String? _coachMessage;
  bool _running = false;
  bool _started = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runDiscussion());
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _showTyping(String agentName) {
    _messages.removeWhere((m) => m.isTyping);
    _messages.add(
      ChatMessage(agentName: agentName, message: '', isTyping: true),
    );
  }

  void _replaceTypingWithMessage(ChatMessage message) {
    _messages.removeWhere((m) => m.isTyping);
    _messages.add(message);
  }

  Future<void> _runDiscussion({String? intervention}) async {
    if (_running) return;
    setState(() {
      _running = true;
      _error = null;
    });

    final client = ref.read(apiClientProvider);
    final stream = intervention == null
        ? client.startDiscussion(sessionId: widget.sessionId)
        : client.interveneDiscussion(
            sessionId: widget.sessionId,
            message: intervention,
          );

    try {
      if (intervention != null) {
        setState(() {
          _messages.add(
            ChatMessage(agentName: 'あなた', message: intervention, isUser: true),
          );
        });
        _scrollToBottom();
      }
      await for (final event in stream) {
        if (!mounted) return;
        if (event.type == 'agent_composing' && event.agentName.isNotEmpty) {
          setState(() => _showTyping(event.agentName));
          _scrollToBottom();
          continue;
        }
        if (event.type == 'agent_message' && event.message.isNotEmpty) {
          setState(() {
            _replaceTypingWithMessage(
              ChatMessage(
                agentName: event.agentName,
                message: event.message,
                confidence: event.confidence,
              ),
            );
            final meta = event.meta;
            if (meta != null && meta['schedule'] is List) {
              _schedule = (meta['schedule'] as List)
                  .map((e) => ScheduleItem.fromJson(e as Map<String, dynamic>))
                  .toList();
              _topPriority = meta['top_priority'] as String?;
            }
            if (event.agentName == 'Coach') {
              _coachMessage = event.message;
            }
          });
          _scrollToBottom();
        }
        if (event.type == 'discussion_complete') {
          final meta = event.meta;
          if (meta != null) {
            setState(() {
              _messages.removeWhere((m) => m.isTyping);
              if (meta['schedule'] is List) {
                _schedule = (meta['schedule'] as List)
                    .map(
                      (e) => ScheduleItem.fromJson(e as Map<String, dynamic>),
                    )
                    .toList();
              }
              _topPriority = meta['top_priority'] as String?;
              _coachMessage = meta['coach_message'] as String? ?? _coachMessage;
            });
          }
        }
      }
      _started = true;
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _running = false;
          _messages.removeWhere((m) => m.isTyping);
        });
      }
    }
  }

  Future<void> _intervene() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    await _runDiscussion(intervention: text);
  }

  Widget _buildChatPane({required bool showInlineSchedule}) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              ..._messages.map((m) => AgentBubble(message: m)),
              if (showInlineSchedule && _schedule.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'たたき台の予定',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ScheduleList(
                  schedule: _schedule,
                  topPriority: _topPriority,
                ),
              ],
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: !_running && _started,
                    decoration: const InputDecoration(
                      hintText: '議論に参加する（例: 今日は意外と元気！）',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _intervene(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _running || !_started ? null : _intervene,
                  child: const Text('発言'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlanPane() {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ColoredBox(
      color: scheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text('Tomorrow Plan', style: textTheme.titleLarge),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              children: [
                if (_schedule.isEmpty)
                  Text(
                    '議論が進むとここに明日の予定が現れます',
                    style: textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  )
                else ...[
                  ScheduleList(
                    schedule: _schedule,
                    topPriority: _topPriority,
                  ),
                  if (_coachMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _coachMessage!,
                      style: textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 会議'),
        actions: [
          TextButton(
            onPressed: !_started || _running
                ? null
                : () => context.push('/plan/${widget.sessionId}'),
            child: const Text('予定を確認'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_running) const LinearProgressIndicator(),
          if (_error != null)
            Material(
              color: scheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _error!,
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
              ),
            ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= _wideBreakpoint;
                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 58,
                        child: _buildChatPane(showInlineSchedule: false),
                      ),
                      VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: scheme.outlineVariant,
                      ),
                      Expanded(
                        flex: 42,
                        child: _buildPlanPane(),
                      ),
                    ],
                  );
                }
                return _buildChatPane(showInlineSchedule: true);
              },
            ),
          ),
        ],
      ),
    );
  }
}
