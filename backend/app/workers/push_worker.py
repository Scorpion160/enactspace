import argparse
import time

from app.db.database import SessionLocal
from app.services.push_worker_service import drain_push_deliveries


def main() -> None:
    parser = argparse.ArgumentParser(description="Drain the EnactSpace push outbox")
    parser.add_argument("--once", action="store_true", help="Drain one available batch and exit")
    parser.add_argument("--batch-size", type=int, default=25)
    args = parser.parse_args()
    while True:
        with SessionLocal() as db:
            processed = drain_push_deliveries(db, limit=max(1, min(args.batch_size, 100)))
        if args.once:
            return
        if not processed:
            time.sleep(5)


if __name__ == "__main__":
    main()
