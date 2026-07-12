from fastapi import HTTPException

from app.common.base_model import BaseDocument
from app.modules.companies.repository import CompanyRepository
from app.modules.transport.routes.repository import RouteRepository
from app.modules.transport.routes.schemas import RouteCreate
from app.modules.transport.stations.repository import StationRepository


class RouteService:
    def __init__(self):
        self.repository = RouteRepository()
        self.company_repository = CompanyRepository()
        self.station_repository = StationRepository()

    async def create_route(self, data: RouteCreate, user_id: str):
        existing = await self.repository.get_by_code(data.route_code)

        if existing:
            raise HTTPException(
                status_code=400,
                detail="Route code already exists.",
            )

        company = await self.company_repository.get_by_id(data.company_id)

        if not company:
            raise HTTPException(
                status_code=404,
                detail="Company not found.",
            )

        if company["owner_id"] != user_id:
            raise HTTPException(
                status_code=403,
                detail="Not allowed.",
            )

        origin = await self.station_repository.get_by_id(
            data.origin_station_id
        )

        if not origin:
            raise HTTPException(
                status_code=404,
                detail="Origin station not found.",
            )

        destination = await self.station_repository.get_by_id(
            data.destination_station_id
        )

        if not destination:
            raise HTTPException(
                status_code=404,
                detail="Destination station not found.",
            )

        if data.origin_station_id == data.destination_station_id:
            raise HTTPException(
                status_code=400,
                detail="Origin and destination stations must be different.",
            )

        route = data.model_dump()

        route["route_code"] = route["route_code"].upper()

        route.update(BaseDocument.create())

        route = await self.repository.create(route)

        return self._format(route)

    async def get_routes(
        self,
        page: int,
        limit: int,
        search: str | None,
        company_id: str | None,
    ):
        routes = await self.repository.get_all(
            page=page,
            limit=limit,
            search=search,
            company_id=company_id,
        )

        return [self._format(route) for route in routes]

    async def get_route(self, route_id: str):
        route = await self.repository.get_by_id(route_id)

        if not route:
            raise HTTPException(
                status_code=404,
                detail="Route not found.",
            )

        return self._format(route)

    async def update_route(
        self,
        route_id: str,
        data: RouteCreate,
        user_id: str,
    ):
        route = await self.repository.get_by_id(route_id)

        if not route:
            raise HTTPException(
                status_code=404,
                detail="Route not found.",
            )

        company = await self.company_repository.get_by_id(route["company_id"])

        if not company:
            raise HTTPException(
                status_code=404,
                detail="Company not found.",
            )

        if company["owner_id"] != user_id:
            raise HTTPException(
                status_code=403,
                detail="Not allowed.",
            )

        origin = await self.station_repository.get_by_id(
            data.origin_station_id
        )

        if not origin:
            raise HTTPException(
                status_code=404,
                detail="Origin station not found.",
            )

        destination = await self.station_repository.get_by_id(
            data.destination_station_id
        )

        if not destination:
            raise HTTPException(
                status_code=404,
                detail="Destination station not found.",
            )

        if data.origin_station_id == data.destination_station_id:
            raise HTTPException(
                status_code=400,
                detail="Origin and destination stations must be different.",
            )

        update_data = data.model_dump()

        update_data["route_code"] = update_data["route_code"].upper()

        update_data.update(BaseDocument.update())

        route = await self.repository.update(
            route_id,
            update_data,
        )

        return self._format(route)

    async def delete_route(
        self,
        route_id: str,
        user_id: str,
    ):
        route = await self.repository.get_by_id(route_id)

        if not route:
            raise HTTPException(
                status_code=404,
                detail="Route not found.",
            )

        company = await self.company_repository.get_by_id(route["company_id"])

        if not company:
            raise HTTPException(
                status_code=404,
                detail="Company not found.",
            )

        if company["owner_id"] != user_id:
            raise HTTPException(
                status_code=403,
                detail="Not allowed.",
            )

        deleted = await self.repository.soft_delete(
            route_id,
            {
                "is_deleted": True,
                "is_active": False,
                "deleted_at": BaseDocument.update()["updated_at"],
            },
        )

        if not deleted:
            raise HTTPException(
                status_code=404,
                detail="Route not found.",
            )

        return {
            "message": "Route deleted successfully."
        }

    def _format(self, route):
        return {
            "id": str(route["_id"]),
            "company_id": route["company_id"],
            "route_code": route["route_code"],
            "name": route["name"],
            "origin_station_id": route["origin_station_id"],
            "destination_station_id": route["destination_station_id"],
            "distance_km": route["distance_km"],
            "estimated_duration_minutes": route["estimated_duration_minutes"],
            "base_price": route["base_price"],
            "description": route.get("description"),
            "is_active": route["is_active"],
            "created_at": route.get("created_at"),
            "updated_at": route.get("updated_at"),
        }