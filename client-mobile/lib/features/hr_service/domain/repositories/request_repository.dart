import 'dart:io';

import '../../data/models/request_model.dart';

abstract class RequestRepository {
  Future<bool> createRequest({
    required String userId,
    required RequestModel request,
    String? evidenceUrl, // [MỚI]
  });

  Future<List<RequestModel>> getMyRequests(
    String userId, {
    String? search,
    int? day, // <-- Thêm dòng này
    int? month,
    int? year,
  });

  // [MỚI] Hàm upload file
  Future<String> uploadFile(File file);

  Future<bool> cancelRequest(String requestId, String userId);
  Future<bool> processRequest(
    String requestId,
    String approverId,
    String status,
    String comment,
  );
}
