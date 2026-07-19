import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/cart_controller.dart';

/// AppBar action for the catalog screen - same "quick access to my
/// stuff" slot Transport/Hotels/Events each put on their own main
/// screen (e.g. EventSearchScreen's "Mes billets" icon), just with a
/// item-count badge since a cart, unlike a booking list, has a size
/// worth showing at a glance.
class CartBadgeAction extends ConsumerWidget {
  const CartBadgeAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartAsync = ref.watch(cartProvider);
    final itemCount = cartAsync.asData?.value.itemCount ?? 0;

    return IconButton(
      tooltip: 'Panier',
      onPressed: () => context.push('/hub/commerce/cart'),
      icon: Badge(
        label: Text('$itemCount', key: const ValueKey('cart-badge-count')),
        isLabelVisible: itemCount > 0,
        child: const Icon(Icons.shopping_cart_outlined),
      ),
    );
  }
}
