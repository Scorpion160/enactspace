from app.db.database import Base, engine
import app.models.base


def main():
    print("Création des tables EnactSpace...")
    Base.metadata.create_all(bind=engine)
    print("Tables créées avec succès.")


if __name__ == "__main__":
    main()