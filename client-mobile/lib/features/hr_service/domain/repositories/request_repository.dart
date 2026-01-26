import 'dart:io';

import '../../data/models/request_model.dart';

abstract class RequestRepository {
  Future<bool> createRequest({
    required String userId,
    required RequestModel request,
    String? evidenceUrl,
  });

  Future<List<RequestModel>> getMyRequests(
    String userId, {
    String? search,
    int? day,
    int? month,
    int? year,
  });

  Future<String> uploadFile(File file);

  Future<bool> cancelRequest(String requestId, String userId);
  Future<bool> processRequest(
    String requestId,
    String approverId,
    String status,
    String comment,
  );
}
