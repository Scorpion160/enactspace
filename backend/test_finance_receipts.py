import unittest
from types import SimpleNamespace
from unittest.mock import MagicMock
from uuid import uuid4

from app.api.routes.finance import allocate_payment_to_unpaid_fees
from app.schemas.mobile_money import MobileMoneyInitiateRequest
from app.services.receipt_reading import parse_receipt


class ReceiptTests(unittest.TestCase):
    def test_read_amount_date_and_labelled_phones(self):
        details = parse_receipt(
            "Montant : 15 000 FCFA\nExpéditeur: 77 123 45 67\n"
            "Destinataire: 78 987 65 43\n28/09/2026 12:05"
        )
        self.assertEqual(details["amount"], 15000)
        self.assertEqual(details["sender_phone"], "771234567")
        self.assertEqual(details["recipient_phone"], "789876543")
        self.assertEqual(details["date_text"], "28/09/2026 12:05")
        self.assertTrue(details["needs_confirmation"])

    def test_orange_money_max_it_receipt_format(self):
        details = parse_receipt(
            "Transfert effectué\nContact\nPapa Test\n"
            "Bénéficiaire\n771234567\nExpéditeur\n781234567\n"
            "Montant\n1 010 F\nDate\n10 septembre 2026 à 22:13\n"
            "Référence\nPP260910.2213.A58434\n"
            "Reçu généré par l'application Max it #OFMS"
        )
        self.assertEqual(details["provider_candidate"], "orange_money")
        self.assertEqual(details["amount"], 1010)
        self.assertEqual(details["sender_phone"], "781234567")
        self.assertEqual(details["recipient_phone"], "771234567")
        self.assertEqual(details["date_text"], "10 septembre 2026 à 22:13")
        self.assertEqual(details["reference"], "PP260910.2213.A58434")
        self.assertEqual(details["status_text"], "Transfert effectué")

    def test_wave_receipt_prefers_received_amount_over_fees(self):
        details = parse_receipt(
            "wave\nReçu de Transaction\nType de transaction\nTransfert\n"
            "Montant reçu\n900F\nExpéditeur\nCheikh T\n78 12 34 56 7\n"
            "Destinataire\nPape N\n77 12 34 56 7\nStatut\nEffectué\n"
            "Montant envoyé\n910F\nFrais\n10F\n"
            "Date et heure\n25 sept. 2026 9:02 AM\n"
            "ID de transaction\nT_HFXFAK6Y6HXMJHJV"
        )
        self.assertEqual(details["provider_candidate"], "wave")
        self.assertEqual(details["amount"], 900)
        self.assertEqual(details["received_amount"], 900)
        self.assertEqual(details["sent_amount"], 910)
        self.assertEqual(details["fee_amount"], 10)
        self.assertEqual(details["sender_phone"], "781234567")
        self.assertEqual(details["recipient_phone"], "771234567")
        self.assertEqual(details["date_text"], "25 sept. 2026 9:02 AM")
        self.assertEqual(details["reference"], "T_HFXFAK6Y6HXMJHJV")

    def test_mobile_money_request_accepts_partial_amount(self):
        fee_id = uuid4()
        payload = MobileMoneyInitiateRequest(
            finance_item_ids=[fee_id],
            channel="wave-senegal",
            amount=500,
        )
        self.assertEqual(payload.finance_item_ids, [fee_id])
        self.assertEqual(payload.amount, 500)

    def test_partial_payment_follows_selected_fees(self):
        first, second = uuid4(), uuid4()
        fees = [SimpleNamespace(id=first, amount=10000, amount_paid=0, status="unpaid", paid_at=None),
                SimpleNamespace(id=second, amount=6000, amount_paid=0, status="unpaid", paid_at=None)]
        db = MagicMock()
        db.query.return_value.filter.return_value.order_by.return_value.with_for_update.return_value.all.return_value = fees
        payment = SimpleNamespace(id=uuid4(), user_id=uuid4(), amount=12000,
            allocation_plan=[{"fee_id": str(second)}, {"fee_id": str(first)}])
        allocations = allocate_payment_to_unpaid_fees(db, payment)
        self.assertEqual([(item.fee_id, item.amount) for item in allocations], [(second, 6000), (first, 6000)])
        self.assertEqual((fees[0].status, fees[1].status), ("partial", "paid"))
        self.assertEqual(fees[0].amount_paid, 6000)
        self.assertEqual(payment.unallocated_amount, 0)
        self.assertEqual(
            payment.allocation_plan,
            [
                {"fee_id": str(second), "amount": 6000},
                {"fee_id": str(first), "amount": 6000},
            ],
        )

    def test_explicit_empty_plan_stays_unallocated(self):
        fee_id = uuid4()
        fee = SimpleNamespace(
            id=fee_id,
            amount=10000,
            amount_paid=0,
            status="unpaid",
            paid_at=None,
        )
        db = MagicMock()
        db.query.return_value.filter.return_value.order_by.return_value.with_for_update.return_value.all.return_value = [fee]
        payment = SimpleNamespace(
            id=uuid4(),
            user_id=uuid4(),
            amount=3000,
            allocation_plan=[],
        )

        allocations = allocate_payment_to_unpaid_fees(db, payment)

        self.assertEqual(allocations, [])
        self.assertEqual(fee.amount_paid, 0)
        self.assertEqual(payment.allocation_plan, [])
        self.assertEqual(payment.unallocated_amount, 3000)

    def test_validation_recalculates_selected_debt_and_tracks_unallocated(self):
        selected, other = uuid4(), uuid4()
        fees = [
            SimpleNamespace(
                id=selected,
                amount=10000,
                amount_paid=8000,
                status="partial",
                paid_at=None,
            ),
            SimpleNamespace(
                id=other,
                amount=10000,
                amount_paid=0,
                status="unpaid",
                paid_at=None,
            ),
        ]
        db = MagicMock()
        db.query.return_value.filter.return_value.order_by.return_value.with_for_update.return_value.all.return_value = fees
        payment = SimpleNamespace(
            id=uuid4(),
            user_id=uuid4(),
            amount=5000,
            allocation_plan=[{"fee_id": str(selected), "amount": 5000}],
        )

        allocations = allocate_payment_to_unpaid_fees(db, payment)

        self.assertEqual([(item.fee_id, item.amount) for item in allocations], [(selected, 2000)])
        self.assertEqual(fees[0].status, "paid")
        self.assertEqual(fees[1].amount_paid, 0)
        self.assertEqual(payment.unallocated_amount, 3000)
        self.assertEqual(
            payment.allocation_plan,
            [{"fee_id": str(selected), "amount": 2000}],
        )


if __name__ == "__main__":
    unittest.main()
