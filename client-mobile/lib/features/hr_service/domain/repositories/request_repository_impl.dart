import 'dart:io';

import '../../data/datasources/request_remote_data_source.dart';
import '../../data/models/request_model.dart';
import 'request_repository.dart';

class RequestRepositoryImpl implements RequestRepository {
  final RequestRemoteDataSource remoteDataSource;

  RequestRepositoryImpl({required this.remoteDataSource});

  @override
  Future<bool> createRequest({
    required String userId,
    required RequestModel request,
    String? evidenceUrl, // [MỚI]
  }) async {
    // Gọi hàm createRequest bên DataSource
    // Lưu ý: DataSource hiện tại đang nhận từng tham số rời rạc,
    // ta nên update DataSource để nhận Model hoặc bóc tách ở đây.
    // Dưới đây là cách bóc tách để khớp với DataSource cũ:

    return await remoteDataSource.createRequest(
      userId: userId,
      type: request.type.name,
      startTime: request.startTime.toIso8601String(),
      endTime: request.endTime.toIso8601String(),
      reason: request.reason,
      durationVal: request.durationVal,
      durationUnit: request.durationUnit,
      evidenceUrl: evidenceUrl, // Truyền xuống
    );
  }

  // [CẬP NHẬT]
  @override
  Future<List<RequestModel>> getMyRequests(
    String userId, {
    String? search,
    int? day, // <-- Thêm dòng này
    int? month,
    int? year,
  }) async {
    // Truyền tiếp tham số xuống Remote Data Source
    return await remoteDataSource.getMyRequests(
      userId,
      search: search,
      day: day, // <--- BẠN ĐANG THIẾU DÒNG NÀY (Thêm vào đây)
      month: month,
      year: year,
    );
  }

  // [MỚI] Implement hàm upload
  @override
  Future<String> uploadFile(File file) async {
    return await remoteDataSource.uploadFile(file);
  }

  @override
  Future<bool> cancelRequest(String requestId, String userId) async {
    return await remoteDataSource.cancelRequest(requestId, userId);
  }

  @override
  Future<bool> processRequest(
    String requestId,
    String approverId,
    String status,
    String comment,
  ) async {
    return await remoteDataSource.processRequest(
      requestId,
      approverId,
      status,
      comment,
    );
  }
}
