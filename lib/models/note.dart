import 'dart:ui';
import 'package:flutter/material.dart';

enum NoteType { regular, sticky }

class DrawnPoint {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  final bool isEraser;

  DrawnPoint({
    required this.points,
    required this.color,
    required this.strokeWidth,
    this.isEraser = false,
  });

  Map<String, dynamic> toJson() => {
        'points': points.map((p) => {'dx': p.dx, 'dy': p.dy}).toList(),
        'color': color.value,
        'strokeWidth': strokeWidth,
        'isEraser': isEraser,
      };

  factory DrawnPoint.fromJson(Map<String, dynamic> json) => DrawnPoint(
        points: (json['points'] as List)
            .map((p) => Offset(
                (p['dx'] as num).toDouble(), (p['dy'] as num).toDouble()))
            .toList(),
        color: Color(json['color']),
        strokeWidth: (json['strokeWidth'] as num).toDouble(),
        isEraser: json['isEraser'] ?? false,
      );
}

class NoteImage {
  final String id;
  final String path;
  double x;
  double y;
  double width;
  double height;

  NoteImage({
    required this.id,
    required this.path,
    this.x = 50,
    this.y = 50,
    this.width = 220,
    this.height = 165,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'path': path,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
      };

  factory NoteImage.fromJson(Map<String, dynamic> json) => NoteImage(
        id: json['id'],
        path: json['path'],
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        width: (json['width'] as num).toDouble(),
        height: (json['height'] as num).toDouble(),
      );
}

class StickyNote {
  final String id;
  String content;
  Color color;
  double x;
  double y;
  double width;
  double height;

  StickyNote({
    required this.id,
    this.content = '',
    required this.color,
    this.x = 100,
    this.y = 100,
    this.width = 180,
    this.height = 160,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'color': color.value,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
      };

  factory StickyNote.fromJson(Map<String, dynamic> json) => StickyNote(
        id: json['id'],
        content: json['content'],
        color: Color(json['color']),
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        width: (json['width'] as num).toDouble(),
        height: (json['height'] as num).toDouble(),
      );
}

/// A text label placed freely on the drawing canvas
class CanvasText {
  final String id;
  String text;
  double x;
  double y;
  int colorValue;
  double fontSize;

  CanvasText({
    required this.id,
    required this.text,
    required this.x,
    required this.y,
    required this.colorValue,
    this.fontSize = 16.0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'x': x,
        'y': y,
        'colorValue': colorValue,
        'fontSize': fontSize,
      };

  factory CanvasText.fromJson(Map<String, dynamic> json) => CanvasText(
        id: json['id'],
        text: json['text'],
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        colorValue: json['colorValue'] ?? json['color'] ?? 0xFF000000,
        fontSize: (json['fontSize'] as num?)?.toDouble() ?? 16.0,
      );

  CanvasText copyWith({double? x, double? y, String? text}) => CanvasText(
        id: id,
        text: text ?? this.text,
        x: x ?? this.x,
        y: y ?? this.y,
        colorValue: colorValue,
        fontSize: fontSize,
      );
}

/// A single page inside a note
class NotePage {
  final String id;
  String textContent;
  List<DrawnPoint> drawings;
  List<NoteImage> images;
  List<StickyNote> stickyNotes;
  List<CanvasText> canvasTexts; // ← persisted text labels

  NotePage({
    required this.id,
    this.textContent = '',
    List<DrawnPoint>? drawings,
    List<NoteImage>? images,
    List<StickyNote>? stickyNotes,
    List<CanvasText>? canvasTexts,
  })  : drawings = drawings ?? [],
        images = images ?? [],
        stickyNotes = stickyNotes ?? [],
        canvasTexts = canvasTexts ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'textContent': textContent,
        'drawings': drawings.map((d) => d.toJson()).toList(),
        'images': images.map((i) => i.toJson()).toList(),
        'stickyNotes': stickyNotes.map((s) => s.toJson()).toList(),
        'canvasTexts': canvasTexts.map((t) => t.toJson()).toList(),
      };

  factory NotePage.fromJson(Map<String, dynamic> json) => NotePage(
        id: json['id'],
        textContent: json['textContent'] ?? '',
        drawings: ((json['drawings'] ?? []) as List)
            .map((d) => DrawnPoint.fromJson(d))
            .toList(),
        images: ((json['images'] ?? []) as List)
            .map((i) => NoteImage.fromJson(i))
            .toList(),
        stickyNotes: ((json['stickyNotes'] ?? []) as List)
            .map((s) => StickyNote.fromJson(s))
            .toList(),
        canvasTexts: ((json['canvasTexts'] ?? []) as List)
            .map((t) => CanvasText.fromJson(t))
            .toList(),
      );

