# Guinea Go - Database Schema

This document defines the MongoDB database structure for Guinea Go, a multi-country booking platform for transport, hotels, events, payments, and tickets.
# Guinea Go - Database Schema

## Version

1.0.0

## Project Vision

Guinea Go is a multi-country booking platform for:

* Transport (Bus, Taxi, Train, Boat)
* Hotels
* Events
* Payments
* QR Tickets

The system is designed to support multiple countries without changing the source code.

---

# General Principles

Every collection that belongs to a country must contain:

```json
country_code
```

Example:

```
GN
SN
CI
ML
GH
SL
LR
```

Never store the full country name inside business collections.

---

# Collections

## countries

Stores all supported countries.

Fields

* id
* code
* name
* currency
* timezone
* languages
* payment_methods
* is_active

---

## cities

Stores cities.

Fields

* id
* country_code
* name
* state_or_region
* latitude
* longitude
* is_active

---

## users

Stores all users.

Fields

* id
* first_name
* last_name
* email
* phone
* password
* country_code
* city
* preferred_language
* role
* profile_picture
* is_verified
* is_active
* created_at
* updated_at
* last_login

Roles

* customer
* company
* admin
* super_admin

---

## companies

Transport companies, hotels and event organizers.

Fields

* id
* name
* company_type
* owner_user_id
* country_code
* city
* email
* phone
* address
* logo
* description
* verification_status
* is_active
* created_at

Company Types

* transport
* hotel
* event

---

## transport_trips

Stores bus and taxi trips.

Fields

* id
* company_id
* country_code
* transport_type
* departure_city
* arrival_city
* departure_time
* arrival_time
* price
* currency
* total_seats
* available_seats
* status

Transport Types

* bus
* taxi

Status

* scheduled
* departed
* completed
* cancelled

---

## hotels

Stores hotels.

Fields

* id
* company_id
* country_code
* city
* name
* address
* description
* images
* amenities
* star_rating
* average_rating
* is_active

---

## rooms

Stores hotel rooms.

Fields

* id
* hotel_id
* room_number
* room_type
* capacity
* price_per_night
* currency
* available
* images

---

## events

Stores events.

Fields

* id
* organizer_company_id
* country_code
* city
* category
* title
* description
* venue
* start_date
* end_date
* ticket_price
* currency
* total_tickets
* available_tickets
* banner_image
* is_active

Categories

* concert
* conference
* festival
* sport

---

## bookings

Central reservation collection.

Fields

* id
* booking_type
* item_id
* user_id
* country_code
* quantity
* total_amount
* currency
* payment_status
* booking_status
* created_at

Booking Types

* transport
* hotel
* event

Payment Status

* pending
* paid
* failed
* refunded

Booking Status

* pending
* confirmed
* cancelled
* completed

---

## payments

Stores all payment transactions.

Fields

* id
* booking_id
* user_id
* country_code
* provider
* amount
* currency
* transaction_reference
* status
* created_at

Providers

* orange_money
* mtn_money
* stripe
* wave
* paypal

---

## tickets

Stores QR tickets.

Fields

* id
* booking_id
* user_id
* ticket_code
* qr_code
* status
* scanned_at
* created_at

Status

* valid
* used
* expired
* cancelled

---

## reviews

Stores user reviews.

Fields

* id
* user_id
* item_type
* item_id
* rating
* comment
* created_at

---

## favorites

Stores user favorites.

Fields

* id
* user_id
* item_type
* item_id
* created_at

---

## notifications

Stores notifications.

Fields

* id
* user_id
* title
* message
* notification_type
* is_read
* created_at

Notification Types

* email
* sms
* push
* whatsapp

---

# Future Modules

Version 2

* Flight Booking
* Boat Booking
* Car Rental

Version 3

* Food Delivery
* Restaurant Reservation
* Marketplace

Version 4

* Healthcare
* Real Estate
* Tourism

---

# Database Design Principles

* Multi-country architecture
* Multi-language support
* Multi-currency support
* Scalable
* Cloud-ready
* Mobile-first
* Secure by design
* Production-ready
