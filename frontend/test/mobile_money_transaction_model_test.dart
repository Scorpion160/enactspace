import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/finance/models/mobile_money_transaction_model.dart';

void main() {
  test('reused PayDunya checkout shows its actual original channel', () {
    final payment = MobileMoneyTransactionModel.fromJson({
      'transaction_id': 'tx-existing',
      'amount': 500,
      'currency': 'XOF',
      'channel': 'wave-senegal',
      'status': 'pending',
      'message': 'Paiement en attente.',
    });
    expect(payment.channel, 'wave-senegal');
    expect(payment.channelLabel, 'Wave');
    expect(payment.isFinal, isFalse);
  });

  test('Orange Money and older responses without channel stay readable', () {
    final orange = MobileMoneyTransactionModel.fromJson({
      'transaction_id': 'tx-orange',
      'amount': 500,
      'currency': 'XOF',
      'channel': 'orange-money-senegal',
      'status': 'successful',
    });
    expect(orange.channelLabel, 'Orange Money');
    expect(orange.isFinal, isTrue);

    final legacy = MobileMoneyTransactionModel.fromJson({
      'transaction_id': 'tx-legacy',
      'amount': 500,
      'currency': 'XOF',
      'status': 'pending',
    });
    expect(legacy.channel, isNull);
    expect(legacy.channelLabel, 'Mobile Money');
  });
}