  NotePage copyWith({
    String? textContent,
    List<DrawnPoint>? drawings,
    List<NoteImage>? images,
    List<StickyNote>? stickyNotes,
    List<CanvasText>? canvasTexts,
  }) =>
      NotePage(
        id: id,
        textContent: textContent ?? this.textContent,
        drawings: drawings ?? this.drawings,
        images: images ?? this.images,
        stickyNotes: stickyNotes ?? this.stickyNotes,
        canvasTexts: canvasTexts ?? this.canvasTexts,
      );
}

class Note {
  final String id;
  String title;
  List<NotePage> pages;
  Color coverColor;
  String? coverImagePath;
  String? coverEmoji;
  String coverTitle;
  DateTime createdAt;
  DateTime updatedAt;
  Color noteColor;
  bool isPinned;
  List<String> tags;
  NoteType type;
  // Legacy
  String content;
  List<DrawnPoint> drawings;
  List<NoteImage> images;
  List<StickyNote> stickyNotes;

  Note({
    required this.id,
    this.title = 'Untitled',
    List<NotePage>? pages,
    this.coverColor = const Color(0xFF6B4EFF),
    this.coverImagePath,
    this.coverEmoji,
    this.coverTitle = '',
    required this.createdAt,
    required this.updatedAt,
    this.noteColor = Colors.white,
    this.isPinned = false,
    List<String>? tags,
    this.type = NoteType.regular,
    this.content = '',
    List<DrawnPoint>? drawings,
    List<NoteImage>? images,
    List<StickyNote>? stickyNotes,
  })  : pages = pages ?? [],
        tags = tags ?? [],
        drawings = drawings ?? [],
        images = images ?? [],
        stickyNotes = stickyNotes ?? [];

  String get previewText =>
      pages.isNotEmpty ? pages.first.textContent : content;
  List<DrawnPoint> get allDrawings =>
      pages.isNotEmpty ? pages.first.drawings : drawings;
  List<NoteImage> get allImages =>
      pages.isNotEmpty ? pages.expand((p) => p.images).toList() : images;
  List<StickyNote> get allStickyNotes =>
      pages.isNotEmpty ? pages.expand((p) => p.stickyNotes).toList() : stickyNotes;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'pages': pages.map((p) => p.toJson()).toList(),
        'coverColor': coverColor.value,
        'coverImagePath': coverImagePath,
        'coverEmoji': coverEmoji,
        'coverTitle': coverTitle,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'noteColor': noteColor.value,
        'isPinned': isPinned,
        'tags': tags,
        'type': type.index,
        'content': content,
        'drawings': drawings.map((d) => d.toJson()).toList(),
        'images': images.map((i) => i.toJson()).toList(),
        'stickyNotes': stickyNotes.map((s) => s.toJson()).toList(),
      };

  factory Note.fromJson(Map<String, dynamic> json) {
    List<NotePage> pages = [];
    if (json['pages'] != null && (json['pages'] as List).isNotEmpty) {
      pages =
          (json['pages'] as List).map((p) => NotePage.fromJson(p)).toList();
    } else if ((json['content'] ?? '').toString().isNotEmpty ||
        ((json['drawings'] as List?) ?? []).isNotEmpty) {
      pages = [
        NotePage(
          id: 'page_0',
          textContent: json['content'] ?? '',
          drawings: ((json['drawings'] ?? []) as List)
              .map((d) => DrawnPoint.fromJson(d))
              .toList(),
          images: ((json['images'] ?? []) as List)
              .map((i) => NoteImage.fromJson(i))
              .toList(),
          stickyNotes: ((json['stickyNotes'] ?? []) as List)
              .map((s) => StickyNote.fromJson(s))
              .toList(),
        )
      ];
    }
    return Note(
      id: json['id'],
      title: json['title'] ?? 'Untitled',
      pages: pages,
      coverColor: Color(json['coverColor'] ?? 0xFF6B4EFF),
      coverImagePath: json['coverImagePath'],
      coverEmoji: json['coverEmoji'],
      coverTitle: json['coverTitle'] ?? '',
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      noteColor: Color(json['noteColor'] ?? 0xFFFFFFFF),
      isPinned: json['isPinned'] ?? false,
      tags: List<String>.from(json['tags'] ?? []),
      type: NoteType.values[json['type'] ?? 0],
      content: json['content'] ?? '',
    );
  }

  Note copyWith({
    String? title,
    List<NotePage>? pages,
    Color? coverColor,
    String? coverImagePath,
    String? coverEmoji,
    String? coverTitle,
    DateTime? updatedAt,
    Color? noteColor,
    bool? isPinned,
    List<String>? tags,
    bool clearCoverEmoji = false,
  }) =>
      Note(
        id: id,
        title: title ?? this.title,
        pages: pages ?? this.pages,
        coverColor: coverColor ?? this.coverColor,
        coverImagePath: coverImagePath ?? this.coverImagePath,
        coverEmoji: clearCoverEmoji ? null : (coverEmoji ?? this.coverEmoji),
        coverTitle: coverTitle ?? this.coverTitle,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        noteColor: noteColor ?? this.noteColor,
        isPinned: isPinned ?? this.isPinned,
        tags: tags ?? this.tags,
        type: type,
        content: content,
      );
}
