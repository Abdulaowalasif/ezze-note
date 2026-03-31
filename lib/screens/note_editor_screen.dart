import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../utils/theme.dart';
import '../widgets/drawing_canvas.dart';
import '../widgets/sticky_note_widget.dart';
import '../widgets/cover_picker_sheet.dart';
import '../utils/pdf_export.dart';

enum EditorMode { text, draw, images, stickies }

class NoteEditorScreen extends StatefulWidget {
  final String noteId;
  const NoteEditorScreen({super.key, required this.noteId});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late Note _note;
  late TextEditingController _titleController;
  final _uuid = const Uuid();
  final _imagePicker = ImagePicker();
  final _pageController = PageController();
  int _pointerCount = 0;
  bool _isMultiTouching = false;

  int _currentPageIndex = 0; // 0 = cover

  EditorMode _mode = EditorMode.text;
  DrawingTool _drawingTool = DrawingTool.pen;
  Color _penColor = Colors.black87;
  double _strokeWidth = 3.0;

  // Per-page text controllers (keyed by page.id)
  final Map<String, TextEditingController> _pageControllers = {};

  // ── Zoom state per page ───────────────────────────────────────────────────
  // Each page gets its own TransformationController for pinch-zoom
  final Map<String, TransformationController> _zoomControllers = {};

  @override
  void initState() {
    super.initState();
    _note = context.read<NotesProvider>().getNoteById(widget.noteId)!;
    _titleController = TextEditingController(text: _note.title);
    if (_note.pages.isEmpty) {
      _note = _note.copyWith(pages: [NotePage(id: _uuid.v4())]);
    }
    for (final p in _note.pages) {
      _pageControllers[p.id] = TextEditingController(text: p.textContent);
      _zoomControllers[p.id] = TransformationController();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (final c in _pageControllers.values) c.dispose();
    for (final c in _zoomControllers.values) c.dispose();
    _pageController.dispose();
    _saveNote();
    super.dispose();
  }

  // ── Page helpers ─────────────────────────────────────────────────────────

  int get _contentPageIndex => (_currentPageIndex - 1).clamp(0, _note.pages.length - 1);

  NotePage get _currentContentPage => _note.pages[_contentPageIndex];

  void _updatePage(int pageIndex, NotePage updated) {
    final pages = List<NotePage>.from(_note.pages);
    pages[pageIndex] = updated;
    setState(() => _note = _note.copyWith(pages: pages));
  }

  void _saveNote() {
    // Flush text controller content into the page model before saving
    final pages = _note.pages.map((p) {
      final ctrl = _pageControllers[p.id];
      return ctrl != null ? p.copyWith(textContent: ctrl.text) : p;
    }).toList();
    context.read<NotesProvider>().updateNote(
          _note.copyWith(
            title: _titleController.text.isEmpty ? 'Untitled' : _titleController.text,
            pages: pages,
            updatedAt: DateTime.now(),
          ),
        );
  }

  void _addPage() {
    final newPage = NotePage(id: _uuid.v4());
    final pages = List<NotePage>.from(_note.pages)..add(newPage);
    _pageControllers[newPage.id] = TextEditingController();
    _zoomControllers[newPage.id] = TransformationController();
    setState(() => _note = _note.copyWith(pages: pages));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pageController.animateToPage(pages.length,
          duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    });
  }

