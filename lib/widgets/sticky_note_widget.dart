import 'package:flutter/material.dart';
import '../models/note.dart';
import '../utils/theme.dart';

class StickyNoteWidget extends StatefulWidget {
  final StickyNote stickyNote;
  final Function(StickyNote) onUpdate;
  final VoidCallback onDelete;
  final bool isEditable;

  const StickyNoteWidget({
    super.key,
    required this.stickyNote,
    required this.onUpdate,
    required this.onDelete,
    this.isEditable = true,
  });

  @override
  State<StickyNoteWidget> createState() => _StickyNoteWidgetState();
}

class _StickyNoteWidgetState extends State<StickyNoteWidget> {
  late double _x;
  late double _y;
  late TextEditingController _ctrl;
  bool _selected = false;

  @override
  void initState() {
    super.initState();
    _x = widget.stickyNote.x;
    _y = widget.stickyNote.y;
    _ctrl = TextEditingController(text: widget.stickyNote.content);
  }

  @override
  void didUpdateWidget(StickyNoteWidget old) {
    super.didUpdateWidget(old);
    if (!_selected) {
      _x = widget.stickyNote.x;
      _y = widget.stickyNote.y;
    }
    if (old.stickyNote.content != widget.stickyNote.content && !_ctrl.text.contains(widget.stickyNote.content)) {
      _ctrl.text = widget.stickyNote.content;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _commitPosition() {
    widget.onUpdate(_buildUpdated(x: _x, y: _y));
  }

  void _commitContent() {
    widget.onUpdate(_buildUpdated(content: _ctrl.text));
  }

  StickyNote _buildUpdated({double? x, double? y, String? content, Color? color}) {
    return StickyNote(
      id: widget.stickyNote.id,
      content: content ?? _ctrl.text,
      color: color ?? widget.stickyNote.color,
      x: x ?? _x,
      y: y ?? _y,
      width: widget.stickyNote.width,
      height: widget.stickyNote.height,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _x,
      top: _y,
      child: GestureDetector(
        onTap: widget.isEditable
            ? () => setState(() => _selected = !_selected)
            : null,
        onPanUpdate: (widget.isEditable && _selected)
            ? (d) => setState(() { _x += d.delta.dx; _y += d.delta.dy; })
            : null,
        onPanEnd: (widget.isEditable && _selected)
            ? (_) => _commitPosition()
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: widget.stickyNote.width,
          height: widget.stickyNote.height,
          decoration: BoxDecoration(
            color: widget.stickyNote.color,
            borderRadius: BorderRadius.circular(4),
            border: (_selected && widget.isEditable)
                ? Border.all(color: AppTheme.primary, width: 2)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(_selected && widget.isEditable ? 0.2 : 0.12),
                blurRadius: _selected ? 16 : 8,
                offset: const Offset(2, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header drag handle
              _buildHeader(),
              // Content area
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                  child: widget.isEditable
                      ? TextField(
                          controller: _ctrl,
                          maxLines: null,
                          expands: true,
                          onChanged: (_) => _commitContent(),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            filled: false,
                            hintText: 'Write here...',
                            hintStyle: TextStyle(color: Colors.black38, fontSize: 13),
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black87, height: 1.4),
                        )
                      : Text(
                          widget.stickyNote.content,
                          style: const TextStyle(fontSize: 12, color: Colors.black87),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 6,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 30,
      decoration: BoxDecoration(
        color: widget.stickyNote.color.withOpacity(0.6),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Icon(
            _selected && widget.isEditable ? Icons.open_with_rounded : Icons.drag_indicator_rounded,
            size: 15,
            color: Colors.black38,
          ),
          const Spacer(),
          if (widget.isEditable)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz, size: 15, color: Colors.black38),
              padding: EdgeInsets.zero,
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'color', child: Text('Change color')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
              onSelected: (v) {
                if (v == 'delete') widget.onDelete();
                if (v == 'color') _showColorPicker(context);
              },
            ),
        ],
      ),
    );
  }

  void _showColorPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sticky Color',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: AppTheme.stickyColors.map((c) => GestureDetector(
                onTap: () {
                  widget.onUpdate(_buildUpdated(color: c));
                  Navigator.pop(context);
                },
                child: Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: c == widget.stickyNote.color ? AppTheme.primary : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
              )).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
