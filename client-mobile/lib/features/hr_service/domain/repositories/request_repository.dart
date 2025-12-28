import 'dart:io';

import '../../data/models/request_model.dart';

abstract class RequestRepository {
  Future<bool> createRequest({
    required String userId,
    required RequestModel request,
    String? evidenceUrl, // [MỚI]
  });

  Future<List<RequestModel>> getMyRequests(String userId);

  // [MỚI] Hàm upload file
  Future<String> uploadFile(File file);

  Future<bool> cancelRequest(String requestId, String userId);
}
