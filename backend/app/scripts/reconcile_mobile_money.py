import asyncio

from app.db.database import SessionLocal
from app.services.mobile_money_service import reconcile_pending_transactions


async def main() -> None:
    db = SessionLocal()
    try:
        summary = await reconcile_pending_transactions(db)
        db.commit()
        print(
            "Mobile Money reconciliation: "
            f"checked={summary['checked']} "
            f"successful={summary['successful']} "
            f"expired={summary['expired']} "
            f"failed={summary['failed']} "
            f"pending={summary['pending']}"
        )
    finally:
        db.close()


if __name__ == "__main__":
    asyncio.run(main())
