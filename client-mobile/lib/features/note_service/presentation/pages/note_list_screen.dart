import 'dart:async';
import 'dart:convert';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter/material.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/config/app_colors.dart';
import '../../../../core/utils/custom_snackbar.dart';
import '../../data/models/note_model.dart';
import 'note_editor_screen.dart';

// Enum cho các kiểu sắp xếp
enum SortType { dateUpdated, title }

class NoteListScreen extends StatefulWidget {
  const NoteListScreen({super.key});

  @override
  State<NoteListScreen> createState() => _NoteListScreenState();
}

class _NoteListScreenState extends State<NoteListScreen> {
  // Dữ liệu
  List<NoteModel> _allNotes = []; // Danh sách gốc từ API
  Map<String, List<NoteModel>> _groupedNotes =
      {}; // Danh sách đã gom nhóm hiển thị

  // Trạng thái
  bool _isLoading = true;
  SortType _sortType =
      SortType.dateUpdated; // Mặc định sắp xếp theo ngày sửa gần nhất

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  // Hàm chuyển đổi JSON (Quill Delta) sang Plain Text
  String _getPlainText(String jsonContent) {
    if (jsonContent.isEmpty) return "";
    try {
      // 1. Decode chuỗi JSON thành List
      final jsonData = jsonDecode(jsonContent);

      // 2. Tạo Quill Document từ dữ liệu JSON
      final doc = quill.Document.fromJson(jsonData);

      // 3. Lấy văn bản thuần và thay thế xuống dòng bằng khoảng trắng
      return doc.toPlainText().trim().replaceAll('\n', ' ');
    } catch (e) {
      // Nếu lỗi (hoặc dữ liệu cũ không phải JSON), trả về nguyên gốc
      return jsonContent;
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchNotes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchNotes({String? query}) async {
    try {
      final client = ApiClient();
      String endpoint = '${ApiClient.noteUrl}/notes';

      if (query != null && query.isNotEmpty) {
        endpoint = '${ApiClient.noteUrl}/notes/search?q=$query';
      }

      final response = await client.get(endpoint);

      if (mounted) {
        final List<dynamic> data = response.data;
        List<NoteModel> fetchedNotes = data
            .map((e) => NoteModel.fromJson(e))
            .toList();

        setState(() {
          _allNotes = fetchedNotes;
          _applySort(); // Sắp xếp và gom nhóm ngay khi có dữ liệu
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // Có thể hiện snackbar lỗi nếu cần
        print("Error fetching notes: $e");
      }
    }
  }

  void _applySort() {
    // Sắp xếp danh sách gốc
    _allNotes.sort((a, b) {
      // [QUAN TRỌNG] Ưu tiên Note ghim (isPinned = true) lên đầu tiên
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }

      // Sau đó mới xét đến tiêu chí sắp xếp khác (Ngày tháng hoặc Tên)
      if (_sortType == SortType.dateUpdated) {
        return b.updatedAt.compareTo(a.updatedAt);
      } else {
        return a.title.compareTo(b.title);
      }
    });

    // Gom nhóm lại để hiển thị
    _groupedNotes = _groupNotesByDate(_allNotes);
  }

  // Logic gom nhóm thông minh (Hôm nay, Hôm qua, Tháng X...)
  Map<String, List<NoteModel>> _groupNotesByDate(List<NoteModel> notes) {
    Map<String, List<NoteModel>> groups = {};

    // --- [LOGIC MỚI] Tách Note ghim ra riêng ---
    // Lọc ra các note Đã ghim và Chưa ghim
    List<NoteModel> pinnedNotes = notes.where((n) => n.isPinned).toList();
    List<NoteModel> unpinnedNotes = notes.where((n) => !n.isPinned).toList();

    // 1. Nếu có note ghim, tạo nhóm "Đã ghim" đặt lên đầu
    if (pinnedNotes.isNotEmpty) {
      groups["Pinned"] = pinnedNotes;
    }
    // ------------------------------------------

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 2. Chỉ chia nhóm ngày tháng cho các note CHƯA ghim
    for (var note in unpinnedNotes) {
      DateTime noteDate;
      try {
        noteDate = DateTime.parse(note.updatedAt);
      } catch (e) {
        noteDate = DateTime.now();
      }

      final noteDay = DateTime(noteDate.year, noteDate.month, noteDate.day);
      final difference = today.difference(noteDay).inDays;

      String groupTitle;
      if (difference == 0)
        groupTitle = "Today";
      else if (difference == 1)
        groupTitle = "Yesterday";
      else if (difference <= 7)
        groupTitle = "7 days ago";
      else if (difference <= 30)
        groupTitle = "30 days ago";
      else
        groupTitle = "Month ${noteDate.month} ${noteDate.year}";
      if (groups[groupTitle] == null) groups[groupTitle] = [];
      groups[groupTitle]!.add(note);
    }

    return groups;
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() => _isLoading = true);
      _fetchNotes(query: query);
    });
  }

