import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/api/api_client.dart';
import '../../models/application_model.dart';
import '../../models/recruitment_campaign_model.dart';
import '../../services/internal_recruitment_gateway.dart';
import '../../widgets/internal/recruitment_internal_widgets.dart';
import 'application_detail_panel.dart';
import 'campaign_management_screen.dart';

class InternalRecruitmentScreen extends StatefulWidget {
  final InternalRecruitmentGateway? gateway;

  const InternalRecruitmentScreen({super.key, this.gateway});

  @override
  State<InternalRecruitmentScreen> createState() =>
      _InternalRecruitmentScreenState();
}

class _InternalRecruitmentScreenState extends State<InternalRecruitmentScreen> {
  static const _pageSize = 15;
  late final InternalRecruitmentGateway _gateway;
  final _search = TextEditingController();
  final _pole = TextEditingController();
  final _project = TextEditingController();
  final _department = TextEditingController();
  final _className = TextEditingController();
  List<RecruitmentCampaignModel> _campaigns = const [];
  List<ApplicationModel> _applications = const [];
  bool _loading = true;
  bool _refreshing = false;
  bool _filtersExpanded = false;
  bool _anonymized = false;
  String _campaignId = 'all';
  String _status = 'all';
  String _gender = 'all';
  DateTime? _submittedFrom;
  DateTime? _submittedTo;
  int _page = 0;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _gateway = widget.gateway ?? RecruitmentServiceGateway();
    _load(initial: true);
  }

  @override
  void dispose() {
    for (final controller in [
      _search,
      _pole,
      _project,
      _department,
      _className,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load({required bool initial}) async {
    setState(() {
      initial ? _loading = true : _refreshing = true;
      _error = null;
    });
    try {
      final result = await Future.wait<dynamic>([
        _gateway.loadCampaigns(),
        _gateway.loadApplications(),
      ]);
      if (!mounted) return;
      setState(() {
        _campaigns = result[0] as List<RecruitmentCampaignModel>;
        _applications = result[1] as List<ApplicationModel>;
        _page = 0;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  List<ApplicationModel> get _filtered {
    final query = _search.text.trim().toLowerCase();
    final result = _applications.where((item) {
      final searchable = [
        item.fullName,
        item.email,
        item.id,
        item.trackingCode,
      ].whereType<String>().join(' ').toLowerCase();
      return (_campaignId == 'all' || item.campaignId == _campaignId) &&
          (_status == 'all' || item.status == _status) &&
          (_gender == 'all' || item.gender?.toLowerCase() == _gender) &&
          (query.isEmpty || searchable.contains(query)) &&
          _matches(item.preferredPole, _pole.text) &&
          _matches(item.projectInterest, _project.text) &&
          _matches(item.department, _department.text) &&
          _matches(item.className, _className.text) &&
          _inDateRange(item.createdAt);
    }).toList();
    result.sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));
    return result;
  }

  static bool _matches(String? value, String filter) {
    final normalized = filter.trim().toLowerCase();
    return normalized.isEmpty ||
        (value ?? '').toLowerCase().contains(normalized);
  }

  bool _inDateRange(String? raw) {
    if (_submittedFrom == null && _submittedTo == null) return true;
    final date = DateTime.tryParse(raw ?? '')?.toLocal();
    if (date == null) return false;
    final day = DateTime(date.year, date.month, date.day);
    if (_submittedFrom != null && day.isBefore(_submittedFrom!)) return false;
    if (_submittedTo != null && day.isAfter(_submittedTo!)) return false;
    return true;
  }

  int get _activeFilterCount => [
    _search.text.trim().isNotEmpty,
    _campaignId != 'all',
    _status != 'all',
    _gender != 'all',
    _pole.text.trim().isNotEmpty,
    _project.text.trim().isNotEmpty,
    _department.text.trim().isNotEmpty,
    _className.text.trim().isNotEmpty,
    _anonymized,
    _submittedFrom != null,
    _submittedTo != null,
  ].where((active) => active).length;

  String _campaignTitle(String id) {
    for (final campaign in _campaigns) {
      if (campaign.id == id) return campaign.title;
    }
    return 'Campagne inconnue';
  }

  void _resetFilters() => setState(() {
    for (final controller in [
      _search,
      _pole,
      _project,
      _department,
      _className,
    ]) {
      controller.clear();
    }
    _campaignId = 'all';
    _status = 'all';
    _gender = 'all';
    _anonymized = false;
    _submittedFrom = null;
    _submittedTo = null;
    _page = 0;
  });

  Future<void> _pickSubmittedDate({required bool from}) async {
    final current = from ? _submittedFrom : _submittedTo;
    final selected = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: from ? 'Début de période' : 'Fin de période',
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (from) {
        _submittedFrom = selected;
      } else {
        _submittedTo = selected;
      }
      _page = 0;
    });
  }

  Future<void> _openApplication(ApplicationModel application) async {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 900) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (routeContext) => ApplicationDetailPanel(
            summary: application,
            campaignTitle: _campaignTitle(application.campaignId),
            anonymized: _anonymized,
            gateway: _gateway,
            onApplicationChanged: _applyUpdatedApplication,
            onClose: () => Navigator.of(routeContext).pop(),
          ),
        ),
      );
      return;
    }
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fermer la fiche candidat',
      barrierColor: Colors.black45,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, animation, secondaryAnimation) => Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: math.min(760, width * .62),
          height: double.infinity,
          child: ApplicationDetailPanel(
            summary: application,
            campaignTitle: _campaignTitle(application.campaignId),
            anonymized: _anonymized,
            gateway: _gateway,
            onApplicationChanged: _applyUpdatedApplication,
            onClose: () => Navigator.of(dialogContext).pop(),
          ),
        ),
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
                ),
            child: child,
          ),
    );
  }

  void _applyUpdatedApplication(ApplicationModel updated) {
    if (!mounted) return;
    setState(() {
      _applications = _applications
          .map((item) => item.id == updated.id ? updated : item)
          .toList();
    });
  }

  Future<void> _openCampaignManagement() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => CampaignManagementScreen(gateway: _gateway),
      ),
    );
    if (mounted) await _load(initial: false);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final pageCount = math.max(1, (filtered.length / _pageSize).ceil());
    final safePage = math.min(_page, pageCount - 1);
    final start = safePage * _pageSize;
    final end = math.min(start + _pageSize, filtered.length);
    final pageItems = filtered.sublist(start, end);
    final selectedCampaign = _campaignId == 'all'
        ? 'Toutes les campagnes'
        : _campaignTitle(_campaignId);
    final padding = MediaQuery.sizeOf(context).width < 560 ? 14.0 : 24.0;
    return RefreshIndicator(
      onRefresh: () => _load(initial: false),
      child: ListView(
        padding: EdgeInsets.fromLTRB(padding, 20, padding, 28),
        children: [
          InternalRecruitmentHeader(
            campaignLabel: selectedCampaign,
            visibleCount: filtered.length,
            totalCount: _applications.length,
            activeFilterCount: _activeFilterCount,
            onRefresh: () => _load(initial: false),
            onToggleFilters: () =>
                setState(() => _filtersExpanded = !_filtersExpanded),
            onManageCampaigns: _openCampaignManagement,
          ),
          const SizedBox(height: 14),
          InternalFilterBar(
            searchController: _search,
            poleController: _pole,
            projectController: _project,
            departmentController: _department,
            classController: _className,
            campaigns: _campaigns,
            campaignId: _campaignId,
            status: _status,
            gender: _gender,
            anonymized: _anonymized,
            expanded:
                _filtersExpanded || MediaQuery.sizeOf(context).width >= 1100,
            submittedFrom: _submittedFrom,
            submittedTo: _submittedTo,
            onSearchChanged: (_) => setState(() => _page = 0),
            onCampaignChanged: (value) => setState(() {
              _campaignId = value ?? 'all';
              _page = 0;
            }),
            onStatusChanged: (value) => setState(() {
              _status = value ?? 'all';
              _page = 0;
            }),
            onGenderChanged: (value) => setState(() {
              _gender = value ?? 'all';
              _page = 0;
            }),
            onAnonymizedChanged: (value) => setState(() {
              _anonymized = value;
              _page = 0;
            }),
            onPickSubmittedFrom: () => _pickSubmittedDate(from: true),
            onPickSubmittedTo: () => _pickSubmittedDate(from: false),
            onApply: () => setState(() {
              _page = 0;
              if (MediaQuery.sizeOf(context).width < 1100) {
                _filtersExpanded = false;
              }
            }),
            onReset: _resetFilters,
          ),
          const SizedBox(height: 14),
          if (_refreshing)
            const LinearProgressIndicator(minHeight: 3)
          else
            const SizedBox(height: 3),
          const SizedBox(height: 10),
          if (_loading)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (_error != null)
            InternalRecruitmentState(
              icon: _isAccessDenied(_error!)
                  ? Icons.lock_outline_rounded
                  : Icons.cloud_off_outlined,
              title: _isAccessDenied(_error!)
                  ? 'Accès refusé'
                  : 'Erreur de chargement',
              message: _error.toString().replaceAll('Exception: ', ''),
              actionLabel: 'Réessayer',
              onAction: () => _load(initial: true),
            )
          else if (_applications.isEmpty)
            const InternalRecruitmentState(
              icon: Icons.inbox_outlined,
              title: 'Aucun dossier',
              message: 'Aucune candidature n’est disponible pour le moment.',
            )
          else if (filtered.isEmpty)
            InternalRecruitmentState(
              icon: Icons.filter_alt_off_outlined,
              title: 'Aucun résultat',
              message: 'Aucun dossier ne correspond aux filtres actifs.',
              actionLabel: 'Réinitialiser les filtres',
              onAction: _resetFilters,
            )
          else
            ApplicationWorkbench(
              applications: pageItems,
              campaignTitle: _campaignTitle,
              anonymized: _anonymized,
              rangeStart: start + 1,
              rangeEnd: end,
              total: filtered.length,
              currentPage: safePage + 1,
              pageCount: pageCount,
              onOpen: _openApplication,
              onPrevious: safePage == 0
                  ? null
                  : () => setState(() => _page = safePage - 1),
              onNext: safePage >= pageCount - 1
                  ? null
                  : () => setState(() => _page = safePage + 1),
            ),
        ],
      ),
    );
  }

  static bool _isAccessDenied(Object error) =>
      error is ApiException &&
      (error.statusCode == 401 || error.statusCode == 403);
}
