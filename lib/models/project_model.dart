import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'arrow_model.dart';

part 'project_model.g.dart';

@HiveType(typeId: 2)
class Project {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String name;
  
  @HiveField(2)
  final DateTime createdAt;
  
  @HiveField(3)
  final DateTime lastModified;
  
  @HiveField(4)
  final String? imagePath;
  
  @HiveField(5)
  final List<ArrowModel> arrows;
  
  @HiveField(6)
  final Color backgroundColor;
  
  @HiveField(7)
  final String thumbnailPath;

  Project({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.lastModified,
    this.imagePath,
    required this.arrows,
    required this.backgroundColor,
    required this.thumbnailPath,
  });

  // Create a copy with updated values
  Project copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? lastModified,
    String? imagePath,
    List<ArrowModel>? arrows,
    Color? backgroundColor,
    String? thumbnailPath,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      lastModified: lastModified ?? DateTime.now(),
      imagePath: imagePath ?? this.imagePath,
      arrows: arrows ?? this.arrows,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
    );
  }
}
