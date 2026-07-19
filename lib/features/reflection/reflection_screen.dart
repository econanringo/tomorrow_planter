import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/api_provider.dart';
import '../../data/models.dart';
import '../shared/agent_bubble.dart';

class ReflectionScreen extends ConsumerStatefulWidget {
  const ReflectionScreen({super.key});

  @override
  ConsumerState<ReflectionScreen> createState() => _ReflectionScreenState();
}

class _ReflectionScreenState extends ConsumerState<ReflectionScreen> {
  final _controller = TextEditingController();
  final _messages = <ChatMessage>[];
  String? _sessionId;
  bool _starting = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final res = await ref.read(apiClientProvider).startReflection();
      setState(() {
        _sessionId = res.sessionId;
        _messages.add(
          ChatMessage(agentName: 'Reflection', message: res.greeting),
        );
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    final sessionId = _sessionId;
    if (text.isEmpty || sessionId == null || _sending) return;

    setState(() {
      _sending = true;
      _messages.add(ChatMessage(agentName: 'あなた', message: text, isUser: true));
      _controller.clear();
    });

    try {
      await for (final event in ref.read(apiClientProvider).postReflectionMessage(
            sessionId: sessionId,
            message: text,
          )) {
        if (event.type == 'agent_message' && event.message.isNotEmpty) {
          setState(() {
            _messages.add(
              ChatMessage(
                agentName: event.agentName,
                message: event.message,
                confidence: event.confidence,
              ),
            );
          });
        }
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reflection'),
        actions: [
          if (_sessionId != null)
            TextButton(
              onPressed: _sending
                  ? null
                  : () => context.push('/discussion/$_sessionId'),
              child: const Text('議論へ'),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_starting) const LinearProgressIndicator(),
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
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return AgentBubble(message: _messages[index]);
              },
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
                      enabled: !_starting && !_sending && _sessionId != null,
                      decoration: const InputDecoration(
                        hintText: '今日のことを雑談するように…',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _sending || _sessionId == null ? null : _send,
                    child: const Icon(Icons.send),
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
