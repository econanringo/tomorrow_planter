class StartReflectionResponse {
  StartReflectionResponse({required this.sessionId, required this.greeting});

  final String sessionId;
  final String greeting;

  factory StartReflectionResponse.fromJson(Map<String, dynamic> json) {
    return StartReflectionResponse(
      sessionId: json['session_id'] as String,
      greeting: json['greeting'] as String,
    );
  }
}

class AgentSseEvent {
  AgentSseEvent({
    required this.type,
    required this.agentName,
    required this.message,
    this.replyTo,
    this.confidence,
    this.done = false,
    this.meta,
  });

  final String type;
  final String agentName;
  final String message;
  final String? replyTo;
  final double? confidence;
  final bool done;
  final Map<String, dynamic>? meta;

  factory AgentSseEvent.fromJson(Map<String, dynamic> json) {
    return AgentSseEvent(
      type: json['type'] as String? ?? 'agent_message',
      agentName: json['agent_name'] as String? ?? '',
      message: json['message'] as String? ?? '',
      replyTo: json['reply_to'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble(),
      done: json['done'] as bool? ?? false,
      meta: json['meta'] as Map<String, dynamic>?,
    );
  }
}

class ScheduleItem {
  ScheduleItem({
    required this.time,
    required this.title,
    this.durationMinutes,
    this.isPriority = false,
    this.notes,
  });

  final String time;
  final String title;
  final int? durationMinutes;
  final bool isPriority;
  final String? notes;

  factory ScheduleItem.fromJson(Map<String, dynamic> json) {
    return ScheduleItem(
      time: json['time'] as String? ?? '',
      title: json['title'] as String? ?? '',
      durationMinutes: json['duration_minutes'] as int?,
      isPriority: json['is_priority'] as bool? ?? false,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'time': time,
        'title': title,
        'duration_minutes': durationMinutes,
        'is_priority': isPriority,
        'notes': notes,
      };
}

class FinalizeResponse {
  FinalizeResponse({
    required this.reviewId,
    required this.planId,
    required this.planDate,
    required this.schedule,
    required this.coachMessage,
  });

  final String reviewId;
  final String planId;
  final String planDate;
  final List<ScheduleItem> schedule;
  final String coachMessage;

  factory FinalizeResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['schedule'] as List<dynamic>? ?? [];
    return FinalizeResponse(
      reviewId: json['review_id'] as String,
      planId: json['plan_id'] as String,
      planDate: json['plan_date'] as String,
      schedule: raw
          .map((e) => ScheduleItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      coachMessage: json['coach_message'] as String? ?? '',
    );
  }
}

class TomorrowPlan {
  TomorrowPlan({
    required this.planId,
    required this.date,
    required this.schedule,
    this.topPriority,
    this.coachMessage,
  });

  final String planId;
  final String date;
  final List<ScheduleItem> schedule;
  final String? topPriority;
  final String? coachMessage;

  factory TomorrowPlan.fromJson(Map<String, dynamic> json) {
    final raw = json['schedule'] as List<dynamic>? ?? [];
    return TomorrowPlan(
      planId: json['plan_id'] as String? ?? '',
      date: json['date'] as String? ?? '',
      schedule: raw
          .map((e) => ScheduleItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      topPriority: json['top_priority'] as String?,
      coachMessage: json['coach_message'] as String?,
    );
  }
}

class ChatMessage {
  ChatMessage({
    required this.agentName,
    required this.message,
    this.isUser = false,
    this.confidence,
    this.isTyping = false,
  });

  final String agentName;
  final String message;
  final bool isUser;
  final double? confidence;
  final bool isTyping;
}

/// SSE `decompose_progress.stage` と対応する思考段階。
enum DecomposeStage {
  inspect,
  memory,
  breakdown,
  schedule,
}

extension DecomposeStageX on DecomposeStage {
  String get label {
    switch (this) {
      case DecomposeStage.inspect:
        return '種を見つめています';
      case DecomposeStage.memory:
        return '過去の自分を参照しています';
      case DecomposeStage.breakdown:
        return 'ステップに分解しています';
      case DecomposeStage.schedule:
        return 'カレンダーに植え付けています';
    }
  }

