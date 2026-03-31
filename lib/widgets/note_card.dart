import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/note.dart';
import '../utils/theme.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onTogglePin;
  final bool isGrid;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onDelete,
    required this.onTogglePin,
    this.isGrid = true,
  });

  @override
  Widget build(BuildContext context) {
    return isGrid ? _buildGridCard(context) : _buildListCard(context);
  }

  Widget _buildGridCard(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              // Full-cover background
              Container(
                color: note.coverColor,
                width: double.infinity,
                height: double.infinity, // fill parent
              ),
              // Emoji / icon at center
              if (note.coverEmoji != null)
                Center(
                  child: Text(
                    note.coverEmoji!,
                    style: const TextStyle(fontSize: 48),
                  ),
                )
              else
                Center(
                  child: Icon(
                    Icons.notes_rounded,
                    color: Colors.white.withOpacity(0.6),
                    size: 48,
                  ),
                ),
              // Overlay: title, badges, pin at bottom
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            note.title.isEmpty ? 'Untitled' : note.title,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (note.isPinned)
                          const Icon(Icons.push_pin_rounded,
                              color: Colors.white, size: 14),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _buildBadgesCompact(),
                        const Spacer(),
                        _buildMenuButton(),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  /// List-style card with left color bar
  Widget _buildListCard(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: note.coverColor.withOpacity(0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Left color bar
                Container(
                  width: 56,
                  decoration: BoxDecoration(
                    color: note.coverColor,
                  ),
                  child: Center(
                    child: note.coverEmoji != null
                        ? Text(note.coverEmoji!,
                        style: const TextStyle(fontSize: 22))
                        : Icon(Icons.notes_rounded,
                        color: Colors.white.withOpacity(0.6), size: 22),
                  ),
                ),
                // Content
                Expanded(
                  child: Padding(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              note.title.isEmpty ? 'Untitled' : note.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AppTheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (note.isPinned)
                              const Icon(Icons.push_pin_rounded,
                                  size: 13, color: AppTheme.primary),
                          ],
                        ),
                        if (note.previewText.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            note.previewText,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              _formatDate(note.updatedAt),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade400,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${note.pages.length} page${note.pages.length != 1 ? "s" : ""}',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade400),
                            ),
                            const Spacer(),
                            _buildBadgesCompact(),
                            _buildMenuButton(),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadgesCompact() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (note.allDrawings.isNotEmpty) _SmallDot(color: AppTheme.primary),
        if (note.allImages.isNotEmpty) _SmallDot(color: AppTheme.accent1),
        if (note.allStickyNotes.isNotEmpty) _SmallDot(color: AppTheme.accent2),
        if (note.pages.length > 1)
          Container(
            margin: const EdgeInsets.only(right: 2),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${note.pages.length}p',
              style: const TextStyle(
                fontSize: 9,
                color: AppTheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMenuButton() {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, size: 15, color: Colors.grey.shade400),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'pin',
          child: Row(children: [
            Icon(note.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                size: 16),
            const SizedBox(width: 8),
            Text(note.isPinned ? 'Unpin' : 'Pin'),
          ]),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            Icon(Icons.delete_outline, size: 16, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete', style: TextStyle(color: Colors.red)),
          ]),
        ),
      ],
      onSelected: (val) {
        if (val == 'delete') onDelete();
        if (val == 'pin') onTogglePin();
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(date);
  }
}

class _SmallDot extends StatelessWidget {
  final Color color;
  const _SmallDot({required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      margin: const EdgeInsets.only(right: 3),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}