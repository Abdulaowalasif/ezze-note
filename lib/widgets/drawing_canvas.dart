import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../models/note.dart';
import '../utils/theme.dart';

enum DrawingTool { pen, highlighter, eraser, text }

// ─── Drawing Canvas ──────────────────────────────────────────────────────────

class DrawingCanvas extends StatefulWidget {
  final List<DrawnPoint> drawings;
  final bool isActive;
  final DrawingTool tool;
  final Color penColor;
  final double strokeWidth;
  final Function(List<DrawnPoint>) onDrawingsChanged;

  const DrawingCanvas({
    super.key,
    required this.drawings,
    required this.isActive,
    required this.tool,
    required this.penColor,
    required this.strokeWidth,
    required this.onDrawingsChanged,
  });

  @override
  State<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas> {
  // Active stroke being drawn right now
  DrawnPoint? _activeStroke;
  // Eraser trail for visual feedback
  Offset? _eraserPos;

  // ── Pointer handlers (supports stylus + finger) ───────────────────────────

  void _onPointerDown(PointerDownEvent e) {
    if (!widget.isActive || widget.tool == DrawingTool.text) return;

    // Palm rejection: ignore very large touch contact (palm)
    if (e.kind == PointerDeviceKind.touch && e.radiusMajor > 30) return;

    if (widget.tool == DrawingTool.eraser) {
      setState(() => _eraserPos = e.localPosition);
      _eraseAt(e.localPosition);
      return;
    }

    final color = widget.tool == DrawingTool.highlighter
        ? widget.penColor.withOpacity(0.38)
        : widget.penColor;
    final width = widget.tool == DrawingTool.highlighter
        ? widget.strokeWidth * 3.5
        : widget.strokeWidth;

    setState(() {
      _activeStroke = DrawnPoint(
        points: [e.localPosition],
        color: color,
        strokeWidth: width,
      );
    });
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (!widget.isActive || widget.tool == DrawingTool.text) return;
    if (e.kind == PointerDeviceKind.touch && e.radiusMajor > 30) return;

    if (widget.tool == DrawingTool.eraser) {
      setState(() => _eraserPos = e.localPosition);
      _eraseAt(e.localPosition);
      return;
    }

    if (_activeStroke == null) return;

    setState(() {
      _activeStroke = DrawnPoint(
        points: [..._activeStroke!.points, e.localPosition],
        color: _activeStroke!.color,
        strokeWidth: _activeStroke!.strokeWidth,
      );
    });
  }

  void _onPointerUp(PointerUpEvent e) {
    if (!widget.isActive) return;

    if (widget.tool == DrawingTool.eraser) {
      setState(() => _eraserPos = null);
      return;
    }

    if (_activeStroke != null) {
      widget.onDrawingsChanged([...widget.drawings, _activeStroke!]);
      setState(() => _activeStroke = null);
    }
  }

  void _eraseAt(Offset position) {
    final radius = widget.strokeWidth * 3.0;
    final remaining = widget.drawings.where((stroke) {
      // Remove any stroke that has a point within eraser radius
      return !stroke.points.any((p) => (p - position).distance < radius);
    }).toList();

    if (remaining.length != widget.drawings.length) {
      widget.onDrawingsChanged(remaining);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _CanvasPainter(
            committed: widget.drawings,
            active: _activeStroke,
            eraserPos: _eraserPos,
            eraserRadius: widget.strokeWidth * 3.0,
          ),
        ),
      ),
    );
  }
}

// ─── Painter ──────────────────────────────────────────────────────────────────

class _CanvasPainter extends CustomPainter {
  final List<DrawnPoint> committed;
  final DrawnPoint? active;
  final Offset? eraserPos;
  final double eraserRadius;

  const _CanvasPainter({
    required this.committed,
    required this.active,
    required this.eraserPos,
    required this.eraserRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw all committed strokes
    for (final stroke in committed) {
      _paintStroke(canvas, stroke.points, stroke.color, stroke.strokeWidth);
    }
    // Draw active (in-progress) stroke
    if (active != null) {
      _paintStroke(canvas, active!.points, active!.color, active!.strokeWidth);
    }
    // Eraser cursor
    if (eraserPos != null) {
      canvas.drawCircle(
        eraserPos!,
        eraserRadius,
        Paint()
          ..color = Colors.grey.withOpacity(0.18)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        eraserPos!,
        eraserRadius,
        Paint()
          ..color = Colors.grey.shade400
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
  }

  void _paintStroke(
      Canvas canvas, List<Offset> pts, Color color, double width) {
    if (pts.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = width
      ..style = PaintingStyle.stroke;

    if (pts.length == 1) {
      canvas.drawCircle(pts.first, width / 2,
          Paint()..color = color..style = PaintingStyle.fill);
      return;
    }

    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (int i = 0; i < pts.length - 1; i++) {
      final mid = Offset(
        (pts[i].dx + pts[i + 1].dx) / 2,
        (pts[i].dy + pts[i + 1].dy) / 2,
      );
      path.quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy);
    }
    path.lineTo(pts.last.dx, pts.last.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CanvasPainter old) =>
      old.committed != committed ||
      old.active != active ||
      old.eraserPos != eraserPos;
}

// ─── Drawing Toolbar ──────────────────────────────────────────────────────────

class DrawingToolbar extends StatefulWidget {
  final DrawingTool currentTool;
  final Color penColor;
  final double strokeWidth;
  final Function(DrawingTool) onToolChanged;
  final Function(Color) onColorChanged;
  final Function(double) onStrokeWidthChanged;
  final VoidCallback onUndo;
  final VoidCallback onClear;

  const DrawingToolbar({
    super.key,
    required this.currentTool,
    required this.penColor,
    required this.strokeWidth,
    required this.onToolChanged,
    required this.onColorChanged,
    required this.onStrokeWidthChanged,
    required this.onUndo,
    required this.onClear,
  });

  @override
  State<DrawingToolbar> createState() => _DrawingToolbarState();
}

class _DrawingToolbarState extends State<DrawingToolbar> {
  bool _showStrokeSlider = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_showStrokeSlider) _buildStrokeSlider(),
        _buildMainRow(),
      ],
    );
  }

