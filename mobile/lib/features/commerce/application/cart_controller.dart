import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/cart_repository.dart';
import '../models/cart.dart';

final cartProvider = FutureProvider<Cart>((ref) {
  return ref.watch(cartRepositoryProvider).getCart();
});
