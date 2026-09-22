import 'package:flutter/material.dart';

enum NotificationFamily {
  tasks('tasks', 'Tâches', Icons.task_alt_rounded),
  posts('posts', 'Publications', Icons.dynamic_feed_rounded),
  chat('chat', 'Chat', Icons.chat_bubble_rounded),
  events('events', 'Événements', Icons.event_rounded),
  attendance('attendance', 'Présences', Icons.fact_check_rounded),
  finance('finance', 'Finance', Icons.payments_rounded),
  recruitment('recruitment', 'Recrutement', Icons.how_to_reg_rounded),
  documents('documents', 'Documents', Icons.description_rounded),
  impact('impact', 'Impact', Icons.insights_rounded),
  academy('academy', 'Academy', Icons.school_rounded),
  account('account', 'Compte/Rôle', Icons.manage_accounts_rounded),
  other('other', 'Autres', Icons.notifications_rounded);

  final String value;
  final String label;
  final IconData icon;

  const NotificationFamily(this.value, this.label, this.icon);

  static NotificationFamily fromValue(String value) =>
      values.firstWhere((family) => family.value == value, orElse: () => other);
}

class NotificationPresentation {
  final String label;
  final NotificationFamily family;
  final IconData icon;

  const NotificationPresentation({
    required this.label,
    required this.family,
    required this.icon,
  });
}

NotificationPresentation notificationPresentation(String rawType) {
  final type = rawType.trim().toLowerCase();
  final family = _familyFor(type);
  final label = switch (type) {
    'task_assigned' => 'Tâche assignée',
    'deadline_near' => 'Échéance proche',
    'task_late' => 'Tâche en retard',
    'new_announcement' => 'Nouvelle annonce',
    'event_scheduled' => 'Événement planifié',
    'absence_recorded' => 'Absence enregistrée',
    'fee_due' => 'Cotisation à régler',
    'payment_validated' => 'Paiement validé',
    'payment_submitted' => 'Paiement à vérifier',
    'application_received' => 'Candidature reçue',
    'recruitment_update' => 'Mise à jour recrutement',
    'document_shared' => 'Document partagé',
    'mentorship_assigned' => 'Mentorat attribué',
    'chat_message' => 'Nouveau message',
    'post_comment' => 'Nouveau commentaire',
    'post_reaction' => 'Nouvelle réaction',
    'post_mention' => 'Mention dans une publication',
    'role_updated' => 'Rôle mis à jour',
    'account_updated' => 'Compte mis à jour',
    'attendance' => 'Présence',
    'payment' => 'Paiement',
    'document' => 'Document',
    'recruitment' => 'Recrutement',
    'system' => 'Information système',
    _ =>
      family == NotificationFamily.other ? 'Autre notification' : family.label,
  };
  return NotificationPresentation(
    label: label,
    family: family,
    icon: family.icon,
  );
}

NotificationFamily _familyFor(String type) {
  if (type.contains('task') || type.contains('deadline')) {
    return NotificationFamily.tasks;
  }
  if (type.contains('post') || type.contains('announcement')) {
    return NotificationFamily.posts;
  }
  if (type.contains('chat') || type.contains('message')) {
    return NotificationFamily.chat;
  }
  if (type.contains('event')) return NotificationFamily.events;
  if (type.contains('attendance') ||
      type.contains('presence') ||
      type.contains('absence')) {
    return NotificationFamily.attendance;
  }
  if (type.contains('payment') ||
      type.contains('finance') ||
      type.contains('fee')) {
    return NotificationFamily.finance;
  }
  if (type.contains('recruitment') || type.contains('application')) {
    return NotificationFamily.recruitment;
  }
  if (type.contains('document')) return NotificationFamily.documents;
  if (type.contains('impact')) return NotificationFamily.impact;
  if (type.contains('academy') ||
      type.contains('formation') ||
      type.contains('mentorship')) {
    return NotificationFamily.academy;
  }
  if (type.contains('account') ||
      type.contains('role') ||
      type.contains('user')) {
    return NotificationFamily.account;
  }
  return NotificationFamily.other;
}