  // --- MENU TÙY CHỌN (Chỉ còn Sắp xếp) ---
  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              const Padding(
                padding: EdgeInsets.only(left: 16, bottom: 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Sort by",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              ListTile(
                leading: const Icon(PhosphorIconsRegular.clock),
                title: const Text("Date updated (Newest)"),
                trailing: _sortType == SortType.dateUpdated
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  setState(() {
                    _sortType = SortType.dateUpdated;
                    _applySort();
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(PhosphorIconsRegular.textAa),
                title: const Text("Title (A-Z)"),
                trailing: _sortType == SortType.title
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  setState(() {
                    _sortType = SortType.title;
                    _applySort();
                  });
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7), // Màu nền iOS
      body: SafeArea(
        child: Column(
          children: [
            _buildCustomAppBar(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _allNotes.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: () =>
                          _fetchNotes(query: _searchController.text),
                      // Luôn hiển thị List View
                      child: _buildListView(),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(
          PhosphorIconsRegular.plus,
          color: Colors.white,
          size: 28,
        ),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NoteEditorScreen()),
          );
          _fetchNotes(query: _searchController.text);
        },
      ),
    );
  }

  // --- WIDGET LIST VIEW (Chính) ---
  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      itemCount: _groupedNotes.keys.length,
      itemBuilder: (context, index) {
        String key = _groupedNotes.keys.elementAt(index);
        List<NoteModel> notesInGroup = _groupedNotes[key]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 24, bottom: 8),
              child: Text(
                key,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  fontFamily: 'Inter',
                ),
              ),
            ),
            ...notesInGroup.map((note) => _buildListNoteItem(note)),
          ],
        );
      },
    );
  }

  // --- APP BAR (ĐÃ SỬA TIÊU ĐỀ) ---
  Widget _buildCustomAppBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      color: const Color(0xFFF2F2F7),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios,
                  color: AppColors.primary,
                  size: 22,
                ),
                onPressed: () => Navigator.pop(context),
              ),

              const Text(
                "NOTE",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2260FF),
                  fontFamily: 'Inter',
                ),
              ),

              IconButton(
                icon: const Icon(
                  PhosphorIconsRegular.dotsThreeCircle,
                  color: AppColors.primary,
                  size: 28,
                ),
                onPressed: _showSortOptions,
              ),
            ],
          ),
          const SizedBox(height: 5),

          Container(
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFE3E3E8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              textAlignVertical: TextAlignVertical.center,
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                isDense: true,
                hintText: "Search",
                hintStyle: TextStyle(color: Colors.grey[600], fontSize: 16),
                prefixIcon: Icon(
                  PhosphorIconsRegular.magnifyingGlass,
                  color: Colors.grey[600],
                  size: 20,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.cancel,
                          size: 18,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- ITEM CỦA DANH SÁCH ---
  Widget _buildListNoteItem(NoteModel note) {
    // Kiểm tra xem note có cài mã PIN không
    bool isLocked = note.pin != null && note.pin!.isNotEmpty;

    return GestureDetector(
      onTap: () async {
        if (isLocked) {
          // --- LOGIC MỞ KHÓA ---
          final input = await _showPinDialog(context);

          if (input == null) return; // Người dùng bấm hủy

          // [PHẦN SỬA ĐỔI QUAN TRỌNG Ở ĐÂY] ---------------------------
          bool isCorrect = false;
          try {
            // Dùng BCrypt để so sánh mật khẩu nhập vào (input) với mã Hash (note.pin)
            isCorrect = BCrypt.checkpw(input, note.pin!);
          } catch (e) {
            // Fallback: Nếu dữ liệu cũ chưa mã hóa (còn là số thường), so sánh kiểu cũ
            isCorrect = input == note.pin;
          }
          // -----------------------------------------------------------

          if (isCorrect) {
            // Đúng mã -> Vào màn hình sửa
            if (!mounted) return;
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note)),
            );
            _fetchNotes(query: _searchController.text);
          } else {
            // Sai mã -> Báo lỗi
            if (!mounted) return;
            CustomSnackBar.show(
              context,
              title: "Access denied",
              message: "The PIN is incorrect!",
              isError: true,
            );
          }
        } else {
          // --- KHÔNG KHÓA -> VÀO LUÔN ---
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note)),
          );
          _fetchNotes(query: _searchController.text);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dòng 1: Tiêu đề + Ghim + Khóa
            Row(
              children: [
                if (note.isPinned)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(
                      PhosphorIconsFill.pushPin,
                      size: 16,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                Expanded(
                  child: Text(
                    // Nếu khóa thì hiện "Secret"
                    isLocked
                        ? "Secret"
                        : (note.title.isEmpty ? "No title" : note.title),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: isLocked ? Colors.grey[600] : Colors.black87,
                      fontStyle: isLocked ? FontStyle.italic : FontStyle.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Icon khóa
                if (isLocked)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(
                      PhosphorIconsFill.lockKey,
                      size: 18,
                      color: Colors.redAccent,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),

            // Dòng 2: Ngày + Nội dung
            Row(
              children: [
                Text(
                  _formatDateSimple(note.updatedAt),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    // Nếu bị khóa thì hiện dấu chấm, nếu không thì parse JSON ra text
                    isLocked ? "••••••••" : _getPlainText(note.content),
                    style: TextStyle(
                      fontSize: 14,
                      color: isLocked ? Colors.grey[300] : Colors.grey[500],
                      letterSpacing: isLocked ? 3 : 0,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Dòng 3: Folder
            Row(
              children: [
                Icon(
                  PhosphorIconsRegular.folder,
                  size: 16,
                  color: Colors.grey[400],
                ),
                const SizedBox(width: 6),
                Text(
                  "Note",
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    bool isSearching = _searchController.text.isNotEmpty;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearching
                ? PhosphorIconsRegular.magnifyingGlass
                : PhosphorIconsRegular.notePencil,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            isSearching ? "No results found" : "No notes yet",
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateSimple(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day) {
        return "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
      }
      return "${date.day}/${date.month}/${date.year.toString().substring(2)}";
    } catch (e) {
      return "";
    }
  }

  // --- [GIAO DIỆN NHẬP PIN ĐẸP (STYLE BANKING)] ---
  Future<String?> _showPinDialog(BuildContext context) async {
    String currentPin = "";

    return showDialog<String>(
      context: context,
      barrierDismissible: true, // Cho phép bấm ra ngoài để hủy
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              elevation: 0,
              backgroundColor: Colors.transparent, // Nền trong suốt
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(
                        0xFF2260FF,
                      ).withOpacity(0.2), // Bóng xanh
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. Icon Ổ khóa xanh
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2260FF).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        PhosphorIconsFill.lockKey,
                        size: 32,
                        color: Color(0xFF2260FF),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. Tiêu đề
                    const Text(
                      "Enter PIN Code",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Enter 6 digits to unlock note",
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // 3. Khu vực nhập PIN
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Lớp dưới: 6 chấm tròn
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
                                    ? const Color(0xFF2260FF) // Đã nhập: Xanh
                                    : const Color(0xFFE3E3E8), // Chưa nhập: Xám
                                border: isFilled
                                    ? null
                                    : Border.all(color: Colors.grey.shade300),
                              ),
                            );
                          }),
                        ),

                        // Lớp trên: TextField tàng hình
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
                              // Đủ 6 số tự động đóng và trả về kết quả
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

                    // 4. Nút Hủy
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
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
}
