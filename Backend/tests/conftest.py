import json
from pathlib import Path

import pytest

FIXTURES = Path(__file__).parent / "fixtures"


@pytest.fixture
def board_json() -> dict:
    return json.loads((FIXTURES / "board.json").read_text(encoding="utf-8"))