  void _deletePage(int pageIndex) {
    if (_note.pages.length <= 1) return;
    final pages = List<NotePage>.from(_note.pages)..removeAt(pageIndex);
    setState(() {
      _note = _note.copyWith(pages: pages);
      if (_currentPageIndex > pages.length) _currentPageIndex = pages.length;
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _saveNote();
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              _buildPageTabBar(),
              Expanded(child: _buildPageView()),
              if (_mode == EditorMode.draw) _buildDrawingToolbar(),
              _buildBottomModeBar(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
            onPressed: () { _saveNote(); Navigator.pop(context); },
          ),
          Expanded(
            child: TextField(
              controller: _titleController,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.onSurface),
              decoration: const InputDecoration(
                border: InputBorder.none, filled: false,
                hintText: 'Title...', contentPadding: EdgeInsets.zero,
                hintStyle: TextStyle(
                    color: AppTheme.onSurfaceVariant, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 22, color: AppTheme.primary),
            tooltip: 'Export PDF',
            onPressed: _exportPDF,
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, size: 22),
            onPressed: _showMoreOptions,
          ),
        ],
      ),
    );
  }

  // ── Page tab bar ──────────────────────────────────────────────────────────

  Widget _buildPageTabBar() {
    return Container(
      height: 36,
      color: AppTheme.surfaceVariant,
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(children: [
                _PageTab(
                  label: 'Cover',
                  icon: Icons.auto_awesome_rounded,
                  isSelected: _currentPageIndex == 0,
                  onTap: () {
                    setState(() => _currentPageIndex = 0);
                    _pageController.animateToPage(0,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut);
                  },
                ),
                ...List.generate(_note.pages.length, (i) => _PageTab(
                  label: 'Page ${i + 1}',
                  isSelected: _currentPageIndex == i + 1,
                  onTap: () {
                    setState(() => _currentPageIndex = i + 1);
                    _pageController.animateToPage(i + 1,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut);
                  },
                  onLongPress: _note.pages.length > 1
                      ? () => _confirmDeletePage(i)
                      : null,
                )),
              ]),
            ),
          ),
          GestureDetector(
            onTap: _addPage,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: const Icon(Icons.add_rounded, size: 20, color: AppTheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  // ── Page view ─────────────────────────────────────────────────────────────

  Widget _buildPageView() {
    return PageView.builder(
      controller: _pageController,
      // Disable swipe when drawing (use finger for drawing, not swiping)
      physics: _mode == EditorMode.draw
          ? const NeverScrollableScrollPhysics()
          : const ClampingScrollPhysics(),
      itemCount: _note.pages.length + 1,
      onPageChanged: (i) => setState(() => _currentPageIndex = i),
      itemBuilder: (_, i) {
        if (i == 0) return _buildCoverPage();
        return _buildContentPage(i - 1);
      },
    );
  }

  // ── Cover page ────────────────────────────────────────────────────────────

  Widget _buildCoverPage() {
    return Container(
      color: _note.coverColor,
      child: Stack(children: [
        Positioned.fill(
          child: CustomPaint(
              painter: _CoverPatternPainter(color: Colors.white.withOpacity(0.06))),
        ),
        Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (_note.coverEmoji != null)
              Text(_note.coverEmoji!, style: const TextStyle(fontSize: 72))
            else
              Icon(Icons.auto_stories_rounded,
                  size: 72, color: Colors.white.withOpacity(0.5)),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _note.title.isEmpty ? 'Untitled' : _note.title,
                style: const TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w900,
                    color: Colors.white, letterSpacing: -0.5),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 48),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(
                '${_note.pages.length} page${_note.pages.length != 1 ? "s" : ""}',
                style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13),
              ),
            ),
          ]),
        ),
        Positioned(
          bottom: 24, right: 24,
          child: ElevatedButton.icon(
            onPressed: _showCoverPicker,
            icon: const Icon(Icons.palette_rounded, size: 16),
            label: const Text('Edit Cover'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: _note.coverColor,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Content page ──────────────────────────────────────────────────────────

  Widget _buildContentPage(int pageIndex) {
    final page = _note.pages[pageIndex];

    // Ensure controllers exist for this page
    _pageControllers.putIfAbsent(
        page.id, () => TextEditingController(text: page.textContent));
    _zoomControllers.putIfAbsent(page.id, () => TransformationController());

    final zoomCtrl = _zoomControllers[page.id]!;

    // Wrap the whole page in InteractiveViewer for pinch-zoom
    // But only allow zoom in draw mode so text mode can still scroll normally
    return _mode == EditorMode.draw
        ? InteractiveViewer(
            transformationController: zoomCtrl,
            minScale: 0.5,
            maxScale: 4.0,
            // Pan is only allowed via two fingers; single finger = drawing
            panEnabled: false,
            scaleEnabled: true,
            child: _buildPageContent(page, pageIndex),
          )
        : _buildPageContent(page, pageIndex);
  }

  Widget _buildPageContent(NotePage page, int pageIndex) {
    return Container(
      color: Colors.white,
      child: Stack(children: [
        // ── 1. Ruled paper background ───────────────────────────────────────
        Positioned.fill(child: CustomPaint(painter: _RuledPainter())),

        // ── 2. Text layer ───────────────────────────────────────────────────
        Positioned.fill(
          child: SingleChildScrollView(
            physics: _mode == EditorMode.draw
                ? const NeverScrollableScrollPhysics()
                : const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height - 200),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
                child: TextField(
                  controller: _pageControllers[page.id],
                  maxLines: null,
                  enabled: _mode == EditorMode.text,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    filled: false,
                    hintText: 'Start writing...',
                    contentPadding: EdgeInsets.zero,
                    hintStyle: TextStyle(
                        color: AppTheme.onSurfaceVariant, fontSize: 16, height: 1.8),
                  ),
                  style: const TextStyle(
                      fontSize: 16, color: AppTheme.onSurface, height: 1.8),
                ),
              ),
            ),
          ),
        ),

        // ── 3. Drawing canvas (With Multi-Finger Detection) ──────────────────
        Positioned.fill(
          child: Listener(
            onPointerDown: (details) {
              _pointerCount++;
              if (_pointerCount > 1) {
                setState(() => _isMultiTouching = true);
              }
            },
            onPointerUp: (details) {
              _pointerCount--;
              if (_pointerCount <= 1) {
                setState(() => _isMultiTouching = false);
              }
            },
            onPointerCancel: (details) {
              _pointerCount = 0;
              setState(() => _isMultiTouching = false);
            },
            child: DrawingCanvas(
              drawings: page.drawings,
              // Logic: Active only if in Draw Mode, NOT text tool, AND only one finger
              isActive: _mode == EditorMode.draw &&
                  _drawingTool != DrawingTool.text &&
                  !_isMultiTouching,
              tool: _drawingTool,
              penColor: _penColor,
              strokeWidth: _strokeWidth,
              onDrawingsChanged: (drawings) =>
                  _updatePage(pageIndex, page.copyWith(drawings: drawings)),
            ),
          ),
        ),

        // ── 4. Canvas text labels ───────────────────────────────────────────
        ..._buildCanvasTexts(page, pageIndex),

        // ── 5. Images ───────────────────────────────────────────────────────
        ..._buildImages(page, pageIndex),

        // ── 6. Sticky notes ────────────────────────────────────────────────
        ..._buildStickyNotes(page, pageIndex),

        // ── 7. Text-tool tap target ─────────────────────────────────────────
        if (_mode == EditorMode.draw && _drawingTool == DrawingTool.text)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapDown: (d) => _promptCanvasText(page, pageIndex, d.localPosition),
            ),
          ),

        // ── 8. Mode FABs ────────────────────────────────────────────────────
        if (_mode == EditorMode.images)
          Positioned(
            right: 16, bottom: 16,
            child: FloatingActionButton(
              heroTag: 'img_fab',
              onPressed: () => _pickImage(page, pageIndex),
              child: const Icon(Icons.add_photo_alternate_rounded),
            ),
          ),
        if (_mode == EditorMode.stickies)
          Positioned(
            right: 16, bottom: 16,
            child: FloatingActionButton(
              heroTag: 'sticky_fab',
              onPressed: () => _addStickyNote(page, pageIndex),
              child: const Icon(Icons.sticky_note_2_rounded),
            ),
          ),

        // ── 9. Zoom hint badge ──────────────────────────────────────────────
        if (_mode == EditorMode.draw)
          Positioned(
            top: 8, right: 8,
            child: AnimatedOpacity(
              opacity: _isMultiTouching ? 1.0 : 0.5,
              duration: const Duration(milliseconds: 200),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _isMultiTouching ? AppTheme.primary : Colors.black.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.pinch_rounded, size: 13, color: Colors.white),
                    SizedBox(width: 4),
                    Text('Zooming...',
                        style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
      ]),
    );
  }

  // ── Canvas text labels ────────────────────────────────────────────────────

  void _promptCanvasText(NotePage page, int pageIndex, Offset position) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add Text', style: TextStyle(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Type something...'),
          onSubmitted: (_) => _commitCanvasText(ctrl.text, page, pageIndex, position),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _commitCanvasText(ctrl.text, page, pageIndex, position),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _commitCanvasText(
      String text, NotePage page, int pageIndex, Offset position) {
    Navigator.of(context, rootNavigator: true).pop();
    if (text.trim().isEmpty) return;
    final newLabel = CanvasText(
      id: _uuid.v4(),
      text: text.trim(),
      x: position.dx,
      y: position.dy,
      colorValue: _penColor.value,
      fontSize: 16.0,
    );
    _updatePage(pageIndex,
        page.copyWith(canvasTexts: [...page.canvasTexts, newLabel]));
  }

  List<Widget> _buildCanvasTexts(NotePage page, int pageIndex) {
    return page.canvasTexts.map((label) {
      return Positioned(
        left: label.x,
        top: label.y,
        child: GestureDetector(
          // Drag to reposition — only in draw mode with text tool
          onPanUpdate: (_mode == EditorMode.draw && _drawingTool == DrawingTool.text)
              ? (d) {
                  final updated = label.copyWith(
                      x: label.x + d.delta.dx, y: label.y + d.delta.dy);
                  final texts = page.canvasTexts
                      .map((t) => t.id == label.id ? updated : t)
                      .toList();
                  _updatePage(pageIndex, page.copyWith(canvasTexts: texts));
                }
              : null,
          // Long press to delete — only in draw mode
          onLongPress: _mode == EditorMode.draw
              ? () {
                  final texts =
                      page.canvasTexts.where((t) => t.id != label.id).toList();
                  _updatePage(pageIndex, page.copyWith(canvasTexts: texts));
                }
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              border: _mode == EditorMode.draw && _drawingTool == DrawingTool.text
                  ? Border.all(
                      color: AppTheme.primary.withOpacity(0.4),
                      width: 1,
                    )
                  : null,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              label.text,
              style: TextStyle(
                color: Color(label.colorValue),
                fontSize: label.fontSize,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  // ── Images ────────────────────────────────────────────────────────────────

  List<Widget> _buildImages(NotePage page, int pageIndex) {
    return page.images.map((img) {
      // Use a StatefulWidget wrapper so position is tracked locally
      // (smooth drag without rebuilding the entire page)
      return _DraggableImage(
        key: ValueKey('img_${img.id}'),
        image: img,
        isDraggable: _mode == EditorMode.images,
        onPositionChanged: (newImg) {
          final images =
              page.images.map((i) => i.id == newImg.id ? newImg : i).toList();
          _updatePage(pageIndex, page.copyWith(images: images));
        },
        onDelete: () {
          final images = page.images.where((i) => i.id != img.id).toList();
          _updatePage(pageIndex, page.copyWith(images: images));
        },
      );
    }).toList();
  }

  // ── Sticky notes ──────────────────────────────────────────────────────────

  List<Widget> _buildStickyNotes(NotePage page, int pageIndex) {
    return page.stickyNotes.map((sticky) {
      return StickyNoteWidget(
        key: ValueKey('sticky_${sticky.id}'),
        stickyNote: sticky,
        isEditable: _mode == EditorMode.stickies,
        onUpdate: (updated) {
          final stickies = page.stickyNotes
              .map((s) => s.id == updated.id ? updated : s)
              .toList();
          _updatePage(pageIndex, page.copyWith(stickyNotes: stickies));
        },
        onDelete: () {
          final stickies =
              page.stickyNotes.where((s) => s.id != sticky.id).toList();
          _updatePage(pageIndex, page.copyWith(stickyNotes: stickies));
        },
      );
    }).toList();
  }

  // ── Drawing toolbar ───────────────────────────────────────────────────────

  Widget _buildDrawingToolbar() {
    return DrawingToolbar(
      currentTool: _drawingTool,
      penColor: _penColor,
      strokeWidth: _strokeWidth,
      onToolChanged: (t) => setState(() => _drawingTool = t),
      onColorChanged: (c) => setState(() => _penColor = c),
      onStrokeWidthChanged: (w) => setState(() => _strokeWidth = w),
      onUndo: () {
        final page = _currentContentPage;
        final idx = _contentPageIndex;
        if (page.drawings.isNotEmpty) {
          final drawings = List<DrawnPoint>.from(page.drawings)..removeLast();
          _updatePage(idx, page.copyWith(drawings: drawings));
        }
      },
      onClear: () => showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Clear all drawings?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                _updatePage(_contentPageIndex,
                    _currentContentPage.copyWith(drawings: []));
                Navigator.pop(context);
              },
              child: const Text('Clear', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bottom mode bar ───────────────────────────────────────────────────────

  Widget _buildBottomModeBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ModeBtn(
              icon: Icons.text_fields_rounded,
              label: 'Text',
              isSelected: _mode == EditorMode.text,
              onTap: () => setState(() => _mode = EditorMode.text)),
          _ModeBtn(
              icon: Icons.draw_rounded,
              label: 'Draw',
              isSelected: _mode == EditorMode.draw,
              onTap: () => setState(() => _mode = EditorMode.draw)),
          _ModeBtn(
              icon: Icons.image_rounded,
              label: 'Images',
              isSelected: _mode == EditorMode.images,
              onTap: () => setState(() => _mode = EditorMode.images)),
          _ModeBtn(
              icon: Icons.sticky_note_2_rounded,
              label: 'Sticky',
              isSelected: _mode == EditorMode.stickies,
              onTap: () => setState(() => _mode = EditorMode.stickies)),
        ],
      ),
    );
  }

  // ── Helper methods ────────────────────────────────────────────────────────

  Future<void> _pickImage(NotePage page, int pageIndex) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.camera_alt_rounded),
            title: const Text('Camera'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded),
            title: const Text('Gallery'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ]),
      ),
    );
    if (source == null) return;
    try {
      final picked =
          await _imagePicker.pickImage(source: source, imageQuality: 85);
      if (picked == null) return;
      final newImg =
          NoteImage(id: _uuid.v4(), path: picked.path, x: 24, y: 80);
      _updatePage(pageIndex, page.copyWith(images: [...page.images, newImg]));
    } catch (_) {}
  }

  void _addStickyNote(NotePage page, int pageIndex) {
    final colors = AppTheme.stickyColors;
    final sticky = StickyNote(
      id: _uuid.v4(),
      color: colors[page.stickyNotes.length % colors.length],
      x: 20 + (page.stickyNotes.length * 18).toDouble(),
      y: 60 + (page.stickyNotes.length * 18).toDouble(),
    );
    _updatePage(
        pageIndex, page.copyWith(stickyNotes: [...page.stickyNotes, sticky]));
  }

  void _showCoverPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CoverPickerSheet(
        note: _note,
        onCoverChanged: (color, emoji) {
          setState(() =>
              _note = _note.copyWith(coverColor: color, coverEmoji: emoji));
          _saveNote();
        },
      ),
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: Icon(
                _note.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: AppTheme.primary),
            title: Text(_note.isPinned ? 'Unpin note' : 'Pin note'),
            onTap: () {
              setState(() =>
                  _note = _note.copyWith(isPinned: !_note.isPinned));
              context.read<NotesProvider>().togglePin(_note.id);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.palette_outlined, color: AppTheme.primary),
            title: const Text('Edit cover'),
            onTap: () { Navigator.pop(context); _showCoverPicker(); },
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_rounded, color: AppTheme.primary),
            title: const Text('Export as PDF'),
            onTap: () { Navigator.pop(context); _exportPDF(); },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
            title: const Text('Delete note', style: TextStyle(color: Colors.red)),
            onTap: () { Navigator.pop(context); _confirmDeleteNote(); },
          ),
        ]),
      ),
    );
  }

  Future<void> _exportPDF() async {
    _saveNote();
    try {
      // Build canvasTexts map from page model for PDF export
      final canvasTextsMap = <String, List<Map<String, dynamic>>>{};
      for (final p in _note.pages) {
        canvasTextsMap[p.id] = p.canvasTexts.map((t) => {
          'text': t.text, 'dx': t.x, 'dy': t.y,
          'color': t.colorValue, 'size': t.fontSize,
        }).toList();
      }
      await PdfExportService.exportNote(_note, canvasTextsMap, context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  void _confirmDeletePage(int pageIndex) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete page?'),
        content: const Text('This page will be permanently deleted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () { _deletePage(pageIndex); Navigator.pop(context); },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteNote() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete note?'),
        content: const Text('This note will be permanently deleted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              context.read<NotesProvider>().deleteNote(_note.id);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ─── Draggable image widget (local state = smooth drag) ──────────────────────

class _DraggableImage extends StatefulWidget {
  final NoteImage image;
  final bool isDraggable;
  final Function(NoteImage) onPositionChanged;
  final VoidCallback onDelete;

  const _DraggableImage({
    super.key,
    required this.image,
    required this.isDraggable,
    required this.onPositionChanged,
    required this.onDelete,
  });

  @override
  State<_DraggableImage> createState() => _DraggableImageState();
}

class _DraggableImageState extends State<_DraggableImage> {
  late double _x;
  late double _y;
  late double _width;
  late double _height;
  bool _selected = false;

  @override
  void initState() {
    super.initState();
    _x = widget.image.x;
    _y = widget.image.y;
    _width = widget.image.width;
    _height = widget.image.height;
  }

  @override
  void didUpdateWidget(_DraggableImage old) {
    super.didUpdateWidget(old);
    // Only sync from parent if NOT currently being dragged
    if (!_selected) {
      _x = widget.image.x;
      _y = widget.image.y;
      _width = widget.image.width;
      _height = widget.image.height;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _x,
      top: _y,
      child: GestureDetector(
        onTap: widget.isDraggable
            ? () => setState(() => _selected = !_selected)
            : null,
        onPanUpdate: (widget.isDraggable && _selected)
            ? (d) {
                setState(() {
                  _x += d.delta.dx;
                  _y += d.delta.dy;
                });
              }
            : null,
        onPanEnd: (widget.isDraggable && _selected)
            ? (_) {
                // Commit final position to parent
                widget.onPositionChanged(NoteImage(
                  id: widget.image.id,
                  path: widget.image.path,
                  x: _x,
                  y: _y,
                  width: _width,
                  height: _height,
                ));
              }
            : null,
        child: Stack(
          children: [
            // Image container
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: _width,
              height: _height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: (_selected && widget.isDraggable)
                    ? Border.all(color: AppTheme.primary, width: 2)
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withOpacity(_selected && widget.isDraggable ? 0.2 : 0.08),
                    blurRadius: _selected ? 16 : 8,
                    offset: const Offset(0, 3),
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  File(widget.image.path),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.broken_image),
                  ),
                ),
              ),
            ),

            // Controls shown when selected
            if (_selected && widget.isDraggable) ...[
              // Move handle (top-left)
              Positioned(
                top: -6, left: -6,
                child: Container(
                  width: 24, height: 24,
                  decoration: const BoxDecoration(
                      color: AppTheme.primary, shape: BoxShape.circle),
                  child: const Icon(Icons.open_with_rounded,
                      size: 14, color: Colors.white),
                ),
              ),
              // Delete button (top-right)
              Positioned(
                top: -6, right: -6,
                child: GestureDetector(
                  onTap: widget.onDelete,
                  child: Container(
                    width: 24, height: 24,
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle),
                    child: const Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
              // Drag instruction badge
              Positioned(
                bottom: 6,
                left: 0, right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Drag to move',
                        style: TextStyle(color: Colors.white, fontSize: 10)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Page tab ─────────────────────────────────────────────────────────────────

class _PageTab extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _PageTab({
    required this.label,
    this.icon,
    required this.isSelected,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 12,
                color: isSelected ? Colors.white : AppTheme.onSurfaceVariant),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : AppTheme.onSurfaceVariant,
              )),
        ]),
      ),
    );
  }
}

class _ModeBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeBtn(
      {required this.icon,
      required this.label,
      required this.isSelected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size: 22,
              color: isSelected ? AppTheme.primary : AppTheme.onSurfaceVariant),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color:
                    isSelected ? AppTheme.primary : AppTheme.onSurfaceVariant,
              )),
        ]),
      ),
    );
  }
}

// ─── Custom painters ──────────────────────────────────────────────────────────

class _RuledPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFFE8E8F0)
      ..strokeWidth = 0.6;
    const lineSpacing = 28.8;
    for (double y = 60; y < size.height; y += lineSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
    canvas.drawLine(
      const Offset(48, 0),
      Offset(48, size.height),
      Paint()
        ..color = const Color(0xFFFFCDD2).withOpacity(0.5)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

class _CoverPatternPainter extends CustomPainter {
  final Color color;
  const _CoverPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color..strokeWidth = 0.8;
    for (double y = 0; y < size.height; y += 40)
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    for (double x = 0; x < size.width; x += 40)
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
  }

  @override
  bool shouldRepaint(_) => false;
}
