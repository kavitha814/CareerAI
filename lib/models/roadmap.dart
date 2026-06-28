class CareerRoadmap {
  final String id;
  final String title;
  final String description;
  final String estimatedDuration;
  final int currentWeek;
  final List<RoadmapMilestone> milestones;
  final DateTime createdAt;

  CareerRoadmap({
    required this.id,
    required this.title,
    required this.description,
    required this.estimatedDuration,
    this.currentWeek = 1,
    required this.milestones,
    required this.createdAt,
  });

  double get progress {
    if (milestones.isEmpty) return 0.0;
    int totalTasks = 0;
    int completedTasks = 0;
    for (var m in milestones) {
      for (var t in m.tasks) {
        totalTasks++;
        if (t.isCompleted) completedTasks++;
      }
    }
    return totalTasks == 0 ? 0.0 : completedTasks / totalTasks;
  }

  CareerRoadmap copyWith({
    String? id,
    String? title,
    String? description,
    String? estimatedDuration,
    int? currentWeek,
    List<RoadmapMilestone>? milestones,
    DateTime? createdAt,
  }) {
    return CareerRoadmap(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      currentWeek: currentWeek ?? this.currentWeek,
      milestones: milestones ?? this.milestones,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'estimatedDuration': estimatedDuration,
      'currentWeek': currentWeek,
      'milestones': milestones.map((e) => e.toMap()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CareerRoadmap.fromMap(Map<String, dynamic> map) {
    return CareerRoadmap(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      estimatedDuration: map['estimatedDuration'] ?? '',
      currentWeek: map['currentWeek'] ?? 1,
      milestones: List<RoadmapMilestone>.from(
        (map['milestones'] ?? []).map((x) => RoadmapMilestone.fromMap(x)),
      ),
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class RoadmapMilestone {
  final String id;
  final int weekNumber;
  final String title;
  final String description;
  final List<RoadmapTask> tasks;

  RoadmapMilestone({
    required this.id,
    required this.weekNumber,
    required this.title,
    required this.description,
    required this.tasks,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'weekNumber': weekNumber,
      'title': title,
      'description': description,
      'tasks': tasks.map((e) => e.toMap()).toList(),
    };
  }

  factory RoadmapMilestone.fromMap(Map<String, dynamic> map) {
    return RoadmapMilestone(
      id: map['id'] ?? '',
      weekNumber: map['weekNumber'] ?? 1,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      tasks: List<RoadmapTask>.from(
        (map['tasks'] ?? []).map((x) => RoadmapTask.fromMap(x)),
      ),
    );
  }
}

class RoadmapTask {
  final String id;
  final String title;
  final String description;
  final bool isCompleted;
  final String type; // e.g., 'concept', 'practice', 'project', 'quiz'
  final List<String> resources;

  RoadmapTask({
    required this.id,
    required this.title,
    required this.description,
    this.isCompleted = false,
    required this.type,
    required this.resources,
  });

  RoadmapTask copyWith({
    String? id,
    String? title,
    String? description,
    bool? isCompleted,
    String? type,
    List<String>? resources,
  }) {
    return RoadmapTask(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      type: type ?? this.type,
      resources: resources ?? this.resources,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'isCompleted': isCompleted,
      'type': type,
      'resources': resources,
    };
  }

  factory RoadmapTask.fromMap(Map<String, dynamic> map) {
    return RoadmapTask(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      isCompleted: map['isCompleted'] ?? false,
      type: map['type'] ?? 'concept',
      resources: List<String>.from(map['resources'] ?? []),
    );
  }
}
