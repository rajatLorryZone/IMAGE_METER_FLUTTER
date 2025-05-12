import 'package:hive/hive.dart';

part 'site_model.g.dart';

@HiveType(typeId: 3)
class Site {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String name;
  
  @HiveField(2)
  final DateTime createdAt;
  
  @HiveField(3)
  final DateTime lastModified;
  
  @HiveField(4)
  final List<String> projectIds; // List of project IDs associated with this site
  
  @HiveField(5)
  final String? thumbnailPath;

  Site({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.lastModified,
    required this.projectIds,
    this.thumbnailPath,
  });

  // Create a copy with updated values
  Site copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? lastModified,
    List<String>? projectIds,
    String? thumbnailPath,
  }) {
    return Site(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      lastModified: lastModified ?? DateTime.now(),
      projectIds: projectIds ?? this.projectIds,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
    );
  }
}
