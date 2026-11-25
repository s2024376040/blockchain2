import os
import tempfile

import pytest
from fastapi.testclient import TestClient

temporary_db = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
temporary_db.close()
os.environ["DATABASE_URL"] = f"sqlite:///{temporary_db.name}"

from app.main import app, initialize_database
from app.database.session import Base, engine


@pytest.fixture(scope="session", autouse=True)
def test_database():
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    initialize_database()
    yield
    Base.metadata.drop_all(bind=engine)
    engine.dispose()
    os.unlink(temporary_db.name)


@pytest.fixture
def client(test_database):
    with TestClient(app) as test_client:
        yield test_client
