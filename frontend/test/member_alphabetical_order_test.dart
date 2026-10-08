import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/meetings/models/meeting_model.dart';
import 'package:frontend/features/members/models/member_model.dart';

void main() {
  test('les membres sont triés par nom puis prénom, accents neutralisés', () {
    final members = <MemberModel>[
      const MemberModel(
        id: '3',
        email: 'zoe@example.test',
        firstName: 'Zoé',
        lastName: 'Ba',
      ),
      const MemberModel(
        id: '2',
        email: 'amadou-z@example.test',
        firstName: 'Amadou',
        lastName: 'Zall',
      ),
      const MemberModel(
        id: '1',
        email: 'elodie@example.test',
        firstName: 'Élodie',
        lastName: 'Diop',
      ),
      const MemberModel(
        id: '4',
        email: 'amadou-a@example.test',
        firstName: 'Amadou',
        lastName: 'Ba',
      ),
    ]..sort(MemberModel.compareAlphabetically);

    expect(
      members
          .map((member) => '${member.firstName} ${member.lastName}')
          .toList(),
      ['Amadou Ba', 'Zoé Ba', 'Élodie Diop', 'Amadou Zall'],
    );
  });

  test(
    'les participants restent triés par nom avec l’ancien payload production',
    () {
      final members = <MeetingMemberModel>[
        const MeetingMemberModel(
          userId: '1',
          displayName: 'Adja Aïssatou LAYE',
          role: 'participant',
          joinedAt: null,
          leftAt: null,
        ),
        const MeetingMemberModel(
          userId: '2',
          displayName: 'Alimatou Sadiya THIAM',
          role: 'participant',
          joinedAt: null,
          leftAt: null,
        ),
        const MeetingMemberModel(
          userId: '3',
          displayName: 'Amadou Adolphe GALLAND',
          role: 'participant',
          joinedAt: null,
          leftAt: null,
        ),
        const MeetingMemberModel(
          userId: '4',
          displayName: 'Amadou CISSE',
          role: 'participant',
          joinedAt: null,
          leftAt: null,
        ),
      ]..sort(MeetingMemberModel.compareAlphabetically);

      expect(members.map((member) => member.displayName).toList(), [
        'Amadou CISSE',
        'Amadou Adolphe GALLAND',
        'Adja Aïssatou LAYE',
        'Alimatou Sadiya THIAM',
      ]);
    },
  );

  test('la position de pôle est présentée avec un libellé lisible', () {
    const member = MemberModel(
      id: '1',
      email: 'test@example.test',
      polePosition: 'chef_de_pole_veille',
    );
    const canonical = MemberModel(
      id: '2',
      email: 'canonical@example.test',
      polePosition: 'adjoint_chef_pole',
    );

    expect(member.polePositionLabel, 'Chef du pôle Veille');
    expect(canonical.polePositionLabel, 'Adjoint du pôle');
  });
}
