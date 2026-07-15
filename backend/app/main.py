from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.core.config import settings
from app.modules.transport.buses.router import router as buses_router
from app.modules.transport.drivers.router import router as drivers_router
from app.modules.transport.stations.router import router as stations_router
from app.modules.transport.routes.router import router as routes_router
from app.modules.transport.schedules.router import router as schedules_router
from app.modules.transport.trips.router import router as trips_router
from app.modules.transport.bookings.router import router as bookings_router
from app.modules.transport.tickets.router import router as tickets_router
from app.payments.router import router as payments_router
from app.payments.router import hotel_router as hotel_payments_router
from app.payments.router import event_router as event_payments_router
from app.payments.router import order_router as order_payments_router
from app.payments.router import school_fee_router as school_fee_payments_router
from app.modules.hotels.hotels.router import router as hotels_router
from app.modules.hotels.rooms.router import router as rooms_router
from app.modules.hotels.reservations.router import router as hotel_bookings_router
from app.modules.events.events.router import router as events_router
from app.modules.events.ticket_types.router import router as ticket_types_router
from app.modules.events.bookings.router import router as event_bookings_router
from app.modules.commerce.categories.router import router as categories_router
from app.modules.commerce.stores.router import router as stores_router
from app.modules.commerce.products.router import router as products_router
from app.modules.commerce.cart.router import router as cart_router
from app.modules.commerce.orders.router import router as orders_router
from app.modules.education.institutions.router import router as institutions_router
from app.modules.education.academic_units.router import router as academic_units_router
from app.modules.education.teachers.router import router as edu_teachers_router
from app.modules.education.students.router import router as edu_students_router
from app.modules.education.subjects.router import router as subjects_router
from app.modules.education.timeslots.router import router as timeslots_router
from app.modules.education.fees.router import router as fee_schedules_router
from app.reviews.router import router as reviews_router
from app.notifications.router import router as notifications_router
from app.identity.auth.router import router as auth_router
from app.shared.cities.router import router as cities_router
from app.modules.companies.router import router as companies_router
from app.shared.countries.router import router as countries_router
from app.shared.currencies.router import router as currencies_router
from app.database.startup import init_database
from app.identity.users.router import router as users_router
from app.admin.router import router as admin_router

app = FastAPI(
    title="Guinea Go API",
    version="1.0.0",
    description="Transport • Hotels • Events",
)

_cors_origins = (
    ["*"] if settings.CORS_ORIGINS == "*" else settings.CORS_ORIGINS.split(",")
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=_cors_origins,
    allow_credentials=settings.CORS_ORIGINS != "*",
    allow_methods=["*"],
    allow_headers=["*"],
)

app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")


@app.on_event("startup")
async def startup_event():
    await init_database()


app.include_router(auth_router)
app.include_router(admin_router)
app.include_router(users_router)
app.include_router(countries_router)
app.include_router(cities_router)
app.include_router(currencies_router)
app.include_router(companies_router)
app.include_router(buses_router)
app.include_router(drivers_router)
app.include_router(stations_router)
app.include_router(routes_router)
app.include_router(schedules_router)
app.include_router(trips_router)
app.include_router(bookings_router)
app.include_router(tickets_router)
app.include_router(payments_router)
app.include_router(hotels_router)
app.include_router(rooms_router)
app.include_router(hotel_bookings_router)
app.include_router(hotel_payments_router)
app.include_router(events_router)
app.include_router(ticket_types_router)
app.include_router(event_bookings_router)
app.include_router(event_payments_router)
app.include_router(categories_router)
app.include_router(stores_router)
app.include_router(products_router)
app.include_router(cart_router)
app.include_router(orders_router)
app.include_router(order_payments_router)
app.include_router(institutions_router)
app.include_router(academic_units_router)
app.include_router(edu_teachers_router)
app.include_router(edu_students_router)
app.include_router(subjects_router)
app.include_router(timeslots_router)
app.include_router(fee_schedules_router)
app.include_router(school_fee_payments_router)
app.include_router(reviews_router)
app.include_router(notifications_router)


@app.get("/", tags=["Root"])
async def root():
    return {
        "message": "Bienvenue sur Guinea Go 🚀",
        "version": "1.0.0",
        "status": "running",
    }