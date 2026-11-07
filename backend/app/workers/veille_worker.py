import argparse
import logging
import time

import app.models.base  # register all models and history
from app.db.database import SessionLocal
from app.services.veille_scheduler import run_cycle

log=logging.getLogger("enactspace.veille")


def main():
    parser=argparse.ArgumentParser(description="Préparer les rappels et bilans Veille")
    parser.add_argument("--once",action="store_true")
    parser.add_argument("--interval",type=int,default=300)
    args=parser.parse_args()
    logging.basicConfig(level=logging.INFO)
    while True:
        try:
            with SessionLocal() as db:
                from app.services.disciplinary_execution import execute_due_dismissals
                execute_due_dismissals(db)
                result=run_cycle(db)
                log.info("Veille cycle: %s",result)
        except Exception:
            log.exception("Le cycle Veille a échoué ; sa transaction sera reprise.")
            if args.once: raise
        if args.once: return
        time.sleep(max(30,args.interval))


if __name__=="__main__": main()
