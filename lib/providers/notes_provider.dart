import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/note.dart';
import 'package:uuid/uuid.dart';

class NotesProvider extends ChangeNotifier {
  List<Note> _notes = [];
  String _searchQuery = '';
  bool _isGridView = true;
  final _uuid = const Uuid();

  List<Note> get notes => _filteredNotes;
  bool get isGridView => _isGridView;
  String get searchQuery => _searchQuery;

  List<Note> get _filteredNotes {
    var filtered = _notes;
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((n) =>
              n.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              n.content.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }
    // Pinned first
    filtered.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return filtered;
  }

  List<Note> get pinnedNotes => _notes.where((n) => n.isPinned).toList();
  List<Note> get unpinnedNotes => _notes.where((n) => !n.isPinned).toList();

  Future<void> loadNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notesJson = prefs.getStringList('notes') ?? [];
      _notes = notesJson
          .map((json) => Note.fromJson(jsonDecode(json)))
          .toList();
      notifyListeners();
    } catch (e) {
      _notes = [];
    }
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final notesJson = _notes.map((n) => jsonEncode(n.toJson())).toList();
    await prefs.setStringList('notes', notesJson);
  }

  Note createNote({Color? coverColor, String? coverEmoji}) {
    final note = Note(
      id: _uuid.v4(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      coverColor: coverColor ?? _randomCoverColor(),
      coverEmoji: coverEmoji,
    );
    _notes.insert(0, note);
    _saveNotes();
    notifyListeners();
    return note;
  }

  Color _randomCoverColor() {
    final colors = [
      const Color(0xFF6B4EFF),
      const Color(0xFFFF6B9D),
      const Color(0xFF4ECBFF),
      const Color(0xFFFF9F4E),
      const Color(0xFF4EFF9F),
      const Color(0xFFFF4E6B),
      const Color(0xFF9F4EFF),
      const Color(0xFF4EFFCB),
    ];
    return colors[_notes.length % colors.length];
  }

  void updateNote(Note note) {
    final index = _notes.indexWhere((n) => n.id == note.id);
    if (index != -1) {
      _notes[index] = note.copyWith(updatedAt: DateTime.now());
      _saveNotes();
      notifyListeners();
    }
  }

  void deleteNote(String id) {
    _notes.removeWhere((n) => n.id == id);
    _saveNotes();
    notifyListeners();
  }

  void togglePin(String id) {
    final index = _notes.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notes[index] = _notes[index].copyWith(
        isPinned: !_notes[index].isPinned,
        updatedAt: DateTime.now(),
      );
      _saveNotes();
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void toggleViewMode() {
    _isGridView = !_isGridView;
    notifyListeners();
  }

  Note? getNoteById(String id) {
    try {
      return _notes.firstWhere((n) => n.id == id);
    } catch (_) {
      return null;
    }
  }
}
