// lib/core/models/user_model.dart

class User {
  final String id;
  final String name;
  final String email;
  final String? role;
  final String? college;
  final String? branch;
  final int? year;
  final String? companyName;
  final String? companyWebsite;
  final int? teamSize;
  final String? firmName;
  final String? investmentStage;
  final String? website;
  bool? forcePasswordChange;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.role,
    this.college,
    this.branch,
    this.year,
    this.companyName,
    this.companyWebsite,
    this.teamSize,
    this.firmName,
    this.investmentStage,
    this.website,
    this.forcePasswordChange,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      role: _toStringOrNull(json['role']),
      college: _toStringOrNull(json['college']),
      branch: _toStringOrNull(json['branch']),
      year: _toIntOrNull(json['year']),
      companyName: _toStringOrNull(json['company_name']),
      companyWebsite: _toStringOrNull(json['company_website']),
      teamSize: _toIntOrNull(json['team_size']),
      firmName: _toStringOrNull(json['firm_name']),
      investmentStage: _toStringOrNull(json['investment_stage']),
      website: _toStringOrNull(json['website']),
      forcePasswordChange: _toBoolOrNull(json['force_password_change']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      if (role != null) 'role': role,
      if (college != null) 'college': college,
      if (branch != null) 'branch': branch,
      if (year != null) 'year': year,
      if (companyName != null) 'company_name': companyName,
      if (companyWebsite != null) 'company_website': companyWebsite,
      if (teamSize != null) 'team_size': teamSize,
      if (firmName != null) 'firm_name': firmName,
      if (investmentStage != null) 'investment_stage': investmentStage,
      if (website != null) 'website': website,
      if (forcePasswordChange != null) 'force_password_change': forcePasswordChange,
    };
  }

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.length >= 2) {
      return ('${parts.first[0]}${parts.last[0]}').toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }
}

/* ----------------------------- Competition ----------------------------- */

class Competition {
  final String id;
  final String title;
  final String description;
  final String? descriptionLong;

  // Key dates
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? registrationStartDate;
  final DateTime? registrationDeadline;
  final DateTime? entryDeadline;
  final DateTime? teamMergerDeadline;
  final DateTime? finalSubmissionDeadline;
  final DateTime? resultsDate;

  // Media & meta
  final String? bannerImageUrl;
  final num? prizePool;            // keep as num to accept int/double
  final int? maxTeamSize;
  final String? rules;
  final String? rulesMarkdown;
  final String? sponsor;
  final String? location;
  final List<String> tags;

  // Structured arrays you referenced in React
  final List<Map<String, dynamic>> resourcesJson;
  final List<Map<String, dynamic>> prizesJson;

  // Stats/extra blobs
  final Map<String, dynamic>? stats;
  final Map<String, dynamic> extra; // full raw json (flexibility)

  Competition({
    required this.id,
    required this.title,
    required this.description,
    this.descriptionLong,
    this.startDate,
    this.endDate,
    this.registrationStartDate,
    this.registrationDeadline,
    this.entryDeadline,
    this.teamMergerDeadline,
    this.finalSubmissionDeadline,
    this.resultsDate,
    this.bannerImageUrl,
    this.prizePool,
    this.maxTeamSize,
    this.rules,
    this.rulesMarkdown,
    this.sponsor,
    this.location,
    this.tags = const [],
    this.resourcesJson = const [],
    this.prizesJson = const [],
    this.stats,
    this.extra = const {},
  });

