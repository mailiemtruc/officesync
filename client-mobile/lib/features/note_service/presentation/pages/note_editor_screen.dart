import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/config/app_colors.dart';
import '../../../../core/utils/custom_snackbar.dart';
import '../../data/models/note_model.dart';

class NoteEditorScreen extends StatefulWidget {
  final NoteModel? note;

  const NoteEditorScreen({super.key, this.note});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  final List<String> _colors = [
    '0xFFFFFFFF', // White
    '0xFFFFF7D6', // Pastel Yellow
    '0xFFFFD6D6', // Pastel Red
    '0xFFD6F5FF', // Pastel Blue
    '0xFFE2F0CB', // Pastel Green
    '0xFFEAD6FF', // Pastel Purple
  ];

  String _selectedColor = '0xFFFFFFFF';
  bool _isPinned = false;
  bool _isLoading = false;
  bool _isDirty = false; // Đánh dấu đã có thay đổi

  @override
  void initState() {
    super.initState();
    if (widget.note != null) {
      _titleController.text = widget.note!.title;
      _contentController.text = widget.note!.content;
      _selectedColor = widget.note!.color;
      _isPinned = widget.note!.isPinned;
    }

    // Lắng nghe thay đổi để biết có cần save không
    _titleController.addListener(_markAsDirty);
    _contentController.addListener(_markAsDirty);
  }

  void _markAsDirty() {
    if (!_isDirty) {
      setState(() => _isDirty = true);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    // Chỉ save khi có nội dung và (đang tạo mới hoặc đã sửa đổi)
    if ((_titleController.text.isEmpty && _contentController.text.isEmpty) ||
        (widget.note != null &&
            !_isDirty &&
            _selectedColor == widget.note!.color &&
            _isPinned == widget.note!.isPinned)) {
      if (mounted) Navigator.pop(context);
      return;
    }

    setState(() => _isLoading = true);
    final client = ApiClient();
    final String baseUrl = '${ApiClient.noteUrl}/notes';

    final body = {
      "title": _titleController.text,
      "content": _contentController.text,

      "pinned": _isPinned,
      "isPinned": _isPinned,

      "color": _selectedColor,
    };

    try {
      if (widget.note == null) {
        await client.post(baseUrl, data: body);
      } else {
        await client.put('$baseUrl/${widget.note!.id}', data: body);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          title: "Error",
          message: "Failed to save note",
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteNote() async {
    if (widget.note == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Note?"),
        content: const Text("This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final client = ApiClient();
      await client.delete('${ApiClient.noteUrl}/notes/${widget.note!.id}');
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    Color bgColor = Color(int.parse(_selectedColor));

    // PopScope chặn nút back để tự động save
    return PopScope(
      canPop: false, // Chặn pop tự động
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _saveNote(); // Gọi hàm save, hàm này sẽ tự pop
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
            onPressed: _saveNote, // Nút back trên AppBar cũng gọi save
          ),
          actions: [
            IconButton(
              icon: Icon(
                _isPinned
                    ? PhosphorIconsFill.pushPin
                    : PhosphorIconsRegular.pushPin,
                color: _isPinned ? AppColors.primary : Colors.black54,
              ),
              onPressed: () {
                setState(() {
                  _isPinned = !_isPinned;
                  _isDirty = true;
                });
              },
            ),
            if (widget.note != null)
              IconButton(
                icon: const Icon(PhosphorIconsRegular.trash, color: Colors.red),
                onPressed: _deleteNote,
              ),
            IconButton(
              icon: const Icon(
                PhosphorIconsBold.check,
                color: AppColors.primary,
              ),
              onPressed: _saveNote,
            ),
            const SizedBox(width: 10),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        children: [
                          TextField(
                            controller: _titleController,
                            // Autofocus khi tạo mới
                            autofocus: widget.note == null,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                            decoration: const InputDecoration(
                              hintText: "Title",
                              hintStyle: TextStyle(color: Colors.black26),
                              border: InputBorder.none,
                            ),
                            maxLines: null,
                            textCapitalization: TextCapitalization.sentences,
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _contentController,
                            maxLines: null,
                            style: const TextStyle(
                              fontSize: 17,
                              height: 1.6,
                              color: Colors.black87,
                            ),
                            decoration: const InputDecoration(
                              hintText: "Start typing...",
                              hintStyle: TextStyle(color: Colors.black26),
                              border: InputBorder.none,
                            ),
                            textCapitalization: TextCapitalization.sentences,
                          ),
                          const SizedBox(height: 100),
                        ],
                      ),
              ),
              _buildBottomColorBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomColorBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _colors.length,
            itemBuilder: (context, index) {
              final colorHex = _colors[index];
              final color = Color(int.parse(colorHex));
              final isSelected = _selectedColor == colorHex;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedColor = colorHex;
                    _isDirty = true;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : Colors.grey.shade300,
                      width: isSelected ? 2.5 : 1,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 20, color: Colors.black54)
                      : null,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
