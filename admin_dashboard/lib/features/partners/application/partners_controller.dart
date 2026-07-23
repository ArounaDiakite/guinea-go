import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/partners_repository.dart';
import '../models/pending_user.dart';

final pendingUsersProvider = FutureProvider.autoDispose<List<PendingUser>>((ref) {
  return ref.watch(partnersRepositoryProvider).getPendingUsers();
});
