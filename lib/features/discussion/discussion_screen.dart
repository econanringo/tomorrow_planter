import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/api_provider.dart';
import '../../data/models.dart';
import '../shared/agent_bubble.dart';
import '../shared/schedule_list.dart';

class DiscussionScreen extends ConsumerStatefulWidget {
  const DiscussionScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<DiscussionScreen> createState() => _DiscussionScreenState();
}

class _DiscussionScreenState extends ConsumerState<DiscussionScreen> {
  final _controller = TextEditingController();
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
    super.dispose();
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
      }
      await for (final event in stream) {
        if (!mounted) return;
        if (event.type == 'agent_message' && event.message.isNotEmpty) {
          setState(() {
            _messages.add(
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
        }
        if (event.type == 'discussion_complete') {
          final meta = event.meta;
          if (meta != null) {
            setState(() {
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
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _intervene() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    await _runDiscussion(intervention: text);
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
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ..._messages.map((m) => AgentBubble(message: m)),
                if (_schedule.isNotEmpty) ...[
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
      ),
    );
  }
}
