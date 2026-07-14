from fastapi import HTTPException

from app.common.base_model import BaseDocument
from app.modules.transport.stations.repository import StationRepository
from app.modules.transport.stations.schemas import StationCreate
from app.shared.cities.repository import CityRepository


class StationService:
    def __init__(self):
        self.repository = StationRepository()
        self.city_repository = CityRepository()

    async def _validate_city(self, city_id: str):
        city = await self.city_repository.get_by_id(city_id)

        if not city:
            raise HTTPException(status_code=400, detail="City not found.")

    async def create_station(self, data: StationCreate):
        existing = await self.repository.get_by_code(data.station_code)

        if existing:
            raise HTTPException(
                status_code=400,
                detail="Station code already exists.",
            )

        await self._validate_city(data.city_id)

        station = data.model_dump()
        station["station_type"] = station["station_type"].value
        station["station_code"] = station["station_code"].upper()

        station.update(BaseDocument.create())

        station = await self.repository.create(station)
        return self._format(station)

    async def get_stations(
        self,
        page: int,
        limit: int,
        search: str | None,
        city_id: str | None,
        station_type: str | None,
    ):
        stations = await self.repository.get_all(
            page=page,
            limit=limit,
            search=search,
            city_id=city_id,
            station_type=station_type,
        )

        return [self._format(station) for station in stations]

    async def get_station(self, station_id: str):
        station = await self.repository.get_by_id(station_id)

        if not station:
            raise HTTPException(status_code=404, detail="Station not found.")

        return self._format(station)

    async def update_station(self, station_id: str, data: StationCreate):
        station = await self.repository.get_by_id(station_id)

        if not station:
            raise HTTPException(status_code=404, detail="Station not found.")

        await self._validate_city(data.city_id)

        update_data = data.model_dump()
        update_data["station_type"] = update_data["station_type"].value
        update_data["station_code"] = update_data["station_code"].upper()
        update_data.update(BaseDocument.update())

        station = await self.repository.update(station_id, update_data)
        return self._format(station)

    async def delete_station(self, station_id: str):
        station = await self.repository.get_by_id(station_id)

        if not station:
            raise HTTPException(status_code=404, detail="Station not found.")

        deleted = await self.repository.soft_delete(
            station_id,
            {
                "is_deleted": True,
                "is_active": False,
                "deleted_at": BaseDocument.update()["updated_at"],
            },
        )

        if not deleted:
            raise HTTPException(status_code=404, detail="Station not found.")

        return {"message": "Station deleted successfully."}

    def _format(self, station):
        return {
            "id": str(station["_id"]),
            "name": station["name"],
            "station_code": station["station_code"],
            "station_type": station["station_type"],
            "city_id": station["city_id"],
            "address": station["address"],
            "latitude": station.get("latitude"),
            "longitude": station.get("longitude"),
            "contact_phone": station.get("contact_phone"),
            "contact_email": station.get("contact_email"),
            "description": station.get("description"),
            "operating_hours": station.get("operating_hours"),
            "is_active": station["is_active"],
            "created_at": station.get("created_at"),
            "updated_at": station.get("updated_at"),
        }