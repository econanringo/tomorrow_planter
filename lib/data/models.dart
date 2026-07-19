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
  });

  final String agentName;
  final String message;
  final bool isUser;
  final double? confidence;
}
