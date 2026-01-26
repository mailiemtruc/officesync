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
    String? evidenceUrl,
  }) async {
    return await remoteDataSource.createRequest(
      userId: userId,
      type: request.type.name,
      startTime: request.startTime.toIso8601String(),
      endTime: request.endTime.toIso8601String(),
      reason: request.reason,
      durationVal: request.durationVal,
      durationUnit: request.durationUnit,
      evidenceUrl: evidenceUrl,
    );
  }

  @override
  Future<List<RequestModel>> getMyRequests(
    String userId, {
    String? search,
    int? day,
    int? month,
    int? year,
  }) async {
    return await remoteDataSource.getMyRequests(
      userId,
      search: search,
      day: day,
      month: month,
      year: year,
    );
  }

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
