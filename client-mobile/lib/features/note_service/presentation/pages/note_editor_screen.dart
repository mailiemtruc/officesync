import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:google_fonts/google_fonts.dart';

// Giả định các import này đúng trong dự án của bạn
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
  bool _isLoading = false; // Đã xử lý để hiển thị loading
  bool _isDirty = false;
  String? _currentPin;

  final Map<String, String> _fontFamilyMap = {
    'Sans Serif': 'roboto',
    'Serif': 'lora',
    'Monospace': 'roboto_mono',
    'Handwriting': 'dancing_script',
    'Stylish': 'merriweather',
  };

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

  // 1. Sheet chọn Font (Đã thêm độ trễ để fix lỗi bàn phím)
  void _showFontFamilySheet() async {
    FocusScope.of(context).unfocus();
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.5,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Select Font",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView(
                  children: _fontFamilyMap.entries.map((entry) {
                    final attribute =
                        Attribute.fromKeyValue('font', entry.value)
                            as Attribute;
                    return ListTile(
                      title: Text(entry.key, style: _getFontStyle(attribute)),
                      onTap: () {
                        _quillController.formatSelection(attribute);
                        Navigator.pop(context); // Đóng sheet

                        // [QUAN TRỌNG 2] Gọi con trỏ quay về Editor
                        Future.delayed(const Duration(milliseconds: 50), () {
                          if (mounted) _editorFocusNode.requestFocus();
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 2. Sheet chọn Size (Đã thêm độ trễ)
  void _showFontSizeSheet() async {
    FocusScope.of(context).unfocus();
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    final Map<String?, String> sizes = {
      'small': 'Small',
      null: 'Normal',
      'large': 'Large',
      'huge': 'Huge',
    };

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "Font Size",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              ...sizes.entries.map((entry) {
                return ListTile(
                  title: Text(entry.value),
                  onTap: () {
                    if (entry.key == null) {
                      _quillController.formatSelection(
                        Attribute.fromKeyValue('size', null),
                      );
                    } else {
                      _quillController.formatSelection(
                        Attribute.fromKeyValue('size', entry.key),
                      );
                    }
                    Navigator.pop(context); // Đóng sheet

                    // [QUAN TRỌNG 2] Gọi con trỏ quay về Editor
                    Future.delayed(const Duration(milliseconds: 50), () {
                      if (mounted) _editorFocusNode.requestFocus();
                    });
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // 3. Sheet chọn Header (Đã thêm độ trễ)
  void _showHeaderStyleSheet() async {
    FocusScope.of(context).unfocus();
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    final List<Map<String, dynamic>> styles = [
      {
        'label': 'Normal',
        'attr': Attribute.fromKeyValue('header', null),
        'size': 16.0,
      },
      {'label': 'Heading 1', 'attr': Attribute.h1, 'size': 24.0},
      {'label': 'Heading 2', 'attr': Attribute.h2, 'size': 20.0},
      {'label': 'Heading 3', 'attr': Attribute.h3, 'size': 18.0},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "Text Style",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              ...styles.map((style) {
                return ListTile(
                  title: Text(
                    style['label'] as String,
                    style: TextStyle(
                      fontSize: style['size'] as double,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    final attr = style['attr'] as Attribute;
                    _quillController.formatSelection(attr);
                    Navigator.pop(context); // Đóng sheet

                    // [QUAN TRỌNG 2] Gọi con trỏ quay về Editor
                    Future.delayed(const Duration(milliseconds: 50), () {
                      if (mounted) _editorFocusNode.requestFocus();
                    });
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _initializeEditors();

    _titleController.addListener(_markAsDirty);
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
    _editorFocusNode.dispose();
    super.dispose();
  }

  // --- LOGIC XỬ LÝ KHÓA/MỞ KHÓA (GIAO DIỆN ĐỒNG BỘ MÀU #2260FF) ---
  Future<void> _handleLockNote() async {
    FocusScope.of(context).unfocus(); // Ẩn bàn phím

    // TRƯỜNG HỢP 1: Đang có khóa -> Muốn gỡ bỏ
    if (_currentPin != null) {
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => Dialog(
          elevation: 0,
          backgroundColor: Colors.transparent, // Để hiển thị bo góc đẹp hơn
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2260FF).withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Icon Mở khóa (Xanh chủ đạo)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2260FF).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    PhosphorIconsFill.lockKeyOpen, // Icon mở khóa
                    size: 32,
                    color: Color(0xFF2260FF),
                  ),
                ),
                const SizedBox(height: 20),

                // 2. Tiêu đề & Nội dung
                const Text(
                  "Remove Lock",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Are you sure you want to remove the PIN protection?",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),

                // 3. Hai nút bấm (Cancel & Remove)
                Row(
                  children: [
                    // Nút Cancel (Màu xám)
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "Cancel",
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Nút Remove (Màu xanh chủ đạo 2260FF)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2260FF),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "Remove",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
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

      // Xử lý kết quả sau khi bấm nút
      if (confirm == true) {
        setState(() {
          _currentPin = null;
          _isDirty = true;
        });
        if (mounted) {
          CustomSnackBar.show(
            context,
            title: "Success",
            message: "Lock removed successfully",
            isError: false,
          );
        }
      }
    }
    // TRƯỜNG HỢP 2: Chưa khóa -> Muốn đặt khóa mới
    else {
      final String? newPin = await _showPinDialog(context, isSetting: true);

      if (newPin != null && newPin.length == 6) {
        setState(() {
          _currentPin = newPin;
          _isDirty = true;
        });
        if (mounted) {
          CustomSnackBar.show(
            context,
            title: "Success",
            message: "Note locked successfully!",
            isError: false,
          );
        }
      }
    }
  }

  // --- DIALOG NHẬP PIN (Style Banking) ---
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
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2260FF).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isSetting
                            ? PhosphorIconsFill.shieldCheck
                            : PhosphorIconsFill.lockKey,
                        size: 32,
                        color: const Color(0xFF2260FF),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isSetting ? "Set New PIN" : "Enter PIN Code",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isSetting
                          ? "Enter 6 digits to lock this note"
                          : "Enter 6 digits to unlock",
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // Ô nhập PIN ẩn
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(6, (index) {
                            bool isFilled = index < currentPin.length;
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isFilled
                                    ? const Color(0xFF2260FF)
                                    : const Color(0xFFE3E3E8),
                              ),
                            );
                          }),
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
                              if (value.length == 6) {
                                Future.delayed(
                                  const Duration(milliseconds: 100),
                                  () {
                                    Navigator.pop(ctx, value);
                                  },
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
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
      if (mounted) {
        CustomSnackBar.show(
          context,
          title: "Error",
          message: "Failed to save note",
          isError: true,
          marginBottom: 50,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteNote() async {
    if (widget.note == null) return;
    final client = ApiClient();
    await client.delete('${ApiClient.noteUrl}/notes/${widget.note!.id}');
    if (mounted) Navigator.pop(context);
  }

  void _showColorPickerSheet() {
    // ... (Code cũ của bạn giữ nguyên) ...
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
              onPressed: () => setState(() {
                _isPinned = !_isPinned;
                _isDirty = true;
              }),
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
        body: Stack(
          children: [
            Column(
              children: [
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
                            focusNode: _editorFocusNode,
                            configurations: QuillEditorConfigurations(
                              controller: _quillController,
                              placeholder: "Start typing...",
                              autoFocus: false,
                              expands: true,
                              scrollable: true,
                              padding: EdgeInsets.zero,
                              sharedConfigurations:
                                  const QuillSharedConfigurations(
                                    locale: Locale('en'),
                                  ),
                              customStyleBuilder: (attribute) {
                                if (attribute.key == Attribute.font.key) {
                                  return _getFontStyle(attribute);
                                }
                                return const TextStyle();
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // --- TOOLBAR ĐÃ SỬA LỖI ---
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: SafeArea(
                    top: false,
                    child: QuillToolbar.simple(
                      configurations: QuillSimpleToolbarConfigurations(
                        controller: _quillController,

                        // 1. Tắt các nút mặc định
                        showFontFamily: false,
                        showFontSize: false,
                        showHeaderStyle: false,

                        showAlignmentButtons: false,
                        showListBullets: true,
                        showListNumbers: true,
                        showQuote: false,
                        showCodeBlock: false,
                        showLink: false,
                        showIndent: false,
                        multiRowsDisplay: false,

                        // 2. Thêm nút Custom (ĐÃ XOÁ THAM SỐ CONTROLLER THỪA)
                        customButtons: [
                          QuillToolbarCustomButtonOptions(
                            icon: const Icon(Icons.font_download_outlined),
                            tooltip: 'Font Family',
                            onPressed: _showFontFamilySheet,
                          ),
                          QuillToolbarCustomButtonOptions(
                            icon: const Icon(Icons.text_fields_rounded),
                            tooltip: 'Text Style',
                            onPressed: _showHeaderStyleSheet,
                          ),
                          QuillToolbarCustomButtonOptions(
                            icon: const Icon(Icons.format_size_rounded),
                            tooltip: 'Font Size',
                            onPressed: _showFontSizeSheet,
                          ),
                        ],

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

            // Loading Overlay (Sửa warning _isLoading isn't used)
            if (_isLoading)
              Container(
                color: Colors.black12,
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}
