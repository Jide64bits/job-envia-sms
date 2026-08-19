import os
import json
from dotenv import load_dotenv


class Envs:

    load_dotenv()

    ENV = os.getenv("ENV")

    DB_HOST = os.getenv("DB_HOST")
    DB_USER = os.getenv("DB_USER")
    DB_PASSWORD = os.getenv("DB_PASSWORD")
    DB_NAME = os.getenv("DB_NAME")
    DB_PORT = os.getenv("DB_PORT", "5432")

    BACKEND_LOGIN = os.getenv("BACKEND_LOGIN")
    BACKEND_PASSWORD = os.getenv("BACKEND_PASSWORD")

    GCP_STORAGE_KEY = os.getenv("GCP_STORAGE_KEY")

    META_ACCESS_TOKEN = os.getenv("META_ACCESS_TOKEN")
    META_PHONE_NUMBER_ID = os.getenv("META_PHONE_NUMBER_ID")

    EVOLUTION_BASE_URL = os.getenv("EVOLUTION_BASE_URL")
    EVOLUTION_INSTANCE = os.getenv("EVOLUTION_INSTANCE")
    EVOLUTION_API_KEY = os.getenv("EVOLUTION_API_KEY")
