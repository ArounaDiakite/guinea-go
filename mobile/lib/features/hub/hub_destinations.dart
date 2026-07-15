import 'package:flutter/material.dart';

/// One entry per hub tab - shared between the adaptive nav shell (bottom
/// bar on mobile, rail on wider/web layouts) and the home screen's
/// shortcut grid, so both always stay in sync with the same 7 routes.
/// Order here MUST match the StatefulShellRoute branch order in
/// app.dart - the shell picks its selected tab by branch index.
class HubDestination {
  const HubDestination({
    required this.path,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const List<HubDestination> hubDestinations = [
  HubDestination(
    path: '/hub/home',
    label: 'Accueil',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
  ),
  HubDestination(
    path: '/hub/transport',
    label: 'Transport',
    icon: Icons.directions_bus_outlined,
    selectedIcon: Icons.directions_bus_rounded,
  ),
  HubDestination(
    path: '/hub/hotels',
    label: 'Hôtels',
    icon: Icons.hotel_outlined,
    selectedIcon: Icons.hotel_rounded,
  ),
  HubDestination(
    path: '/hub/events',
    label: 'Événements',
    icon: Icons.confirmation_number_outlined,
    selectedIcon: Icons.confirmation_number_rounded,
  ),
  HubDestination(
    path: '/hub/commerce',
    label: 'Commerce',
    icon: Icons.storefront_outlined,
    selectedIcon: Icons.storefront_rounded,
  ),
  HubDestination(
    path: '/hub/education',
    label: 'Éducation',
    icon: Icons.school_outlined,
    selectedIcon: Icons.school_rounded,
  ),
  HubDestination(
    path: '/hub/profile',
    label: 'Profil',
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
  ),
];
