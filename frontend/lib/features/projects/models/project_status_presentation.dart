class ProjectStatusPresentation {
  static const values = <String>[
    'idee',
    'etude',
    'prototype',
    'test',
    'deploiement',
    'termine',
    'suspendu',
  ];

  static String label(String value) => switch (value) {
    'idee' => 'Idée',
    'etude' => 'Étude',
    'prototype' => 'Prototype',
    'test' => 'Test',
    'deploiement' => 'Déploiement',
    'termine' => 'Terminé',
    'suspendu' => 'Suspendu',
    _ => 'Statut non reconnu',
  };
}