  String get sseValue => name;

  static DecomposeStage? fromSse(String? value) {
    if (value == null) return null;
    for (final stage in DecomposeStage.values) {
      if (stage.name == value) return stage;
    }
    return null;
  }
}

class SubTaskDraft {
  SubTaskDraft({
    required this.title,
    required this.suggestedDate,
    this.estimateMinutes,
    this.order = 0,
  });

  final String title;
  final String suggestedDate;
  final int? estimateMinutes;
  final int order;

  factory SubTaskDraft.fromJson(Map<String, dynamic> json) {
    return SubTaskDraft(
      title: json['title'] as String? ?? '',
      suggestedDate: json['suggested_date'] as String? ?? '',
      estimateMinutes: json['estimate_minutes'] as int?,
      order: json['order'] as int? ?? 0,
    );
  }

  SubTaskDraft copyWith({
    String? title,
    String? suggestedDate,
    int? estimateMinutes,
    int? order,
    bool clearEstimate = false,
  }) {
    return SubTaskDraft(
      title: title ?? this.title,
      suggestedDate: suggestedDate ?? this.suggestedDate,
      estimateMinutes:
          clearEstimate ? null : (estimateMinutes ?? this.estimateMinutes),
      order: order ?? this.order,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'suggested_date': suggestedDate,
        'scheduled_date': suggestedDate,
        'estimate_minutes': estimateMinutes,
        'order': order,
        'source': 'ai',
        'accepted': true,
        'status': 'accepted',
      };
}

class SavedSubTask {
  SavedSubTask({
    required this.id,
    required this.parentTaskId,
    required this.title,
    required this.suggestedDate,
    this.scheduledDate,
    this.estimateMinutes,
    this.order = 0,
    this.source = 'ai',
    this.accepted = true,
    this.status = 'accepted',
  });

  final String id;
  final String parentTaskId;
  final String title;
  final String suggestedDate;
  final String? scheduledDate;
  final int? estimateMinutes;
  final int order;
  final String source;
  final bool accepted;
  final String status;

  bool get isDone => status == 'done';

  SavedSubTask copyWith({
    String? title,
    String? suggestedDate,
    String? scheduledDate,
    int? estimateMinutes,
    String? status,
    int? order,
  }) {
    return SavedSubTask(
      id: id,
      parentTaskId: parentTaskId,
      title: title ?? this.title,
      suggestedDate: suggestedDate ?? this.suggestedDate,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      estimateMinutes: estimateMinutes ?? this.estimateMinutes,
      order: order ?? this.order,
      source: source,
      accepted: accepted,
      status: status ?? this.status,
    );
  }

  factory SavedSubTask.fromJson(Map<String, dynamic> json) {
    return SavedSubTask(
      id: json['id'] as String? ?? '',
      parentTaskId: json['parent_task_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      suggestedDate: json['suggested_date'] as String? ?? '',
      scheduledDate: json['scheduled_date'] as String?,
      estimateMinutes: json['estimate_minutes'] as int?,
      order: json['order'] as int? ?? 0,
      source: json['source'] as String? ?? 'ai',
      accepted: json['accepted'] as bool? ?? true,
      status: json['status'] as String? ?? 'accepted',
    );
  }
}

class ParentTask {
  ParentTask({
    required this.id,
    required this.title,
    required this.deadline,
    required this.status,
    this.notes,
    this.subtasks = const [],
  });

  final String id;
  final String title;
  final String deadline;
  final String status;
  final String? notes;
  final List<SavedSubTask> subtasks;

  factory ParentTask.fromJson(Map<String, dynamic> json) {
    final raw = json['subtasks'] as List<dynamic>? ?? [];
    return ParentTask(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      deadline: json['deadline'] as String? ?? '',
      status: json['status'] as String? ?? 'open',
      notes: json['notes'] as String?,
      subtasks: raw
          .map((e) => SavedSubTask.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
