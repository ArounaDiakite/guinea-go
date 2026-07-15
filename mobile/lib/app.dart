import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'features/hub/presentation/home_hub_screen.dart';
import 'features/hub/presentation/hub_scaffold.dart';
import 'features/hub/presentation/module_placeholder_screen.dart';
import 'features/hub/presentation/profile_screen.dart';
import 'features/identity/application/auth_controller.dart';
import 'features/identity/presentation/login_screen.dart';
import 'features/identity/presentation/register_screen.dart';
import 'features/splash/splash_screen.dart';
import 'features/transport/models/booking.dart';
import 'features/transport/models/booking_summary.dart';
import 'features/transport/models/trip_search_params.dart';
import 'features/transport/models/trip_seat.dart';
import 'features/transport/presentation/booking_screen.dart';
import 'features/transport/presentation/company_bus_form_screen.dart';
import 'features/transport/presentation/company_buses_screen.dart';
import 'features/transport/presentation/company_driver_form_screen.dart';
import 'features/transport/presentation/company_drivers_screen.dart';
import 'features/transport/presentation/company_home_screen.dart';
import 'features/transport/presentation/company_route_form_screen.dart';
import 'features/transport/presentation/company_routes_screen.dart';
import 'features/transport/presentation/company_schedule_form_screen.dart';
import 'features/transport/presentation/company_trip_form_screen.dart';
import 'features/transport/presentation/company_trips_screen.dart';
import 'features/transport/presentation/my_bookings_screen.dart';
import 'features/transport/presentation/payment_screen.dart';
import 'features/transport/presentation/driver_trips_screen.dart';
import 'features/transport/presentation/results_screen.dart';
import 'features/transport/presentation/search_screen.dart';
import 'features/transport/presentation/ticket_scan_screen.dart';
import 'features/transport/presentation/ticket_screen.dart';
import 'features/transport/presentation/trip_detail_screen.dart';

/// Overridable in tests to land the router somewhere other than the
/// splash screen (e.g. straight on a /hub/* deep link), without having
/// to duplicate the whole route table.
final initialLocationProvider = Provider<String>((ref) => '/');

/// Route-level auth guard for everything under /hub/*: rather than
/// relying on each screen's own API calls to fail with a 401 once
/// they're already visible, this blocks navigation into the hub shell
/// up front whenever there's no valid session - covers a deep link
/// landing straight on a hub route, not just in-app navigation coming
/// from the splash screen. Splash/login/register keep managing their
/// own flow untouched, since they're reachable without a session by
/// design.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: ref.watch(initialLocationProvider),
    redirect: (context, state) async {
      if (!state.matchedLocation.startsWith('/hub')) return null;

      final user = await ref.read(authControllerProvider.future);
      return user != null ? null : '/login';
    },
    routes: _routes,
  );
});

// A single, fixed branch list regardless of role - HubDestination.
// branchIndex (features/hub/hub_destinations.dart) is what maps a
// role's *visible* tabs back to a position here, so branches can be
// appended (like the driver one below) without renumbering existing
// ones or rebuilding GoRouter on login.
final List<RouteBase> _routes = [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => HubScaffold(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/hub/home', builder: (context, state) => const HomeHubScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/hub/transport',
              builder: (context, state) => const SearchScreen(),
              routes: [
                GoRoute(
                  path: 'results',
                  builder: (context, state) => ResultsScreen(params: state.extra as TripSearchParams),
                ),
                GoRoute(
                  path: 'bookings',
                  builder: (context, state) => const MyBookingsScreen(),
                  routes: [
                    GoRoute(
                      path: 'ticket',
                      builder: (context, state) => TicketScreen(summary: state.extra as BookingSummary),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'trips/:tripId',
                  builder: (context, state) =>
                      TripDetailScreen(tripId: state.pathParameters['tripId']!),
                  routes: [
                    GoRoute(
                      path: 'booking',
                      builder: (context, state) => BookingScreen(
                        tripId: state.pathParameters['tripId']!,
                        seat: state.extra as TripSeat,
                      ),
                      routes: [
                        GoRoute(
                          path: 'payment',
                          builder: (context, state) => PaymentScreen(booking: state.extra as Booking),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/hub/hotels',
              builder: (context, state) => const ModulePlaceholderScreen(
                title: 'Hôtels',
                icon: Icons.hotel_rounded,
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/hub/events',
              builder: (context, state) => const ModulePlaceholderScreen(
                title: 'Événements',
                icon: Icons.confirmation_number_rounded,
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/hub/commerce',
              builder: (context, state) => const ModulePlaceholderScreen(
                title: 'Commerce',
                icon: Icons.storefront_rounded,
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/hub/education',
              builder: (context, state) => const ModulePlaceholderScreen(
                title: 'Éducation',
                icon: Icons.school_rounded,
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/hub/profile', builder: (context, state) => const ProfileScreen()),
          ],
        ),
        // branchIndex 7 in hub_destinations.dart - driver-only, never
        // shown/reachable for a passenger since hubDestinationsForRole
        // never offers it to them.
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/hub/driver/trips',
              builder: (context, state) => const DriverTripsScreen(),
              routes: [
                GoRoute(
                  path: 'scan',
                  builder: (context, state) => const TicketScanScreen(),
                ),
              ],
            ),
          ],
        ),
        // branchIndex 8 in hub_destinations.dart - company_owner-only.
        // Every nested route below takes companyId via `extra` (a
        // plain String, resolved once on CompanyHomeScreen and passed
        // down at each push) rather than a path parameter, same
        // pattern as passing a Booking/TripSeat/BookingSummary
        // elsewhere in this route table.
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/hub/company',
              builder: (context, state) => const CompanyHomeScreen(),
              routes: [
                GoRoute(
                  path: 'buses',
                  builder: (context, state) => CompanyBusesScreen(companyId: state.extra as String),
                  routes: [
                    GoRoute(
                      path: 'new',
                      builder: (context, state) => CompanyBusFormScreen(companyId: state.extra as String),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'drivers',
                  builder: (context, state) => CompanyDriversScreen(companyId: state.extra as String),
                  routes: [
                    GoRoute(
                      path: 'new',
                      builder: (context, state) => CompanyDriverFormScreen(companyId: state.extra as String),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'routes',
                  builder: (context, state) => CompanyRoutesScreen(companyId: state.extra as String),
                  routes: [
                    GoRoute(
                      path: 'new',
                      builder: (context, state) => CompanyRouteFormScreen(companyId: state.extra as String),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'trips',
                  builder: (context, state) => CompanyTripsScreen(companyId: state.extra as String),
                  routes: [
                    GoRoute(
                      path: 'new-schedule',
                      builder: (context, state) => CompanyScheduleFormScreen(companyId: state.extra as String),
                    ),
                    GoRoute(
                      path: 'new-trip',
                      builder: (context, state) => CompanyTripFormScreen(companyId: state.extra as String),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ];

class GuineaGoApp extends ConsumerWidget {
  const GuineaGoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Guinea Go',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
