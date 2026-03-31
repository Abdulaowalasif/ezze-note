import 'package:flutter/material.dart';
import '../models/note.dart';
import '../utils/theme.dart';

class CoverPickerSheet extends StatefulWidget {
  final Note note;
  final Function(Color color, String? emoji) onCoverChanged;

  const CoverPickerSheet({
    super.key,
    required this.note,
    required this.onCoverChanged,
  });

  @override
  State<CoverPickerSheet> createState() => _CoverPickerSheetState();
}

class _CoverPickerSheetState extends State<CoverPickerSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Color _selectedColor = AppTheme.primary;
  String? _selectedEmoji;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedColor = widget.note.coverColor;
    _selectedEmoji = widget.note.coverEmoji;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Preview
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            height: 100,
            decoration: BoxDecoration(
              color: _selectedColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: _selectedEmoji != null
                  ? Text(_selectedEmoji!, style: const TextStyle(fontSize: 40))
                  : Icon(Icons.notes_rounded,
                      color: Colors.white.withOpacity(0.5), size: 40),
            ),
          ),
          // Tabs
          TabBar(
            controller: _tabController,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.onSurfaceVariant,
            indicatorColor: AppTheme.primary,
            tabs: const [
              Tab(text: 'Colors'),
              Tab(text: 'Emojis'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildColorGrid(),
                _buildEmojiGrid(),
              ],
            ),
          ),
          // Apply button
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: () {
                widget.onCoverChanged(_selectedColor, _selectedEmoji);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Apply Cover'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorGrid() {
    return GridView.count(
      crossAxisCount: 4,
      padding: const EdgeInsets.all(16),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: AppTheme.coverColors.map((color) {
        final isSelected = color == _selectedColor;
        return GestureDetector(
          onTap: () => setState(() => _selectedColor = color),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? Colors.white : Colors.transparent,
                width: 3,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      )
                    ]
                  : [],
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white)
                : null,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmojiGrid() {
    return GridView.count(
      crossAxisCount: 5,
      padding: const EdgeInsets.all(16),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      children: [
        // None option
        GestureDetector(
          onTap: () => setState(() => _selectedEmoji = null),
          child: Container(
            decoration: BoxDecoration(
              color: _selectedEmoji == null
                  ? AppTheme.primary.withOpacity(0.1)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _selectedEmoji == null
                    ? AppTheme.primary
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: const Center(
              child: Text('—',
                  style: TextStyle(fontSize: 20, color: Colors.grey)),
            ),
          ),
        ),
        ...AppTheme.coverEmojis.map((emoji) {
          final isSelected = emoji == _selectedEmoji;
          return GestureDetector(
            onTap: () => setState(() => _selectedEmoji = emoji),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primary.withOpacity(0.1)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? AppTheme.primary : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 22)),
              ),
            ),
          );
        }),
      ],
    );
  }
}
