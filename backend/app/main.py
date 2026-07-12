from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from app.modules.transport.buses.router import router as buses_router
from app.modules.transport.drivers.router import router as drivers_router
from app.modules.transport.stations.router import router as stations_router
from app.modules.transport.routes.router import router as routes_router
from app.modules.transport.schedules.router import router as schedules_router
from app.modules.transport.trips.router import router as trips_router
from app.modules.transport.bookings.router import router as bookings_router
from app.payments.router import router as payments_router
from app.payments.router import hotel_router as hotel_payments_router
from app.modules.hotels.hotels.router import router as hotels_router
from app.modules.hotels.rooms.router import router as rooms_router
from app.modules.hotels.reservations.router import router as hotel_bookings_router
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
app.include_router(payments_router)
app.include_router(hotels_router)
app.include_router(rooms_router)
app.include_router(hotel_bookings_router)
app.include_router(hotel_payments_router)
@app.get("/", tags=["Root"])
async def root():
    return {
        "message": "Bienvenue sur Guinea Go 🚀",
        "version": "1.0.0",
        "status": "running",
    }