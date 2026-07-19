import 'package:flutter/material.dart';

import '../../../data/models.dart';

/// AIタスク分解の提案中 UI。
///
/// SeedPulse / StageCrossfade / SubtaskReveal を備え、
/// SSE の `decompose_progress.stage` と連動させる。
class DecomposeThinkingPanel extends StatefulWidget {
  const DecomposeThinkingPanel({
    super.key,
    required this.stage,
    this.subtasks = const [],
    this.revealing = false,
    this.onCancel,
  });

  /// 現在の思考段階（SSE `stage`）。
  final DecomposeStage stage;

  /// `decompose_complete` 後のサブタスク。revealing 時に順次表示。
  final List<SubTaskDraft> subtasks;

  /// true のときスケルトンからカードへ遷移する。
  final bool revealing;

  final VoidCallback? onCancel;

  @override
  State<DecomposeThinkingPanel> createState() => _DecomposeThinkingPanelState();
}

class _DecomposeThinkingPanelState extends State<DecomposeThinkingPanel>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;
  int _visibleCount = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseScale = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (widget.revealing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startReveal();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant DecomposeThinkingPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse();
    if (widget.revealing &&
        (!oldWidget.revealing ||
            widget.subtasks.length != oldWidget.subtasks.length)) {
      _startReveal();
    }
    if (!widget.revealing && oldWidget.revealing) {
      setState(() => _visibleCount = 0);
    }
  }

  void _syncPulse() {
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce || widget.revealing) {
      _pulseController.stop();
      _pulseController.value = 1;
    } else if (!_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    }
  }

  Future<void> _startReveal() async {
    setState(() => _visibleCount = 0);
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) {
      setState(() => _visibleCount = widget.subtasks.length);
      return;
    }
    for (var i = 0; i < widget.subtasks.length; i++) {
      if (!mounted || !widget.revealing) return;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (!mounted || !widget.revealing) return;
      setState(() => _visibleCount = i + 1);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  int get _stageIndex => DecomposeStage.values.indexOf(widget.stage);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final reduce = MediaQuery.disableAnimationsOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.onCancel != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: widget.onCancel,
              child: const Text('キャンセル'),
            ),
          ),
        const SizedBox(height: 8),
        Center(
          child: reduce
              ? Icon(Icons.eco_outlined, size: 64, color: scheme.primary)
              : ScaleTransition(
                  scale: _pulseScale,
                  child: Icon(
                    Icons.eco_outlined,
                    size: 64,
                    color: scheme.primary,
                  ),
                ),
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: reduce
              ? Duration.zero
              : const Duration(milliseconds: 300),
          child: Text(
            widget.revealing ? '提案をまとめています' : widget.stage.label,
            key: ValueKey(
              widget.revealing ? 'revealing' : widget.stage.name,
            ),
            textAlign: TextAlign.center,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (!widget.revealing && reduce)
          const LinearProgressIndicator(),
        const SizedBox(height: 24),
        ...DecomposeStage.values.map((stage) {
          final index = DecomposeStage.values.indexOf(stage);
          final done = widget.revealing || index < _stageIndex;
          final active = !widget.revealing && index == _stageIndex;
          return _StageRow(
            label: stage.label,
            done: done,
            active: active,
            pulse: active && !reduce,
            pulseAnimation: _pulseScale,
          );
        }),
        const SizedBox(height: 28),
        Text(
          '提案プレビュー',
          style: textTheme.titleSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        if (!widget.revealing || _visibleCount == 0)
          ...List.generate(
            widget.revealing && widget.subtasks.isNotEmpty
                ? widget.subtasks.length.clamp(3, 8)
                : 5,
            (i) => const _SkeletonRow(),
          )
        else
          ...List.generate(_visibleCount, (i) {
            final item = widget.subtasks[i];
            return _SubtaskRevealCard(
              key: ValueKey('subtask-$i-${item.title}'),
              draft: item,
              reduceMotion: reduce,
            );
          }),
      ],
    );
  }
}

class _StageRow extends StatelessWidget {
  const _StageRow({
    required this.label,
    required this.done,
    required this.active,
    required this.pulse,
    required this.pulseAnimation,
  });

  final String label;
  final bool done;
  final bool active;
  final bool pulse;
  final Animation<double> pulseAnimation;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Widget leading;
    if (done) {
      leading = Icon(Icons.check_circle, color: scheme.primary, size: 22);
    } else if (active && pulse) {
      leading = ScaleTransition(
        scale: pulseAnimation,
        child: Icon(Icons.radio_button_checked, color: scheme.primary, size: 22),
      );
    } else if (active) {
      leading = Icon(Icons.radio_button_checked, color: scheme.primary, size: 22);
    } else {
      leading = Icon(
        Icons.radio_button_unchecked,
        color: scheme.outlineVariant,
        size: 22,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active || done
                    ? scheme.onSurface
                    : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonRow extends StatefulWidget {
  const _SkeletonRow();

  @override
  State<_SkeletonRow> createState() => _SkeletonRowState();
}

class _SkeletonRowState extends State<_SkeletonRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduce = MediaQuery.disableAnimationsOf(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: reduce
          ? Container(
              height: 56,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
            )
          : AnimatedBuilder(
              animation: _shimmer,
              builder: (context, child) {
                return Container(
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment(-1.0 + 2 * _shimmer.value, 0),
                      end: Alignment(1.0 + 2 * _shimmer.value, 0),
                      colors: [
                        scheme.surfaceContainerHighest,
                        scheme.surfaceContainerHigh,
                        scheme.surfaceContainerHighest,
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _SubtaskRevealCard extends StatefulWidget {
  const _SubtaskRevealCard({
    super.key,
    required this.draft,
    required this.reduceMotion,
  });

  final SubTaskDraft draft;
  final bool reduceMotion;

  @override
  State<_SubtaskRevealCard> createState() => _SubtaskRevealCardState();
}

class _SubtaskRevealCardState extends State<_SubtaskRevealCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 280),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final card = Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.spa_outlined, color: scheme.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.draft.title,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.draft.suggestedDate +
                      (widget.draft.estimateMinutes != null
                          ? ' · 約${widget.draft.estimateMinutes}分'
                          : ''),
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (widget.reduceMotion) return card;

    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _offset, child: card),
    );
  }
}
