import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Project Model ────────────────────────────────────────────────────────────

class Project {
  final String id;
  final String name;
  final String type; // 'video' | 'audio'
  final DateTime createdAt;
  final DateTime updatedAt;
  final Duration? duration;
  final String? thumbnailPath;

  Project({
    required this.id,
    required this.name,
    required this.type,
    required this.createdAt,
    DateTime? updatedAt,
    this.duration,
    this.thumbnailPath,
  }) : updatedAt = updatedAt ?? createdAt;

  Project copyWith({
    String? name,
    DateTime? updatedAt,
    Duration? duration,
    String? thumbnailPath,
  }) =>
      Project(
        id: id,
        name: name ?? this.name,
        type: type,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        duration: duration ?? this.duration,
        thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'durationMs': duration?.inMilliseconds,
        'thumbnailPath': thumbnailPath,
      };

  factory Project.fromJson(Map<String, dynamic> json) => Project(
        id: json['id'],
        name: json['name'],
        type: json['type'],
        createdAt: DateTime.parse(json['createdAt']),
        updatedAt: DateTime.parse(json['updatedAt']),
        duration: json['durationMs'] != null
            ? Duration(milliseconds: json['durationMs'])
            : null,
        thumbnailPath: json['thumbnailPath'],
      );
}

// ─── Projects State ───────────────────────────────────────────────────────────

class ProjectsState {
  final List<Project> projects;
  final bool isLoaded;

  const ProjectsState({
    this.projects = const [],
    this.isLoaded = false,
  });

  ProjectsState copyWith({
    List<Project>? projects,
    bool? isLoaded,
  }) =>
      ProjectsState(
        projects: projects ?? this.projects,
        isLoaded: isLoaded ?? this.isLoaded,
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class ProjectsNotifier extends Notifier<ProjectsState> {
  static const _storageKey = 'pro_editor_projects';

  @override
  ProjectsState build() {
    _loadFromDisk();
    return const ProjectsState();
  }

  Future<void> _loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        final List<dynamic> list = jsonDecode(raw);
        final projects = list.map((j) => Project.fromJson(j)).toList();
        // Sort newest first
        projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        state = state.copyWith(projects: projects, isLoaded: true);
      } else {
        state = state.copyWith(isLoaded: true);
      }
    } catch (e) {
      debugPrint('Error loading projects: $e');
      state = state.copyWith(isLoaded: true);
    }
  }

  Future<void> _saveToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode(state.projects.map((p) => p.toJson()).toList());
      await prefs.setString(_storageKey, data);
    } catch (e) {
      debugPrint('Error saving projects: $e');
    }
  }

  Project createProject(String name, String type) {
    final project = Project(
      id: '${type}_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      type: type,
      createdAt: DateTime.now(),
    );
    state = state.copyWith(
      projects: [project, ...state.projects],
    );
    _saveToDisk();
    return project;
  }

  void renameProject(String id, String newName) {
    final list = state.projects.map((p) {
      if (p.id == id) return p.copyWith(name: newName, updatedAt: DateTime.now());
      return p;
    }).toList();
    state = state.copyWith(projects: list);
    _saveToDisk();
  }

  void deleteProject(String id) {
    final list = state.projects.where((p) => p.id != id).toList();
    state = state.copyWith(projects: list);
    _saveToDisk();
  }

  void updateProjectTimestamp(String id) {
    final list = state.projects.map((p) {
      if (p.id == id) return p.copyWith(updatedAt: DateTime.now());
      return p;
    }).toList();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    state = state.copyWith(projects: list);
    _saveToDisk();
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final projectsProvider = NotifierProvider<ProjectsNotifier, ProjectsState>(
  ProjectsNotifier.new,
);
