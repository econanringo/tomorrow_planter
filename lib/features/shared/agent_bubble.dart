import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../theme.dart';
import 'typing_dots.dart';

class AgentBubble extends StatelessWidget {
  const AgentBubble({super.key, required this.message});

  final ChatMessage message;

  Color _bubbleColor(ColorScheme scheme) {
    if (message.isUser) return scheme.primaryContainer;
    switch (message.agentName) {
      case 'Reflection':
        return scheme.secondaryContainer;
      case 'Memory':
        return scheme.tertiaryContainer;
      case 'Priority':
        return scheme.surfaceContainerHigh;
      case 'Planner':
        return MaterialTheme.customColor1.light.colorContainer;
      case 'Coach':
        return scheme.primaryContainer;
      default:
        return scheme.surfaceContainerHighest;
    }
  }

  Color _onBubble(ColorScheme scheme) {
    if (message.isUser) return scheme.onPrimaryContainer;
    switch (message.agentName) {
      case 'Reflection':
        return scheme.onSecondaryContainer;
      case 'Memory':
        return scheme.onTertiaryContainer;
      case 'Planner':
        return MaterialTheme.customColor1.light.onColorContainer;
      case 'Coach':
        return scheme.onPrimaryContainer;
      default:
        return scheme.onSurface;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final align =
        message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Text(
            message.agentName,
            style: textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.85,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _bubbleColor(scheme),
              borderRadius: BorderRadius.circular(16),
            ),
            child: message.isTyping
                ? TypingDots(color: _onBubble(scheme).withValues(alpha: 0.7))
                : Text(
                    message.message,
                    style: textTheme.bodyMedium?.copyWith(
                      color: _onBubble(scheme),
                    ),
                  ),
          ),
          if (!message.isTyping && message.confidence != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'confidence ${(message.confidence! * 100).round()}%',
                style: textTheme.labelSmall?.copyWith(
                  color: scheme.outline,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