  factory Competition.fromJson(Map<String, dynamic> json) {
    final map = Map<String, dynamic>.from(json);

    return Competition(
      id: (map['id'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      descriptionLong: _toStringOrNull(map['description_long'] ?? map['overview']),

      startDate: _toDateOrNull(map['start_date']),
      endDate: _toDateOrNull(map['end_date']),
      registrationStartDate: _toDateOrNull(map['registration_start_date']),
      registrationDeadline: _toDateOrNull(map['registration_deadline']),
      entryDeadline: _toDateOrNull(map['entry_deadline']),
      teamMergerDeadline: _toDateOrNull(map['team_merger_deadline']),
      finalSubmissionDeadline: _toDateOrNull(map['final_submission_deadline']),
      resultsDate: _toDateOrNull(map['results_date']),

      bannerImageUrl: _toStringOrNull(map['banner_image_url'] ?? map['bannerImageUrl']),
      prizePool: _toNumOrNull(map['prize_pool']),
      maxTeamSize: _toIntOrNull(map['max_team_size']),
      rules: _toStringOrNull(map['rules']),
      rulesMarkdown: _toStringOrNull(map['rules_markdown']),
      sponsor: _toStringOrNull(map['sponsor']),
      location: _toStringOrNull(map['location']),

      tags: _toStringList(map['tags']),
      resourcesJson: _toMapList(map['resources_json']),
      prizesJson: _toMapList(map['prizes_json']),

      stats: (map['stats'] is Map<String, dynamic>) ? Map<String, dynamic>.from(map['stats']) : null,
      extra: map,
    );
  }

  /// Computed status used by UI
  String get status {
    final now = DateTime.now();
    if (startDate != null && startDate!.isAfter(now)) return 'upcoming';
    if (startDate != null &&
        endDate != null &&
        !startDate!.isAfter(now) &&
        endDate!.isAfter(now)) return 'ongoing';
    if (endDate != null && endDate!.isBefore(now)) return 'completed';
    return 'upcoming';
  }

  /// ✅ copyWith so the UI can create an updated instance immutably.
  Competition copyWith({
    String? id,
    String? title,
    String? description,
    String? descriptionLong,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? registrationStartDate,
    DateTime? registrationDeadline,
    DateTime? entryDeadline,
    DateTime? teamMergerDeadline,
    DateTime? finalSubmissionDeadline,
    DateTime? resultsDate,
    String? bannerImageUrl,
    num? prizePool,
    int? maxTeamSize,
    String? rules,
    String? rulesMarkdown,
    String? sponsor,
    String? location,
    List<String>? tags,
    List<Map<String, dynamic>>? resourcesJson,
    List<Map<String, dynamic>>? prizesJson,
    Map<String, dynamic>? stats,
    Map<String, dynamic>? extra,
  }) {
    return Competition(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      descriptionLong: descriptionLong ?? this.descriptionLong,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      registrationStartDate: registrationStartDate ?? this.registrationStartDate,
      registrationDeadline: registrationDeadline ?? this.registrationDeadline,
      entryDeadline: entryDeadline ?? this.entryDeadline,
      teamMergerDeadline: teamMergerDeadline ?? this.teamMergerDeadline,
      finalSubmissionDeadline: finalSubmissionDeadline ?? this.finalSubmissionDeadline,
      resultsDate: resultsDate ?? this.resultsDate,
      bannerImageUrl: bannerImageUrl ?? this.bannerImageUrl,
      prizePool: prizePool ?? this.prizePool,
      maxTeamSize: maxTeamSize ?? this.maxTeamSize,
      rules: rules ?? this.rules,
      rulesMarkdown: rulesMarkdown ?? this.rulesMarkdown,
      sponsor: sponsor ?? this.sponsor,
      location: location ?? this.location,
      tags: tags ?? this.tags,
      resourcesJson: resourcesJson ?? this.resourcesJson,
      prizesJson: prizesJson ?? this.prizesJson,
      stats: stats ?? this.stats,
      extra: extra ?? this.extra,
    );
  }

  /// Optional: convert to JSON (useful for debugging/persisting).
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      if (descriptionLong != null) 'description_long': descriptionLong,
      if (startDate != null) 'start_date': startDate!.toIso8601String(),
      if (endDate != null) 'end_date': endDate!.toIso8601String(),
      if (registrationStartDate != null) 'registration_start_date': registrationStartDate!.toIso8601String(),
      if (registrationDeadline != null) 'registration_deadline': registrationDeadline!.toIso8601String(),
      if (entryDeadline != null) 'entry_deadline': entryDeadline!.toIso8601String(),
      if (teamMergerDeadline != null) 'team_merger_deadline': teamMergerDeadline!.toIso8601String(),
      if (finalSubmissionDeadline != null) 'final_submission_deadline': finalSubmissionDeadline!.toIso8601String(),
      if (resultsDate != null) 'results_date': resultsDate!.toIso8601String(),
      if (bannerImageUrl != null) 'banner_image_url': bannerImageUrl,
      if (prizePool != null) 'prize_pool': prizePool,
      if (maxTeamSize != null) 'max_team_size': maxTeamSize,
      if (rules != null) 'rules': rules,
      if (rulesMarkdown != null) 'rules_markdown': rulesMarkdown,
      if (sponsor != null) 'sponsor': sponsor,
      if (location != null) 'location': location,
      'tags': tags,
      'resources_json': resourcesJson,
      'prizes_json': prizesJson,
      if (stats != null) 'stats': stats,
      // keep full raw as well if you want:
      'extra': extra,
    };
  }

  /* -------------------------- helpers (static) -------------------------- */

  static DateTime? _toDateOrNull(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    final s = v.toString();
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  static int? _toIntOrNull(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) {
      final parsed = int.tryParse(v);
      return parsed;
    }
    return null;
  }

  static num? _toNumOrNull(dynamic v) {
    if (v == null) return null;
    if (v is num) return v;
    if (v is String) {
      final d = double.tryParse(v);
      return d ?? int.tryParse(v);
    }
    return null;
  }

  static String? _toStringOrNull(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    return s.isEmpty ? null : s;
  }

  static bool? _toBoolOrNull(dynamic v) {
    if (v == null) return null;
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.toLowerCase().trim();
      if (s == 'true' || s == '1' || s == 'yes') return true;
      if (s == 'false' || s == '0' || s == 'no') return false;
    }
    return null;
  }

  static List<String> _toStringList(dynamic v) {
    if (v is List) {
      return v.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
    }
    return const [];
  }

  static List<Map<String, dynamic>> _toMapList(dynamic v) {
    if (v is List) {
      return v
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return const [];
  }
}

/* ----------------------- shared parse helpers ----------------------- */

String? _toStringOrNull(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

int? _toIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

bool? _toBoolOrNull(dynamic v) {
  if (v == null) return null;
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.toLowerCase().trim();
    if (s == 'true' || s == '1' || s == 'yes') return true;
    if (s == 'false' || s == '0' || s == 'no') return false;
  }
  return null;
}
