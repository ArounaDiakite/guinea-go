import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../models/pending_user.dart';

class PartnersRepository {
  PartnersRepository(this._dio);

  final Dio _dio;

  Future<List<PendingUser>> getPendingUsers() async {
    final response = await _dio.get<List<dynamic>>('/admin/users/pending');
    return response.data!.map((json) => PendingUser.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<PendingUser> activateUser(String userId) async {
    final response = await _dio.patch<Map<String, dynamic>>('/admin/users/$userId/activate');
    return PendingUser.fromJson(response.data!);
  }
}

final partnersRepositoryProvider = Provider<PartnersRepository>((ref) {
  return PartnersRepository(ref.watch(apiClientProvider));
});
