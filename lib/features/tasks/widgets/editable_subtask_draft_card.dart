import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/models.dart';

/// AI提案後にタイトル・日付・所要時間を手編集するカード。
class EditableSubtaskDraftCard extends StatefulWidget {
  const EditableSubtaskDraftCard({
    super.key,
    required this.draft,
    required this.index,
    required this.onChanged,
    required this.onRemove,
  });

  final SubTaskDraft draft;
  final int index;
  final ValueChanged<SubTaskDraft> onChanged;
  final VoidCallback onRemove;

  @override
  State<EditableSubtaskDraftCard> createState() =>
      _EditableSubtaskDraftCardState();
}

class _EditableSubtaskDraftCardState extends State<EditableSubtaskDraftCard> {
  late final TextEditingController _titleController;
  late final TextEditingController _minutesController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.draft.title);
    _minutesController = TextEditingController(
      text: widget.draft.estimateMinutes?.toString() ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant EditableSubtaskDraftCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.draft.title != widget.draft.title &&
        _titleController.text != widget.draft.title) {
      _titleController.text = widget.draft.title;
    }
    final minutesText = widget.draft.estimateMinutes?.toString() ?? '';
    if (oldWidget.draft.estimateMinutes != widget.draft.estimateMinutes &&
        _minutesController.text != minutesText) {
      _minutesController.text = minutesText;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final parts = widget.draft.suggestedDate.split('-');
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
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked == null) return;
    final ymd =
        '${picked.year.toString().padLeft(4, '0')}-'
        '${picked.month.toString().padLeft(2, '0')}-'
        '${picked.day.toString().padLeft(2, '0')}';
    widget.onChanged(widget.draft.copyWith(suggestedDate: ymd));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  '${widget.index + 1}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: '削除',
                  onPressed: widget.onRemove,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'タイトル',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) =>
                  widget.onChanged(widget.draft.copyWith(title: v)),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.event_outlined, size: 18),
                    label: Text(widget.draft.suggestedDate),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _minutesController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: '分',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) {
                      final parsed = int.tryParse(v);
                      widget.onChanged(
                        widget.draft.copyWith(
                          estimateMinutes: parsed,
                          clearEstimate: v.isEmpty,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
