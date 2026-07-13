from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


class AcademicUnitCreate(BaseModel):
    institution_id: str
    # "classe" for a school (e.g. "CM2 A", "Terminale S2") or
    # "département/filière" for a university (e.g. "Génie Civil").
    name: str = Field(..., min_length=1, max_length=150)
    # Free text on purpose: a primary school's CE1/CM2, a lycée's
    # Seconde/Terminale, and a university's L1/M2 don't share a common
    # enum without being awkwardly overloaded.
    level: str = Field(..., min_length=1, max_length=100)


class AcademicUnitResponse(BaseModel):
    id: str
    institution_id: str
    name: str
    level: str
    is_active: bool
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
