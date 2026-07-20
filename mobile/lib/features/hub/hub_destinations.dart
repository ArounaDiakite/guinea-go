import 'package:flutter/material.dart';

/// One entry per hub tab - shared between the adaptive nav shell (bottom
/// bar on mobile, rail on wider/web layouts) and the home screen's
/// shortcut grid, so both always stay in sync with the same routes.
///
/// `branchIndex` is the entry's position in app.dart's single, always-
/// built StatefulShellRoute branch list (which never changes shape by
/// role - only the *destinations shown for it* do) - NOT the position
/// of this entry within whichever role-filtered list is currently
/// displayed. That distinction is what lets HubScaffold show a
/// different, shorter tab set per role while still driving
/// `navigationShell.goBranch` with the branch index it actually
/// expects.
class HubDestination {
  const HubDestination({
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

const List<HubDestination> _passengerDestinations = [
  HubDestination(
    branchIndex: 0,
    path: '/hub/home',
    label: 'Accueil',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
  ),
  HubDestination(
    branchIndex: 1,
    path: '/hub/transport',
    label: 'Transport',
    icon: Icons.directions_bus_outlined,
    selectedIcon: Icons.directions_bus_rounded,
  ),
  HubDestination(
    branchIndex: 2,
    path: '/hub/hotels',
    label: 'Hôtels',
    icon: Icons.hotel_outlined,
    selectedIcon: Icons.hotel_rounded,
  ),
  HubDestination(
    branchIndex: 3,
    path: '/hub/events',
    label: 'Événements',
    icon: Icons.confirmation_number_outlined,
    selectedIcon: Icons.confirmation_number_rounded,
  ),
  HubDestination(
    branchIndex: 4,
    path: '/hub/commerce',
    label: 'Commerce',
    icon: Icons.storefront_outlined,
    selectedIcon: Icons.storefront_rounded,
  ),
  HubDestination(
    branchIndex: 5,
    path: '/hub/education',
    label: 'Éducation',
    icon: Icons.school_outlined,
    selectedIcon: Icons.school_rounded,
  ),
  HubDestination(
    branchIndex: 6,
    path: '/hub/profile',
    label: 'Profil',
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
  ),
];

const List<HubDestination> _driverDestinations = [
  HubDestination(
    branchIndex: 7,
    path: '/hub/driver/trips',
    label: 'Mes trajets',
    icon: Icons.directions_bus_outlined,
    selectedIcon: Icons.directions_bus_rounded,
  ),
  HubDestination(
    branchIndex: 6,
    path: '/hub/profile',
    label: 'Profil',
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
  ),
];

const List<HubDestination> _companyOwnerDestinations = [
  HubDestination(
    branchIndex: 8,
    path: '/hub/company',
    label: 'Ma compagnie',
    icon: Icons.apartment_outlined,
    selectedIcon: Icons.apartment_rounded,
  ),
  HubDestination(
    branchIndex: 6,
    path: '/hub/profile',
    label: 'Profil',
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
  ),
];

const List<HubDestination> _hotelOwnerDestinations = [
  HubDestination(
    branchIndex: 9,
    path: '/hub/hotel',
    label: 'Mon hôtel',
    icon: Icons.hotel_outlined,
    selectedIcon: Icons.hotel_rounded,
  ),
  HubDestination(
    branchIndex: 6,
    path: '/hub/profile',
    label: 'Profil',
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
  ),
];

const List<HubDestination> _eventOrganizerDestinations = [
  HubDestination(
    branchIndex: 10,
    path: '/hub/organizer',
    label: 'Mes événements',
    icon: Icons.event_outlined,
    selectedIcon: Icons.event_rounded,
  ),
  HubDestination(
    branchIndex: 6,
    path: '/hub/profile',
    label: 'Profil',
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
  ),
];

const List<HubDestination> _storeManagerDestinations = [
  HubDestination(
    branchIndex: 11,
    path: '/hub/store',
    label: 'Ma boutique',
    icon: Icons.storefront_outlined,
    selectedIcon: Icons.storefront_rounded,
  ),
  HubDestination(
    branchIndex: 6,
    path: '/hub/profile',
    label: 'Profil',
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
  ),
];

const List<HubDestination> _schoolAdministratorDestinations = [
  HubDestination(
    branchIndex: 12,
    path: '/hub/school',
    label: 'Mon établissement',
    icon: Icons.school_outlined,
    selectedIcon: Icons.school_rounded,
  ),
  HubDestination(
    branchIndex: 6,
    path: '/hub/profile',
    label: 'Profil',
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
  ),
];

/// Source of truth for UserRole values: backend/app/core/constants.py.
/// Only `driver`, `company_owner`, `hotel_owner`, `event_organizer`,
/// `store_manager` and `school_administrator` get a distinct nav set
/// today - every other role (including passenger) falls back to the
/// passenger tab set, since no other role has a dedicated hub
/// experience yet.
List<HubDestination> hubDestinationsForRole(String? role) {
  return switch (role) {
    'driver' => _driverDestinations,
    'company_owner' => _companyOwnerDestinations,
    'hotel_owner' => _hotelOwnerDestinations,
    'event_organizer' => _eventOrganizerDestinations,
    'store_manager' => _storeManagerDestinations,
    'school_administrator' => _schoolAdministratorDestinations,
    _ => _passengerDestinations,
  };
}

/// Where a session should land right after it's established - a fresh
/// login, a fresh registration, or a session restored from storage on
/// app relaunch. Every one of those call sites used to send every role
/// to '/hub/home' unconditionally; for a role whose own destinations
/// (above) don't include '/hub/home' at all (every owner-ish role -
/// company_owner already special-cased this correctly, driver too, but
/// hotel_owner/event_organizer/store_manager were missed), that left
/// HubScaffold's `selectedIndex` with no real match. It falls back to
/// position 0 rather than crash, which visually highlights that role's
/// first tab (and swaps in its *selected* icon) despite Home - not
/// that tab - being what's actually on screen. Routing straight to the
/// role's own landing screen avoids the mismatch entirely, rather than
/// trying to represent "nothing selected" in a widget whose API
/// requires a valid index.
String landingRouteForRole(String? role) {
  return switch (role) {
    'driver' => '/hub/driver/trips',
    'company_owner' => '/hub/company',
    'hotel_owner' => '/hub/hotel',
    'event_organizer' => '/hub/organizer',
    'store_manager' => '/hub/store',
    'school_administrator' => '/hub/school',
    _ => '/hub/home',
  };
}