  Widget _buildStrokeSlider() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          // Live preview dot
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: widget.strokeWidth.clamp(4.0, 28.0),
            height: widget.strokeWidth.clamp(4.0, 28.0),
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: widget.penColor,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Slider(
              value: widget.strokeWidth,
              min: 1.0,
              max: 24.0,
              divisions: 23,
              activeColor: widget.penColor,
              inactiveColor: Colors.grey.shade200,
              onChanged: widget.onStrokeWidthChanged,
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '${widget.strokeWidth.round()}px',
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.onSurfaceVariant),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainRow() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ToolBtn(
            icon: Icons.edit_rounded,
            label: 'Pen',
            isSelected: widget.currentTool == DrawingTool.pen,
            color: widget.penColor,
            onTap: () {
              widget.onToolChanged(DrawingTool.pen);
              setState(() => _showStrokeSlider =
                  widget.currentTool != DrawingTool.pen || !_showStrokeSlider);
            },
          ),
          _ToolBtn(
            icon: Icons.highlight_rounded,
            label: 'Highlight',
            isSelected: widget.currentTool == DrawingTool.highlighter,
            color: Colors.amber.shade600,
            onTap: () {
              widget.onToolChanged(DrawingTool.highlighter);
              setState(() => _showStrokeSlider =
                  widget.currentTool != DrawingTool.highlighter ||
                      !_showStrokeSlider);
            },
          ),
          _ToolBtn(
            icon: Icons.text_fields_rounded,
            label: 'Text',
            isSelected: widget.currentTool == DrawingTool.text,
            color: AppTheme.accent2,
            onTap: () {
              widget.onToolChanged(DrawingTool.text);
              setState(() => _showStrokeSlider = false);
            },
          ),
          _ToolBtn(
            icon: Icons.auto_fix_normal_rounded,
            label: 'Erase',
            isSelected: widget.currentTool == DrawingTool.eraser,
            color: Colors.grey.shade600,
            onTap: () {
              widget.onToolChanged(DrawingTool.eraser);
              setState(() => _showStrokeSlider =
                  widget.currentTool != DrawingTool.eraser ||
                      !_showStrokeSlider);
            },
          ),
          // Color swatch
          GestureDetector(
            onTap: () => _showColorPicker(context),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: widget.penColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300, width: 2),
                boxShadow: [
                  BoxShadow(
                      color: widget.penColor.withOpacity(0.4), blurRadius: 6)
                ],
              ),
            ),
          ),
          _ToolBtn(
            icon: Icons.undo_rounded,
            label: 'Undo',
            color: AppTheme.onSurfaceVariant,
            onTap: widget.onUndo,
          ),
          _ToolBtn(
            icon: Icons.delete_sweep_rounded,
            label: 'Clear',
            color: Colors.red.shade400,
            onTap: widget.onClear,
          ),
        ],
      ),
    );
  }

  void _showColorPicker(BuildContext context) {
    final colors = [
      Colors.black87,
      const Color(0xFF6B4EFF),
      const Color(0xFFFF6B9D),
      const Color(0xFF4ECBFF),
      const Color(0xFFFF9F4E),
      Colors.red,
      Colors.green.shade600,
      Colors.blue.shade700,
      Colors.orange,
      Colors.teal,
      Colors.brown,
      Colors.pink,
      Colors.indigo,
      Colors.cyan.shade700,
      Colors.lime.shade700,
      Colors.deepPurple,
      Colors.white,
      Colors.grey.shade400,
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ink Color',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: colors
                  .map((c) => GestureDetector(
                        onTap: () {
                          widget.onColorChanged(c);
                          Navigator.pop(context);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: c == widget.penColor
                                  ? AppTheme.primary
                                  : Colors.grey.shade300,
                              width: c == widget.penColor ? 3 : 1.5,
                            ),
                            boxShadow: c == widget.penColor
                                ? [
                                    BoxShadow(
                                        color: c.withOpacity(0.5),
                                        blurRadius: 8)
                                  ]
                                : [],
                          ),
                          child: c == widget.penColor
                              ? const Icon(Icons.check,
                                  size: 18, color: Colors.black54)
                              : null,
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _ToolBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _ToolBtn({
    required this.icon,
    required this.label,
    this.isSelected = false,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon,
              size: 21,
              color: isSelected ? color : AppTheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
