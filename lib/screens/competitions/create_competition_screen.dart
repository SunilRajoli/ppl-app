// lib/screens/competitions/create_competition_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/user_model.dart';
import '../../core/services/api_service.dart';
import '../../widgets/custom_widgets.dart'; // keep for consistency (StatusChip etc.)

class CreateCompetitionScreen extends StatefulWidget {
  const CreateCompetitionScreen({super.key});

  @override
  State<CreateCompetitionScreen> createState() => _CreateCompetitionScreenState();
}

class _CreateCompetitionScreenState extends State<CreateCompetitionScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();

  // --- Form controllers / state ---
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _sponsorCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _bannerCtrl = TextEditingController();

  final _maxTeamCtrl = TextEditingController(text: '1');
  final _seatsCtrl = TextEditingController(text: '100');
  final _prizePoolCtrl = TextEditingController();

  final _tagsCtrl = TextEditingController();
  final _stagesCtrl = TextEditingController(text: 'registration,submission,evaluation');

  // Dates (ISO yyyy-MM-dd for pickers, convert to ISO-8601 on submit)
  final _regStartCtrl = TextEditingController();
  final _regDeadlineCtrl = TextEditingController();
  final _startDateCtrl = TextEditingController();
  final _endDateCtrl = TextEditingController();
  final _resultsDateCtrl = TextEditingController();

  // Eligibility
  final _minAgeCtrl = TextEditingController();
  final _maxAgeCtrl = TextEditingController();
  final _educationCtrl = TextEditingController();
  final _countriesAllowedCtrl = TextEditingController();

  // Contact (REMOVED UI; controllers left harmless if you re-add later)
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _discordCtrl = TextEditingController();

  // Rules
  final _rulesCtrl = TextEditingController();

  // Dynamic lists
  List<Map<String, String>> _prizes = [
    {'place': '', 'amount': ''},
  ];
  List<Map<String, String>> _resources = [
    {'label': '', 'url': ''},
  ];

  // State
  bool _submitting = false;
  String? _error;
  bool _isEdit = false;
  String? _editingId; // used in PUT
  bool _loadingFromRoute = false;

  // Animation
  late final AnimationController _anim;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeIn);
    _slide = Tween<Offset>(begin: const Offset(0, .04), end: Offset.zero)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _hydrateFromRoute();
      if (mounted) _anim.forward();
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _sponsorCtrl.dispose();
    _locationCtrl.dispose();
    _bannerCtrl.dispose();

    _maxTeamCtrl.dispose();
    _seatsCtrl.dispose();
    _prizePoolCtrl.dispose();

    _tagsCtrl.dispose();
    _stagesCtrl.dispose();

    _regStartCtrl.dispose();
    _regDeadlineCtrl.dispose();
    _startDateCtrl.dispose();
    _endDateCtrl.dispose();
    _resultsDateCtrl.dispose();

    _minAgeCtrl.dispose();
    _maxAgeCtrl.dispose();
    _educationCtrl.dispose();
    _countriesAllowedCtrl.dispose();

    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _websiteCtrl.dispose();
    _discordCtrl.dispose();

    _rulesCtrl.dispose();
    _anim.dispose();
    super.dispose();
  }

  /* --------------------------- helpers & parsing --------------------------- */

  DateTime? _parseYmd(String v) {
    if (v.trim().isEmpty) return null;
    try {
      return DateTime.parse(v); // expects yyyy-MM-dd
    } catch (_) {
      return null;
    }
  }

  String? _toIsoOrNull(String v) {
    final d = _parseYmd(v);
    return d?.toIso8601String();
  }

  bool _looksHttp(String v) => RegExp(r'^https?:\/\/', caseSensitive: false).hasMatch(v);

  List<String> _splitComma(String v) =>
      v.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  int? _toIntOrNull(String v) {
    if (v.trim().isEmpty) return null;
    return int.tryParse(v.trim());
  }

  double? _toDoubleOrNull(String v) {
    if (v.trim().isEmpty) return null;
    return double.tryParse(v.trim());
  }

  /* ------------------------------ edit hydrate ----------------------------- */

  Future<void> _hydrateFromRoute() async {
    final state = GoRouterState.of(context);
    final extra = state.extra;
    final idFromPath = state.pathParameters['id'];

    Competition? comp;
    Map<String, dynamic>? raw;

    // 1) Prefer extra (already loaded object)
    if (extra is Map && extra['competition'] != null) {
      final v = extra['competition'];
      if (v is Competition) {
        comp = v;
        raw = v.extra;
      } else if (v is Map<String, dynamic>) {
        comp = Competition.fromJson(v);
        raw = v;
      }
    } else if (extra is Competition) {
      comp = extra;
      raw = extra.extra;
    } else if (extra is Map<String, dynamic>) {
      comp = Competition.fromJson(extra);
      raw = extra;
    }

    // 2) If not provided, but path is /competition/:id/edit, fetch it
    if (comp == null && idFromPath != null && idFromPath.isNotEmpty) {
      setState(() {
        _loadingFromRoute = true;
      });
      try {
        final res = await _api.getCompetition(idFromPath);
        final data = res?['data']?['competition'] ?? res?['competition'] ?? res?['data'];
        if (data is Map<String, dynamic>) {
          comp = Competition.fromJson(data);
          raw = data;
        }
      } catch (e) {
        _error = e.toString();
      } finally {
        if (mounted) setState(() => _loadingFromRoute = false);
      }
    }

    if (comp == null) return;

    _isEdit = true;
    _editingId = comp.id;

    _titleCtrl.text = comp.title;
    _descCtrl.text = comp.descriptionLong ?? comp.description;
    _sponsorCtrl.text = comp.sponsor ?? '';
    _locationCtrl.text = comp.location ?? '';
    _bannerCtrl.text = comp.bannerImageUrl ?? '';

    _maxTeamCtrl.text = (comp.maxTeamSize ?? 1).toString();
    // seats: prefer seats_remaining / total_seats from raw
    final seats = raw?['seats_remaining'] ?? raw?['total_seats'];
    _seatsCtrl.text = (seats is num ? seats : int.tryParse('$seats') ?? 100).toString();

    _tagsCtrl.text = comp.tags.join(',');
    // stages may live only in raw
    final stages = raw?['stages'];
    final stagesText = stages is List
        ? stages.map((e) => e?.toString() ?? '').where((s) => s.trim().isNotEmpty).join(',')
        : stages?.toString() ?? 'registration,submission,evaluation';
    _stagesCtrl.text = stagesText;

    _prizePoolCtrl.text = (comp.prizePool?.toString() ?? '');

    // dates → yyyy-MM-dd
    String _ymd(DateTime? d) =>
        d == null ? '' : '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    _startDateCtrl.text = _ymd(comp.startDate);
    _endDateCtrl.text = _ymd(comp.endDate);

    // extra registration/results
    DateTime? _dateFromRaw(dynamic v) {
      if (v == null) return null;
      try { return DateTime.parse(v.toString()); } catch (_) { return null; }
    }

    _regStartCtrl.text = _ymd(_dateFromRaw(raw?['registration_start_date']));
    _regDeadlineCtrl.text = _ymd(_dateFromRaw(raw?['registration_deadline']));
    _resultsDateCtrl.text = _ymd(_dateFromRaw(raw?['results_date']));

    // eligibility
    final ec = raw?['eligibility_criteria'];
    if (ec is Map) {
      _minAgeCtrl.text = (ec['minAge']?.toString() ?? '');
      _maxAgeCtrl.text = (ec['maxAge']?.toString() ?? '');
      _educationCtrl.text = (ec['education']?.toString() ?? '');
      final ca = ec['countriesAllowed'];
      if (ca is List) {
        _countriesAllowedCtrl.text =
            ca.map((e) => e?.toString() ?? '').where((s) => s.trim().isNotEmpty).join(',');
      } else if (ca is String) {
        _countriesAllowedCtrl.text = ca;
      }
    }

    // contact (ignored in UI)

    // prizes/resources
    final pj = raw?['prizes_json'];
    if (pj is List && pj.isNotEmpty) {
      _prizes = pj
          .map((e) => {
                'place': e?['place']?.toString() ?? '',
                'amount': (e?['amount']?.toString() ?? ''),
              })
          .toList()
          .cast<Map<String, String>>();
    }
    final rj = raw?['resources_json'];
    if (rj is List && rj.isNotEmpty) {
      _resources = rj
          .map((e) => {
                'label': e?['label']?.toString() ?? '',
                'url': e?['url']?.toString() ?? '',
              })
          .toList()
          .cast<Map<String, String>>();
    }

    // rules
    _rulesCtrl.text = raw?['rules_markdown']?.toString() ?? raw?['rules']?.toString() ?? '';

    if (mounted) setState(() {}); // reflect edit mode
  }

  /* --------------------------------- validation -------------------------------- */

  bool _validate() {
    final title = _titleCtrl.text.trim();
    if (title.length < 3) {
      _error = 'Title must be at least 3 characters';
      return false;
    }
    final desc = _descCtrl.text.trim();
    if (desc.length < 10) {
      _error = 'Description must be at least 10 characters';
      return false;
    }
    if (_startDateCtrl.text.isEmpty || _endDateCtrl.text.isEmpty) {
      _error = 'Please select start and end dates';
      return false;
    }
    final sd = _parseYmd(_startDateCtrl.text)!;
    final ed = _parseYmd(_endDateCtrl.text)!;
    if (!ed.isAfter(sd)) {
      _error = 'End date must be after start date';
      return false;
    }
    if (_regStartCtrl.text.isNotEmpty) {
      final rs = _parseYmd(_regStartCtrl.text)!;
      if (rs.isAfter(sd)) {
        _error = 'Registration start must be on/before competition start';
        return false;
      }
    }
    if (_regDeadlineCtrl.text.isNotEmpty) {
      final rd = _parseYmd(_regDeadlineCtrl.text)!;
      if (rd.isAfter(sd)) {
        _error = 'Registration deadline must be before competition start';
        return false;
      }
    }
    if (_resultsDateCtrl.text.isNotEmpty) {
      final res = _parseYmd(_resultsDateCtrl.text)!;
      if (res.isBefore(ed)) {
        _error = 'Results date must be on/after competition end';
        return false;
      }
    }
    final maxTeam = _toIntOrNull(_maxTeamCtrl.text) ?? 0;
    if (maxTeam < 1) {
      _error = 'Max team size must be at least 1';
      return false;
    }
    final seats = _toIntOrNull(_seatsCtrl.text) ?? -1;
    if (seats < 0) {
      _error = 'Seats available cannot be negative';
      return false;
    }
    for (final r in _resources) {
      final url = (r['url'] ?? '').trim();
      if (url.isNotEmpty && !_looksHttp(url)) {
        _error = 'Every Resource URL must start with http:// or https://';
        return false;
      }
    }
    final banner = _bannerCtrl.text.trim();
    if (banner.isNotEmpty && !_looksHttp(banner)) {
      _error = 'Banner Image URL must start with http:// or https://';
      return false;
    }
    _error = null;
    return true;
  }

  /* ---------------------------------- submit ---------------------------------- */

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_validate()) {
      if (mounted) setState(() {});
      return;
    }

    if (mounted) setState(() => _submitting = true);

    try {
      final payload = <String, dynamic>{
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'sponsor': _sponsorCtrl.text.trim().isEmpty ? null : _sponsorCtrl.text.trim(),
        'location': _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
        'banner_image_url': _bannerCtrl.text.trim().isEmpty ? null : _bannerCtrl.text.trim(),

        'start_date': _toIsoOrNull(_startDateCtrl.text),
        'end_date': _toIsoOrNull(_endDateCtrl.text),

        'registration_start_date': _toIsoOrNull(_regStartCtrl.text),
        'registration_deadline': _toIsoOrNull(_regDeadlineCtrl.text),
        'results_date': _toIsoOrNull(_resultsDateCtrl.text),

        'max_team_size': _toIntOrNull(_maxTeamCtrl.text),
        'seats_remaining': _toIntOrNull(_seatsCtrl.text),
        'total_seats': _toIntOrNull(_seatsCtrl.text),

        'tags': _splitComma(_tagsCtrl.text),
        'stages': _splitComma(_stagesCtrl.text),

        'eligibility_criteria': {
          if (_minAgeCtrl.text.trim().isNotEmpty) 'minAge': _toIntOrNull(_minAgeCtrl.text),
          if (_maxAgeCtrl.text.trim().isNotEmpty) 'maxAge': _toIntOrNull(_maxAgeCtrl.text),
          if (_educationCtrl.text.trim().isNotEmpty) 'education': _educationCtrl.text.trim(),
          if (_countriesAllowedCtrl.text.trim().isNotEmpty)
            'countriesAllowed': _splitComma(_countriesAllowedCtrl.text),
        },

        // CONTACT INFO REMOVED FROM PAYLOAD
        // 'contact_info': {...},

        'prize_pool': _prizePoolCtrl.text.trim().isEmpty
            ? null
            : (_toDoubleOrNull(_prizePoolCtrl.text) ?? 0),

        'prizes_json': _prizes
            .map((p) => {
                  if ((p['place'] ?? '').trim().isNotEmpty) 'place': (p['place'] ?? '').trim(),
                  if ((p['amount'] ?? '').trim().isNotEmpty)
                    'amount': _toDoubleOrNull((p['amount'] ?? '').trim()),
                })
            .where((p) => p.isNotEmpty)
            .toList(),

        'resources_json': _resources
            .map((r) => {
                  if ((r['label'] ?? '').trim().isNotEmpty) 'label': (r['label'] ?? '').trim(),
                  if ((r['url'] ?? '').trim().isNotEmpty) 'url': (r['url'] ?? '').trim(),
                })
            .where((r) => r.isNotEmpty)
            .toList(),

        'rules_markdown': _rulesCtrl.text.trim().isEmpty ? null : _rulesCtrl.text.trim(),
      };

      // remove empty nested maps
      if ((payload['eligibility_criteria'] as Map).isEmpty) {
        payload.remove('eligibility_criteria');
      }

      Map<String, dynamic>? res;

      // Use typed ApiService methods
      if (_isEdit && _editingId != null && _editingId!.isNotEmpty) {
        res = await _api.updateCompetition(_editingId!, payload);
      } else {
        res = await _api.createCompetition(payload);
      }

      final ok = res?['success'] == true || res?['data'] != null;
      if (!mounted) return;

      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEdit ? 'Competition updated' : 'Competition created'),
          ),
        );
        context.pop({'refreshCompetitions': true});
      } else {
        final msg = res?['message']?.toString() ?? 'Operation failed';
        setState(() => _error = msg);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _submitting = false);
    }
  }

  /* ---------------------------------- UI ---------------------------------- */

  @override
  Widget build(BuildContext context) {
    // Apply Google Fonts text theme to this screen only.
    final themed = Theme.of(context).copyWith(
      textTheme: GoogleFonts.notoSansTextTheme(Theme.of(context).textTheme),
    );
    final theme = themed;

    // smaller placeholder style for all inputs
    final hintStyleSmall = theme.textTheme.bodySmall?.copyWith(
      fontSize: 12,
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Theme(
      data: themed,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEdit ? 'Edit Competition' : 'Create Competition'),
          elevation: 0,
          actions: [
            IconButton(
              tooltip: 'Close',
              onPressed: () => context.pop(),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        body: SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: _loadingFromRoute
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      child: Column(
                        children: [
                          // Header Card
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: theme.colorScheme.outline.withOpacity(0.25)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: theme.colorScheme.outline.withOpacity(0.25)),
                                  ),
                                  child: Icon(
                                    Icons.rocket_launch_outlined,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _isEdit ? 'Edit Competition' : 'Create Competition',
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        _isEdit ? 'Update competition details' : 'Set up a new competition',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Form Card
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: theme.colorScheme.outline.withOpacity(0.25)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // --- Basic ---
                                _sectionTitle(theme, 'Basic'),
                                _labeledText(theme, 'Title', required: true),
                                _input(
                                  controller: _titleCtrl,
                                  hint: 'Enter competition title',
                                  hintStyle: hintStyleSmall,
                                  prefix: Icons.description_outlined,
                                ),
                                const SizedBox(height: 12),
                                _labeledText(theme, 'Description', required: true),
                                _multiline(
                                  controller: _descCtrl,
                                  hint: 'Describe the competition, expectations and deliverables…',
                                  hintStyle: hintStyleSmall,
                                ),
                                const SizedBox(height: 12),

                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          _labeledText(theme, 'Sponsor'),
                                          _input(
                                            controller: _sponsorCtrl,
                                            hint: 'Competition sponsor',
                                            hintStyle: hintStyleSmall,
                                            prefix: Icons.verified_user_outlined,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          _labeledText(theme, 'Location'),
                                          _input(
                                            controller: _locationCtrl,
                                            hint: 'City / Online / Hybrid',
                                            hintStyle: hintStyleSmall,
                                            prefix: Icons.place_outlined,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                _labeledText(theme, 'Banner Image URL'),
                                _input(
                                  controller: _bannerCtrl,
                                  hint: 'https://example.com/banner.jpg',
                                  hintStyle: hintStyleSmall,
                                  prefix: Icons.image_outlined,
                                ),

                                const SizedBox(height: 16),
                                // --- Capacity ---
                                _sectionTitle(theme, 'Capacity'),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          _labeledText(theme, 'Max Team Size', required: true),
                                          _input(
                                            controller: _maxTeamCtrl,
                                            hint: '1',
                                            hintStyle: hintStyleSmall,
                                            keyboardType: TextInputType.number,
                                            prefix: Icons.groups_2_outlined,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          _labeledText(theme, 'Seats Available', required: true),
                                          _input(
                                            controller: _seatsCtrl,
                                            hint: '100',
                                            hintStyle: hintStyleSmall,
                                            keyboardType: TextInputType.number,
                                            prefix: Icons.numbers_outlined,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          _labeledText(theme, 'Prize Pool (optional)'),
                                          _input(
                                            controller: _prizePoolCtrl,
                                            hint: '100000',
                                            hintStyle: hintStyleSmall,
                                            keyboardType:
                                                const TextInputType.numberWithOptions(decimal: true),
                                            prefix: Icons.card_giftcard_outlined,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 16),
                                // --- Timeline ---
                                _sectionTitle(theme, 'Timeline'),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    _dateField(context, theme,
                                        label: 'Registration Opens',
                                        controller: _regStartCtrl,
                                        hintStyle: hintStyleSmall),
                                    _dateField(context, theme,
                                        label: 'Registration Closes',
                                        controller: _regDeadlineCtrl,
                                        hintStyle: hintStyleSmall),
                                    _dateField(context, theme,
                                        label: 'Start Date',
                                        controller: _startDateCtrl,
                                        required: true,
                                        hintStyle: hintStyleSmall),
                                    _dateField(context, theme,
                                        label: 'End Date',
                                        controller: _endDateCtrl,
                                        required: true,
                                        hintStyle: hintStyleSmall),
                                    _dateField(context, theme,
                                        label: 'Results Date',
                                        controller: _resultsDateCtrl,
                                        hintStyle: hintStyleSmall),
                                  ],
                                ),

                                const SizedBox(height: 16),
                                // --- Tags & Stages ---
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          _labeledText(theme, 'Tags (comma-separated)'),
                                          _input(
                                            controller: _tagsCtrl,
                                            hint: 'e.g., ai,nlp,web-dev',
                                            hintStyle: hintStyleSmall,
                                            prefix: Icons.tag_outlined,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          _labeledText(theme, 'Stages (comma-separated)'),
                                          _input(
                                            controller: _stagesCtrl,
                                            hint: 'registration,submission,evaluation,results',
                                            hintStyle: hintStyleSmall,
                                            prefix: Icons.view_timeline_outlined,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 16),
                                // --- Eligibility ---
                                _sectionTitle(theme, 'Eligibility'),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    _numberField(theme, 'Min Age', _minAgeCtrl, hintStyleSmall),
                                    _numberField(theme, 'Max Age', _maxAgeCtrl, hintStyleSmall),
                                    _textField(theme, 'Education', _educationCtrl,
                                        hint: 'Any / College students / Open', hintStyle: hintStyleSmall),
                                    _textField(
                                      theme,
                                      'Countries Allowed (comma-separated)',
                                      _countriesAllowedCtrl,
                                      prefix: Icons.public_outlined,
                                      hint: 'e.g., US, IN, UK (leave empty for global)',
                                      hintStyle: hintStyleSmall,
                                    ),
                                  ],
                                ),

                                // --- Contact REMOVED ---

                                const SizedBox(height: 16),
                                // --- Prizes ---
                                _sectionTitle(theme, 'Prizes'),
                                _rowAddButton(
                                  theme,
                                  label: 'Add Prize',
                                  icon: Icons.add,
                                  onPressed: () => setState(
                                    () => _prizes.add({'place': '', 'amount': ''}),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Column(
                                  children: [
                                    for (int i = 0; i < _prizes.length; i++)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: _input(
                                                controller: TextEditingController(
                                                  text: _prizes[i]['place'] ?? '',
                                                ),
                                                onChanged: (v) => _prizes[i]['place'] = v,
                                                hint: 'Place (e.g., 1st)',
                                                hintStyle: hintStyleSmall,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: _input(
                                                controller: TextEditingController(
                                                  text: _prizes[i]['amount'] ?? '',
                                                ),
                                                onChanged: (v) => _prizes[i]['amount'] = v,
                                                hint: 'Amount (e.g., 35000)',
                                                hintStyle: hintStyleSmall,
                                                keyboardType:
                                                    const TextInputType.numberWithOptions(decimal: true),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton.filledTonal(
                                              onPressed: () {
                                                setState(() {
                                                  if (_prizes.length > 1) {
                                                    _prizes.removeAt(i);
                                                  }
                                                });
                                              },
                                              icon: const Icon(Icons.delete_outline),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),

                                const SizedBox(height: 16),
                                // --- Resources ---
                                _sectionTitle(theme, 'Resources'),
                                _rowAddButton(
                                  theme,
                                  label: 'Add Resource',
                                  icon: Icons.add_link,
                                  onPressed: () => setState(
                                    () => _resources.add({'label': '', 'url': ''}),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Column(
                                  children: [
                                    for (int i = 0; i < _resources.length; i++)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: _input(
                                                controller: TextEditingController(
                                                  text: _resources[i]['label'] ?? '',
                                                ),
                                                onChanged: (v) => _resources[i]['label'] = v,
                                                hint: 'Label (e.g., Dataset, Starter Notebook)',
                                                hintStyle: hintStyleSmall,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: _input(
                                                controller: TextEditingController(
                                                  text: _resources[i]['url'] ?? '',
                                                ),
                                                onChanged: (v) => _resources[i]['url'] = v,
                                                hint: 'https://...',
                                                hintStyle: hintStyleSmall,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton.filledTonal(
                                              onPressed: () {
                                                setState(() {
                                                  if (_resources.length > 1) {
                                                    _resources.removeAt(i);
                                                  }
                                                });
                                              },
                                              icon: const Icon(Icons.delete_outline),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),

                                const SizedBox(height: 16),
                                // --- Rules ---
                                _sectionTitle(theme, 'Rules (Markdown allowed)'),
                                _multiline(
                                  controller: _rulesCtrl,
                                  minLines: 8,
                                  hint: 'Write the competition rules here...',
                                  hintStyle: hintStyleSmall,
                                ),

                                const SizedBox(height: 12),

                                // --- Error ---
                                if (_error != null)
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.red.withOpacity(0.25)),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.error_outline, color: Colors.red),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _error!,
                                            style: theme.textTheme.bodyMedium?.copyWith(
                                              color: Colors.red.shade300,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                const SizedBox(height: 12),

                                // --- Submit ---
                                FilledButton(
                                  onPressed: _submitting ? null : _submit,
                                  child: Text(
                                    _submitting
                                        ? (_isEdit ? 'Saving Changes...' : 'Creating Competition...')
                                        : (_isEdit ? 'Save Changes' : 'Create Competition'),
                                  ),
                                ),
                                const SizedBox(height: 8),

                                TextButton.icon(
                                  onPressed: () => context.pop(),
                                  icon: const Icon(Icons.chevron_left),
                                  label: const Text('Cancel'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  /* --------------------------- small UI helpers --------------------------- */

  Widget _sectionTitle(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  // Replaced Row with Text.rich to avoid RenderFlex overflow on narrow widths
  Widget _labeledText(ThemeData theme, String text, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 6),
      child: Text.rich(
        TextSpan(
          text: text,
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          children: required
              ? [
                  TextSpan(
                    text: ' *',
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.red),
                  ),
                ]
              : const [],
        ),
        softWrap: true,
      ),
    );
  }

  Widget _input({
    required TextEditingController controller,
    String? hint,
    TextInputType? keyboardType,
    IconData? prefix,
    ValueChanged<String>? onChanged,
    TextStyle? hintStyle, // ⬅️ smaller placeholder
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: hintStyle,
        prefixIcon: prefix != null ? Icon(prefix) : null,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _multiline({
    required TextEditingController controller,
    String? hint,
    int minLines = 4,
    TextStyle? hintStyle, // ⬅️ smaller placeholder
  }) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: null,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: hintStyle,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _textField(
    ThemeData theme,
    String label,
    TextEditingController c, {
    String? hint,
    IconData? prefix,
    TextStyle? hintStyle,
  }) {
    return SizedBox(
      width: 360,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _labeledText(theme, label),
          _input(controller: c, hint: hint, prefix: prefix, hintStyle: hintStyle),
        ],
      ),
    );
  }

  Widget _numberField(ThemeData theme, String label, TextEditingController c, TextStyle? hintStyle) {
    return _textField(
      theme,
      label,
      c,
      hint: '0',
      prefix: Icons.numbers_outlined,
      hintStyle: hintStyle,
    );
  }

  Widget _dateField(
    BuildContext context,
    ThemeData theme, {
    required String label,
    required TextEditingController controller,
    bool required = false,
    TextStyle? hintStyle,
  }) {
    return SizedBox(
      width: 260,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _labeledText(theme, label, required: required),
          GestureDetector(
            onTap: () async {
              final now = DateTime.now();
              final initial = _parseYmd(controller.text) ?? now;
              final picked = await showDatePicker(
                context: context,
                firstDate: DateTime(now.year - 2),
                lastDate: DateTime(now.year + 6),
                initialDate: initial,
              );
              if (picked != null && mounted) {
                final y = picked.year.toString().padLeft(4, '0');
                final m = picked.month.toString().padLeft(2, '0');
                final d = picked.day.toString().padLeft(2, '0');
                controller.text = '$y-$m-$d';
                setState(() {});
              }
            },
            child: AbsorbPointer(
              child: _input(
                controller: controller,
                hint: 'YYYY-MM-DD',
                hintStyle: hintStyle,
                prefix: Icons.calendar_today_outlined,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rowAddButton(ThemeData theme,
      {required String label, required IconData icon, required VoidCallback onPressed}) {
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}
