class Task {
  final String id, title, description, createdAt, updatedAt;
  final String? userId;
  final bool completed, deleted, pending;
  final int revision;
  const Task({
    required this.id,
    required this.title,
    this.description = '',
    required this.createdAt,
    required this.updatedAt,
    this.userId,
    this.completed = false,
    this.deleted = false,
    this.pending = true,
    this.revision = 1,
  });

  factory Task.fromMap(Map<String, dynamic> m) => Task(
    id: m['id'] as String,
    title: m['title'] as String,
    description: m['description'] as String? ?? '',
    createdAt: m['created_at'] as String,
    updatedAt: m['updated_at'] as String,
    userId: m['user_id'] as String?,
    completed: m['completed'] == true || m['completed'] == 1,
    deleted: m['deleted'] == true || m['deleted'] == 1,
    pending: m['pending'] == 1,
    revision: m['revision'] as int? ?? 1,
  );

  Map<String, dynamic> toLocal() => {
    'id': id,
    'title': title,
    'description': description,
    'created_at': createdAt,
    'updated_at': updatedAt,
    'user_id': userId,
    'completed': completed ? 1 : 0,
    'deleted': deleted ? 1 : 0,
    'pending': pending ? 1 : 0,
    'revision': revision,
  };
  Map<String, dynamic> toRemote(String owner) => {
    'id': id,
    'title': title,
    'description': description,
    'created_at': createdAt,
    'updated_at': updatedAt,
    'user_id': owner,
    'completed': completed,
    'deleted': deleted,
  };
}
