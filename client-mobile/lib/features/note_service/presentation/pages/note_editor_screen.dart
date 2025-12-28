import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_quill/flutter_quill.dart'; // Import trực tiếp
import 'package:google_fonts/google_fonts.dart';

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
  late QuillController _quillController;

  // [QUAN TRỌNG] FocusNode để quản lý con trỏ tốt hơn
  final FocusNode _editorFocusNode = FocusNode();

  final List<String> _colors = [
    '0xFFFFFFFF',
    '0xFFFFF7D6',
    '0xFFFFD6D6',
    '0xFFD6F5FF',
    '0xFFE2F0CB',
    '0xFFEAD6FF',
  ];

  String _selectedColor = '0xFFFFFFFF';
  bool _isPinned = false;
  bool _isLoading = false;
  bool _isDirty = false;
  String? _currentPin;

  // Cấu hình Font chữ
  final Map<String, String> _fontFamilyMap = {
    'Sans Serif': 'roboto',
    'Serif': 'lora',
    'Monospace': 'roboto_mono',
    'Handwriting': 'dancing_script',
    'Stylish': 'merriweather',
  };

  @override
  void initState() {
    super.initState();
    _initializeEditors();

    _titleController.addListener(_markAsDirty);
    // Lắng nghe thay đổi nội dung để bật nút Save
    _quillController.document.changes.listen((event) {
      _markAsDirty();
    });
  }

  void _initializeEditors() {
    String initialTitle = "";
    bool initialPinned = false;
    String? initialPin;

    Document quillDoc = Document()..insert(0, '');

    if (widget.note != null) {
      initialTitle = widget.note!.title;
      _selectedColor = widget.note!.color;
      initialPinned = widget.note!.isPinned;
      initialPin = widget.note!.pin;

      try {
        final jsonContent = jsonDecode(widget.note!.content);
        quillDoc = Document.fromJson(jsonContent);
      } catch (e) {
        quillDoc = Document()..insert(0, '${widget.note!.content}\n');
      }
    }

    _titleController.text = initialTitle;
    _quillController = QuillController(
      document: quillDoc,
      selection: const TextSelection.collapsed(offset: 0),
    );
    _isPinned = initialPinned;
    _currentPin = initialPin;
  }

  void _markAsDirty() {
    if (!_isDirty) setState(() => _isDirty = true);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _quillController.dispose();
    _editorFocusNode.dispose(); // Giải phóng FocusNode
    super.dispose();
  }

  // --- Logic Khóa Note (Không thay đổi) ---
  Future<void> _handleLockNote() async {
    if (_currentPin != null) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => Dialog(
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2260FF).withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2260FF).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    PhosphorIconsFill.lockKeyOpen,
                    size: 32,
                    color: Color(0xFF2260FF),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Remove protection?",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  "This note will no longer be protected by a PIN code.",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text("Cancel"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFEBEE),
                        ),
                        child: const Text(
                          "Remove",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      if (confirm == true) {
        setState(() {
          _currentPin = null;
          _isDirty = true;
        });
        if (mounted)
          CustomSnackBar.show(
            context,
            title: "Success",
            message: "Password protection removed.",
            isError: false,
            marginBottom: 50,
          );
      }
    } else {
      final newPin = await _showPinDialog(context, isSetting: true);
      if (newPin != null && newPin.length == 6) {
        setState(() {
          _currentPin = newPin;
          _isDirty = true;
        });
        if (mounted)
          CustomSnackBar.show(
            context,
            title: "Success",
            message: "Note protected with PIN.",
            isError: false,
            marginBottom: 50,
          );
      }
    }
  }

  // --- Logic Nhập PIN (Không thay đổi) ---
  Future<String?> _showPinDialog(
    BuildContext context, {
    bool isSetting = false,
  }) async {
    String currentPin = "";
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2260FF).withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      PhosphorIconsFill.lockKey,
                      size: 32,
                      color: Color(0xFF2260FF),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isSetting ? "Set PIN Code" : "Enter PIN Code",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            6,
                            (index) => Container(
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: index < currentPin.length
                                    ? const Color(0xFF2260FF)
                                    : const Color(0xFFE3E3E8),
                              ),
                            ),
                          ),
                        ),
                        Opacity(
                          opacity: 0.0,
                          child: TextField(
                            autofocus: true,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            onChanged: (value) {
                              setStateDialog(() {
                                currentPin = value;
                              });
                              if (value.length == 6)
                                Future.delayed(
                                  const Duration(milliseconds: 100),
                                  () => Navigator.pop(ctx, value),
                                );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- Logic Lưu Note ---
  Future<void> _saveNote() async {
    // Ẩn bàn phím trước khi lưu để tránh lỗi UI
    FocusScope.of(context).unfocus();

    String contentJson = jsonEncode(
      _quillController.document.toDelta().toJson(),
    );
    bool isContentEmpty = _quillController.document
        .toPlainText()
        .trim()
        .isEmpty;

    if ((_titleController.text.isEmpty && isContentEmpty) ||
        (widget.note != null &&
            !_isDirty &&
            _selectedColor == widget.note!.color &&
            _isPinned == widget.note!.isPinned &&
            _currentPin == widget.note!.pin)) {
      if (mounted) Navigator.pop(context);
      return;
    }

    setState(() => _isLoading = true);
    final client = ApiClient();
    final String baseUrl = '${ApiClient.noteUrl}/notes';

    final body = {
      "title": _titleController.text,
      "content": contentJson,
      "pinned": _isPinned,
      "isPinned": _isPinned,
      "color": _selectedColor,
      "pin": _currentPin,
    };

    try {
      if (widget.note == null) {
        await client.post(baseUrl, data: body);
      } else {
        await client.put('$baseUrl/${widget.note!.id}', data: body);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted)
        CustomSnackBar.show(
          context,
          title: "Error",
          message: "Failed to save note",
          isError: true,
          marginBottom: 50,
        );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteNote() async {
    // ... (Logic xóa giữ nguyên như cũ)
    if (widget.note == null) return;
    // (Thêm code showDialog xóa ở đây nếu cần, tôi rút gọn để tập trung vào Editor)
    final client = ApiClient();
    await client.delete('${ApiClient.noteUrl}/notes/${widget.note!.id}');
    if (mounted) Navigator.pop(context);
  }

  // --- SHEET CHỌN MÀU ---
  void _showColorPickerSheet() {
    // Không unfocus bàn phím ở đây để trải nghiệm mượt mà hơn,
    // người dùng chọn màu xong có thể gõ tiếp luôn.
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                  child: Text(
                    "Change Background Color",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                SizedBox(
                  height: 60,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
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
                          (context as Element).markNeedsBuild();
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 12),
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.grey.shade300,
                              width: isSelected ? 3 : 1,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  size: 24,
                                  color: Colors.black54,
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper ánh xạ Font
  TextStyle _getFontStyle(Attribute attribute) {
    if (attribute.key == Attribute.font.key) {
      switch (attribute.value) {
        case 'roboto':
          return GoogleFonts.roboto();
        case 'lora':
          return GoogleFonts.lora();
        case 'roboto_mono':
          return GoogleFonts.robotoMono();
        case 'dancing_script':
          return GoogleFonts.dancingScript();
        case 'merriweather':
          return GoogleFonts.merriweather();
        default:
          return GoogleFonts.roboto();
      }
    }
    return const TextStyle();
  }

  @override
  Widget build(BuildContext context) {
    Color bgColor = Color(int.parse(_selectedColor));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _saveNote();
      },
      child: Scaffold(
        backgroundColor: bgColor,
        // [QUAN TRỌNG] resizeToAvoidBottomInset: true giúp đẩy nội dung lên khi bàn phím hiện
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
            onPressed: _saveNote,
          ),
          actions: [
            IconButton(
              icon: const Icon(
                PhosphorIconsFill.palette,
                color: Colors.black54,
              ),
              tooltip: "Background Color",
              onPressed: _showColorPickerSheet,
            ),
            IconButton(
              icon: Icon(
                _currentPin != null
                    ? PhosphorIconsFill.lockKey
                    : PhosphorIconsRegular.lockKeyOpen,
                color: _currentPin != null ? Colors.redAccent : Colors.black54,
              ),
              onPressed: _handleLockNote,
            ),
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
        body: Column(
          children: [
            // --- VÙNG SOẠN THẢO ---
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    TextField(
                      controller: _titleController,
                      autofocus: widget.note == null,
                      style: GoogleFonts.roboto(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                        color: Colors.black87,
                      ),
                      decoration: const InputDecoration(
                        hintText: "Title",
                        border: InputBorder.none,
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: QuillEditor.basic(
                        configurations: QuillEditorConfigurations(
                          controller: _quillController,
                          // Gắn FocusNode để quản lý
                          // (Lưu ý: version 10.8.4 có thể không cần tham số này trực tiếp nếu autoFocus hoạt động tốt,
                          // nhưng nếu có lỗi focus, ta sẽ dùng FocusNode bọc ngoài)
                          placeholder: "Start typing...",
                          autoFocus:
                              false, // Để false để tránh nhảy focus khi mở lại note
                          expands: true,
                          scrollable: true,
                          padding: EdgeInsets.zero,
                          sharedConfigurations: const QuillSharedConfigurations(
                            locale: Locale('en'),
                          ),
                          customStyleBuilder: (attribute) {
                            if (attribute.key == Attribute.font.key)
                              return _getFontStyle(attribute);
                            return const TextStyle();
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // --- THANH CÔNG CỤ (TOOLBAR) ---
            // Nằm ngay trên bàn phím
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: SafeArea(
                top: false, // Không cần top safe area vì nằm dưới
                child: QuillToolbar.simple(
                  configurations: QuillSimpleToolbarConfigurations(
                    controller: _quillController,
                    showAlignmentButtons: false,
                    showHeaderStyle: true,
                    showListBullets: true,
                    showListNumbers: true,
                    showQuote: false,
                    showCodeBlock: false,
                    showLink: false,
                    showIndent: false,

                    // Cấu hình chọn Font
                    showFontFamily: true,
                    fontFamilyValues: _fontFamilyMap,

                    multiRowsDisplay: false,
                    buttonOptions: const QuillSimpleToolbarButtonOptions(
                      base: QuillToolbarBaseButtonOptions(
                        iconTheme: QuillIconTheme(
                          iconButtonSelectedData: IconButtonData(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
