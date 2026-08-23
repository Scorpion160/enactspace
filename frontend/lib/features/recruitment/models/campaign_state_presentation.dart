import 'recruitment_campaign_model.dart';

class CampaignStatePresentation {
  final String key;
  final String label;

  const CampaignStatePresentation._(this.key, this.label);

  static const planned = CampaignStatePresentation._('planned', 'Planifiée');
  static const open = CampaignStatePresentation._('open', 'Ouverte');
  static const ended = CampaignStatePresentation._('ended', 'Terminée');
  static const inactive = CampaignStatePresentation._('inactive', 'Inactive');

  factory CampaignStatePresentation.fromCampaign(
    RecruitmentCampaignModel campaign, {
    DateTime? now,
  }) {
    final today = _day(now ?? DateTime.now());
    final start = campaign.startDateValue;
    final end = campaign.endDateValue;
    if (end != null && _day(end).isBefore(today)) return ended;
    if (!campaign.isActive) return inactive;
    if (start != null && _day(start).isAfter(today)) return planned;
    return open;
  }

  static DateTime _day(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
