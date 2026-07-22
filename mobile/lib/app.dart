import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'features/events/models/event_booking_selection.dart';
import 'features/events/models/event_booking_summary.dart';
import 'features/events/models/event_search_params.dart';
import 'features/events/presentation/event_booking_screen.dart';
import 'features/events/presentation/event_bookings_received_screen.dart';
import 'features/events/presentation/event_detail_screen.dart';
import 'features/events/presentation/event_form_screen.dart';
import 'features/events/presentation/event_manage_screen.dart';
import 'features/events/presentation/event_organizer_home_screen.dart';
import 'features/events/presentation/event_results_screen.dart';
import 'features/events/presentation/event_search_screen.dart';
import 'features/events/presentation/event_ticket_scan_screen.dart';
import 'features/events/presentation/event_ticket_screen.dart';
import 'features/events/presentation/event_ticket_types_screen.dart';
import 'features/events/presentation/my_event_bookings_screen.dart';
import 'features/events/presentation/ticket_type_form_screen.dart';
import 'features/hotels/models/hotel_booking_selection.dart';
import 'features/hotels/models/hotel_search_params.dart';
import 'features/hotels/models/hotel_stay.dart';
import 'features/hotels/presentation/hotel_booking_screen.dart';
import 'features/hotels/presentation/hotel_bookings_received_screen.dart';
import 'features/hotels/presentation/hotel_detail_screen.dart';
import 'features/hotels/presentation/hotel_home_screen.dart';
import 'features/hotels/presentation/hotel_results_screen.dart';
import 'features/hotels/presentation/hotel_room_form_screen.dart';
import 'features/hotels/presentation/hotel_rooms_screen.dart';
import 'features/hotels/presentation/hotel_search_screen.dart';
import 'features/hotels/presentation/my_hotel_bookings_screen.dart';
import 'features/commerce/models/order_summary.dart';
import 'features/commerce/presentation/cart_screen.dart';
import 'features/commerce/presentation/category_form_screen.dart';
import 'features/commerce/presentation/category_list_screen.dart';
import 'features/commerce/presentation/checkout_screen.dart';
import 'features/commerce/presentation/my_orders_screen.dart';
import 'features/commerce/presentation/order_detail_screen.dart';
import 'features/commerce/presentation/product_catalog_screen.dart';
import 'features/commerce/presentation/product_detail_screen.dart';
import 'features/commerce/presentation/product_form_screen.dart';
import 'features/commerce/presentation/store_form_screen.dart';
import 'features/commerce/presentation/store_manage_screen.dart';
import 'features/commerce/presentation/store_manager_home_screen.dart';
import 'features/commerce/presentation/store_orders_received_screen.dart';
import 'features/commerce/presentation/store_product_list_screen.dart';
import 'features/commerce/presentation/store_screen.dart';
import 'features/education/models/student_fee.dart';
import 'features/education/presentation/academic_unit_form_screen.dart';
import 'features/education/presentation/academic_unit_list_screen.dart';
import 'features/education/presentation/academic_unit_schedule_screen.dart';
import 'features/education/presentation/attendance_entry_screen.dart';
import 'features/education/presentation/fee_apply_screen.dart';
import 'features/education/presentation/fee_payment_screen.dart';
import 'features/education/presentation/fee_schedule_form_screen.dart';
import 'features/education/presentation/fee_schedule_list_screen.dart';
import 'features/education/presentation/grade_form_screen.dart';
import 'features/education/presentation/grade_list_screen.dart';
import 'features/education/presentation/institution_home_screen.dart';
import 'features/education/presentation/report_card_screen.dart';
import 'features/education/presentation/student_attendance_screen.dart';
import 'features/education/presentation/student_fees_screen.dart';
import 'features/education/presentation/student_fees_view_screen.dart';
import 'features/education/presentation/student_form_screen.dart';
import 'features/education/presentation/student_grades_screen.dart';
import 'features/education/presentation/student_home_screen.dart';
import 'features/education/presentation/student_list_screen.dart';
import 'features/education/presentation/student_schedule_screen.dart';
import 'features/education/presentation/subject_form_screen.dart';
import 'features/education/presentation/subject_list_screen.dart';
import 'features/education/presentation/teacher_class_screen.dart';
import 'features/education/presentation/teacher_form_screen.dart';
import 'features/education/presentation/teacher_home_screen.dart';
import 'features/education/presentation/teacher_list_screen.dart';
import 'features/education/presentation/timeslot_form_screen.dart';
import 'features/hub/presentation/home_hub_screen.dart';
import 'features/hub/presentation/hub_scaffold.dart';
import 'features/hub/presentation/module_placeholder_screen.dart';
import 'features/hub/presentation/profile_screen.dart';
import 'features/identity/application/auth_controller.dart';
import 'features/identity/presentation/login_screen.dart';
import 'features/identity/presentation/register_school_member_screen.dart';
import 'features/identity/presentation/register_screen.dart';
import 'features/payments/models/payment.dart';
import 'features/payments/presentation/payment_screen.dart';
import 'features/splash/splash_screen.dart';
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
    GoRoute(
      path: '/register-school-member',
      builder: (context, state) => const RegisterSchoolMemberScreen(),
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
                          builder: (context, state) => PaymentScreen(request: state.extra as PaymentRequest),
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
              builder: (context, state) => const HotelSearchScreen(),
              routes: [
                GoRoute(
                  path: 'results',
                  builder: (context, state) => HotelResultsScreen(params: state.extra as HotelSearchParams),
                ),
                GoRoute(
                  path: 'bookings',
                  builder: (context, state) => const MyHotelBookingsScreen(),
                ),
                GoRoute(
                  path: ':hotelId',
                  builder: (context, state) => HotelDetailScreen(
                    hotelId: state.pathParameters['hotelId']!,
                    stay: state.extra as HotelStay,
                  ),
                  routes: [
                    GoRoute(
                      path: 'booking',
                      builder: (context, state) =>
                          HotelBookingScreen(selection: state.extra as HotelBookingSelection),
                      routes: [
                        GoRoute(
                          path: 'payment',
                          builder: (context, state) => PaymentScreen(request: state.extra as PaymentRequest),
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
              path: '/hub/events',
              builder: (context, state) => const EventSearchScreen(),
              routes: [
                GoRoute(
                  path: 'results',
                  builder: (context, state) => EventResultsScreen(params: state.extra as EventSearchParams),
                ),
                GoRoute(
                  path: 'bookings',
                  builder: (context, state) => const MyEventBookingsScreen(),
                  routes: [
                    GoRoute(
                      path: 'ticket',
                      builder: (context, state) => EventTicketScreen(summary: state.extra as EventBookingSummary),
                    ),
                  ],
                ),
                GoRoute(
                  path: ':eventId',
                  builder: (context, state) => EventDetailScreen(eventId: state.pathParameters['eventId']!),
                  routes: [
                    GoRoute(
                      path: 'booking',
                      builder: (context, state) =>
                          EventBookingScreen(selection: state.extra as EventBookingSelection),
                      routes: [
                        GoRoute(
                          path: 'payment',
                          builder: (context, state) => PaymentScreen(request: state.extra as PaymentRequest),
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
              path: '/hub/commerce',
              builder: (context, state) => const ProductCatalogScreen(),
              routes: [
                GoRoute(
                  path: 'products/:productId',
                  builder: (context, state) =>
                      ProductDetailScreen(productId: state.pathParameters['productId']!),
                ),
                GoRoute(
                  path: 'stores/:storeId',
                  builder: (context, state) => StoreScreen(storeId: state.pathParameters['storeId']!),
                ),
                GoRoute(
                  path: 'cart',
                  builder: (context, state) => const CartScreen(),
                ),
                GoRoute(
                  path: 'checkout',
                  builder: (context, state) => const CheckoutScreen(),
                ),
                GoRoute(
                  path: 'orders',
                  builder: (context, state) => const MyOrdersScreen(),
                  routes: [
                    GoRoute(
                      path: ':orderId',
                      builder: (context, state) => OrderDetailScreen(summary: state.extra as OrderSummary),
                      routes: [
                        GoRoute(
                          path: 'payment',
                          builder: (context, state) => PaymentScreen(request: state.extra as PaymentRequest),
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
        // branchIndex 9 in hub_destinations.dart - hotel_owner-only.
        // Same extra-carries-the-id pattern as /hub/company above.
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/hub/hotel',
              builder: (context, state) => const HotelHomeScreen(),
              routes: [
                GoRoute(
                  path: 'rooms',
                  builder: (context, state) => HotelRoomsScreen(hotelId: state.extra as String),
                  routes: [
                    GoRoute(
                      path: 'new',
                      builder: (context, state) => HotelRoomFormScreen(hotelId: state.extra as String),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'bookings',
                  builder: (context, state) => HotelBookingsReceivedScreen(hotelId: state.extra as String),
                ),
              ],
            ),
          ],
        ),
        // branchIndex 10 in hub_destinations.dart - event_organizer-only.
        // Unlike company_owner/hotel_owner (one owned entity assumed),
        // an organizer manages several events, so eventId travels as a
        // path parameter here (like hotelId does on the passenger-side
        // hotel detail route) rather than via `extra`.
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/hub/organizer',
              builder: (context, state) => const EventOrganizerHomeScreen(),
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (context, state) => const EventFormScreen(),
                ),
                // Not scoped to one event - an organizer's tickets all
                // share one code namespace, and validate_ticket checks
                // the scanned ticket's own event against the caller,
                // same as the driver-side scan screen isn't nested
                // under one specific trip either.
                GoRoute(
                  path: 'scan',
                  builder: (context, state) => const EventTicketScanScreen(),
                ),
                GoRoute(
                  path: ':eventId',
                  builder: (context, state) => EventManageScreen(eventId: state.pathParameters['eventId']!),
                  routes: [
                    GoRoute(
                      path: 'ticket-types',
                      builder: (context, state) =>
                          EventTicketTypesScreen(eventId: state.pathParameters['eventId']!),
                      routes: [
                        GoRoute(
                          path: 'new',
                          builder: (context, state) =>
                              TicketTypeFormScreen(eventId: state.pathParameters['eventId']!),
                        ),
                      ],
                    ),
                    GoRoute(
                      path: 'bookings',
                      builder: (context, state) =>
                          EventBookingsReceivedScreen(eventId: state.pathParameters['eventId']!),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        // branchIndex 11 in hub_destinations.dart - store_manager-only.
        // Same "several owned entities, id travels as a path parameter"
        // shape as /hub/organizer above - a store_manager may run more
        // than one store (see StoreService.create_store).
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/hub/store',
              builder: (context, state) => const StoreManagerHomeScreen(),
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (context, state) => const StoreFormScreen(),
                ),
                // Not scoped to one store - categories are a shared
                // taxonomy across every store (see categories/service.py),
                // not store-owned data.
                GoRoute(
                  path: 'categories',
                  builder: (context, state) => const CategoryListScreen(),
                  routes: [
                    GoRoute(
                      path: 'new',
                      builder: (context, state) => const CategoryFormScreen(),
                    ),
                  ],
                ),
                GoRoute(
                  path: ':storeId',
                  builder: (context, state) => StoreManageScreen(storeId: state.pathParameters['storeId']!),
                  routes: [
                    GoRoute(
                      path: 'products',
                      builder: (context, state) =>
                          StoreProductListScreen(storeId: state.pathParameters['storeId']!),
                      routes: [
                        GoRoute(
                          path: 'new',
                          builder: (context, state) =>
                              ProductFormScreen(storeId: state.pathParameters['storeId']!),
                        ),
                        GoRoute(
                          path: ':productId/edit',
                          builder: (context, state) => ProductFormScreen(
                            storeId: state.pathParameters['storeId']!,
                            productId: state.pathParameters['productId']!,
                          ),
                        ),
                      ],
                    ),
                    GoRoute(
                      path: 'orders',
                      builder: (context, state) =>
                          StoreOrdersReceivedScreen(storeId: state.pathParameters['storeId']!),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        // branchIndex 12 in hub_destinations.dart - school_administrator-
        // only. One institution per administrator (InstitutionService
        // enforces it), same "single owned entity, id travels via extra"
        // shape as /hub/hotel above - not a :institutionId path param
        // the way /hub/store's several-owned-stores does.
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/hub/school',
              builder: (context, state) => const InstitutionHomeScreen(),
              routes: [
                GoRoute(
                  path: 'academic-units',
                  builder: (context, state) =>
                      AcademicUnitListScreen(institutionId: state.extra as String),
                  routes: [
                    GoRoute(
                      path: 'new',
                      builder: (context, state) =>
                          AcademicUnitFormScreen(institutionId: state.extra as String),
                    ),
                    GoRoute(
                      path: ':academicUnitId/edit',
                      builder: (context, state) => AcademicUnitFormScreen(
                        institutionId: state.extra as String,
                        academicUnitId: state.pathParameters['academicUnitId']!,
                      ),
                    ),
                    GoRoute(
                      path: ':academicUnitId/schedule',
                      builder: (context, state) => AcademicUnitScheduleScreen(
                        institutionId: state.extra as String,
                        academicUnitId: state.pathParameters['academicUnitId']!,
                      ),
                      routes: [
                        GoRoute(
                          path: 'timeslots/new',
                          builder: (context, state) => TimeSlotFormScreen(
                            institutionId: state.extra as String,
                            academicUnitId: state.pathParameters['academicUnitId']!,
                          ),
                        ),
                        GoRoute(
                          path: 'timeslots/:timeSlotId/edit',
                          builder: (context, state) => TimeSlotFormScreen(
                            institutionId: state.extra as String,
                            academicUnitId: state.pathParameters['academicUnitId']!,
                            timeSlotId: state.pathParameters['timeSlotId']!,
                          ),
                        ),
                        GoRoute(
                          path: 'timeslots/:timeSlotId/attendance',
                          builder: (context, state) => AttendanceEntryScreen(
                            institutionId: state.extra as String,
                            academicUnitId: state.pathParameters['academicUnitId']!,
                            timeSlotId: state.pathParameters['timeSlotId']!,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                GoRoute(
                  path: 'teachers',
                  builder: (context, state) => TeacherListScreen(institutionId: state.extra as String),
                  routes: [
                    GoRoute(
                      path: 'new',
                      builder: (context, state) => TeacherFormScreen(institutionId: state.extra as String),
                    ),
                    GoRoute(
                      path: ':teacherId/edit',
                      builder: (context, state) => TeacherFormScreen(
                        institutionId: state.extra as String,
                        teacherId: state.pathParameters['teacherId']!,
                      ),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'students',
                  builder: (context, state) => StudentListScreen(institutionId: state.extra as String),
                  routes: [
                    GoRoute(
                      path: 'new',
                      builder: (context, state) => StudentFormScreen(institutionId: state.extra as String),
                    ),
                    GoRoute(
                      path: ':studentId/edit',
                      builder: (context, state) => StudentFormScreen(
                        institutionId: state.extra as String,
                        studentId: state.pathParameters['studentId']!,
                      ),
                    ),
                    GoRoute(
                      path: ':studentId/grades',
                      builder: (context, state) => GradeListScreen(
                        institutionId: state.extra as String,
                        studentId: state.pathParameters['studentId']!,
                      ),
                      routes: [
                        // No :gradeId path param - the backend has no
                        // GET-single-grade endpoint, so there's nothing
                        // to fetch by id. GradeFormArgs (carried via
                        // extra) is the only source of truth for both
                        // create and edit.
                        GoRoute(
                          path: 'form',
                          builder: (context, state) => GradeFormScreen(
                            studentId: state.pathParameters['studentId']!,
                            args: state.extra as GradeFormArgs,
                          ),
                        ),
                      ],
                    ),
                    GoRoute(
                      path: ':studentId/report-card',
                      builder: (context, state) =>
                          ReportCardScreen(studentId: state.pathParameters['studentId']!),
                    ),
                    GoRoute(
                      path: ':studentId/fees',
                      builder: (context, state) => StudentFeesScreen(
                        institutionId: state.extra as String,
                        studentId: state.pathParameters['studentId']!,
                      ),
                      routes: [
                        GoRoute(
                          path: 'apply',
                          builder: (context, state) => FeeApplyScreen(
                            institutionId: state.extra as String,
                            studentId: state.pathParameters['studentId']!,
                          ),
                        ),
                        // No :studentFeeId path param - same reasoning
                        // as grades/form: no GET-single-StudentFee
                        // endpoint, so the full StudentFee travels via
                        // extra instead.
                        GoRoute(
                          path: 'pay',
                          builder: (context, state) => FeePaymentScreen(
                            studentId: state.pathParameters['studentId']!,
                            studentFee: state.extra as StudentFee,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                GoRoute(
                  path: 'fee-schedules',
                  builder: (context, state) => FeeScheduleListScreen(institutionId: state.extra as String),
                  routes: [
                    GoRoute(
                      path: 'new',
                      builder: (context, state) => FeeScheduleFormScreen(institutionId: state.extra as String),
                    ),
                    GoRoute(
                      path: ':feeScheduleId/edit',
                      builder: (context, state) => FeeScheduleFormScreen(
                        institutionId: state.extra as String,
                        feeScheduleId: state.pathParameters['feeScheduleId']!,
                      ),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'subjects',
                  builder: (context, state) => SubjectListScreen(institutionId: state.extra as String),
                  routes: [
                    GoRoute(
                      path: 'new',
                      builder: (context, state) => SubjectFormScreen(institutionId: state.extra as String),
                    ),
                    GoRoute(
                      path: ':subjectId/edit',
                      builder: (context, state) => SubjectFormScreen(
                        institutionId: state.extra as String,
                        subjectId: state.pathParameters['subjectId']!,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        // branchIndex 13 in hub_destinations.dart - teacher-only. A
        // teacher's own classes come from GET /teachers/me's
        // academic_unit_ids (TeacherHomeScreen), not a path param -
        // same "resolve the caller's own scope first" shape as /hub/
        // school above, just via the teacher's own profile instead of
        // an owned Institution.
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/hub/teacher',
              builder: (context, state) => const TeacherHomeScreen(),
              routes: [
                GoRoute(
                  path: 'classes/:academicUnitId',
                  builder: (context, state) {
                    final extra = state.extra as Map<String, String>;
                    return TeacherClassScreen(
                      institutionId: extra['institutionId']!,
                      teacherId: extra['teacherId']!,
                      academicUnitId: state.pathParameters['academicUnitId']!,
                    );
                  },
                  routes: [
                    GoRoute(
                      path: 'timeslots/:timeSlotId/attendance',
                      builder: (context, state) => AttendanceEntryScreen(
                        institutionId: state.extra as String,
                        academicUnitId: state.pathParameters['academicUnitId']!,
                        timeSlotId: state.pathParameters['timeSlotId']!,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        // branchIndex 14 in hub_destinations.dart - student-only. Every
        // sub-route resolves the logged-in student's own id/academic
        // unit up front (StudentHomeScreen, via GET /students/me) and
        // passes it on via extra/path param - nothing here is browsable
        // by id the way the school_administrator's screens are, since
        // a student only ever has permission to see their own records.
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/hub/student',
              builder: (context, state) => const StudentHomeScreen(),
              routes: [
                GoRoute(
                  path: 'schedule',
                  builder: (context, state) => StudentScheduleScreen(academicUnitId: state.extra as String),
                ),
                GoRoute(
                  path: 'grades',
                  builder: (context, state) => StudentGradesScreen(studentId: state.extra as String),
                ),
                GoRoute(
                  path: 'report-card',
                  builder: (context, state) => ReportCardScreen(studentId: state.extra as String),
                ),
                GoRoute(
                  path: 'attendance',
                  builder: (context, state) => StudentAttendanceScreen(studentId: state.extra as String),
                ),
                GoRoute(
                  path: 'fees',
                  builder: (context, state) => StudentFeesViewScreen(studentId: state.extra as String),
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
