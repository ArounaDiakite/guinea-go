import os

from pymongo import MongoClient
import certifi

uri = os.environ.get("MONGODB_URL", "mongodb://localhost:27017")

try:
    client = MongoClient(
        uri,
        tlsCAFile=certifi.where(),
        serverSelectionTimeoutMS=10000,
    )

    print(client.server_info())
    print("Connexion réussie ✅")

except Exception as e:
    print(e)