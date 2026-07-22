import 'package:flutter/material.dart';

/// One entry per side-rail destination. Unlike mobile/'s hub_
/// destinations.dart, there is no per-role filtering here - every
/// account that ever reaches past the login screen is already a
/// system_administrator (see AuthController.login), so every
/// destination is visible to every session.
class AdminDestination {
  const AdminDestination({
    required this.branchIndex,
    required this.path,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final int branchIndex;
  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const List<AdminDestination> adminDestinations = [
  AdminDestination(
    branchIndex: 0,
    path: '/',
    label: 'Tableau de bord',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard_rounded,
  ),
];
