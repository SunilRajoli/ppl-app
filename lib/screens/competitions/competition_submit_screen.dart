// lib/screens/competitions/competition_submit_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/services/api_service.dart';

class CompetitionSubmitScreen extends StatefulWidget {
  /// Optional if you prefer passing directly instead of route param
  final String? competitionId;
  final String? competitionTitle;
  final Map<String, dynamic>? competitionMeta;

  const CompetitionSubmitScreen({
    super.key,
    this.competitionId,
    this.competitionTitle,
    this.competitionMeta,
  });

  @override
  State<CompetitionSubmitScreen> createState() => _CompetitionSubmitScreenState();
}

class _CompetitionSubmitScreenState extends State<CompetitionSubmitScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();

  // form fields
  final _titleCtrl = TextEditingController();
  final _summaryCtrl = TextEditingController();
  final _repoCtrl = TextEditingController();
  final _driveCtrl = TextEditingController();

  // files
  PlatformFile? _videoFile;
  PlatformFile? _zipFile;
  final List<PlatformFile> _attachments = <PlatformFile>[];

  // state
  bool _submitting = false;
  String? _error;

  // animation
  late final AnimationController _anim;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  // convenience getters from router or props
  String get _competitionId {
    final fromParam = GoRouterState.of(context).pathParameters['id'];
    return widget.competitionId ??
        fromParam ??
        GoRouterState.of(context).uri.queryParameters['id'] ??
        ''; // last resort
  }

  String get _titleFromExtra =>
      (GoRouterState.of(context).extra is Map &&
              (GoRouterState.of(context).extra as Map)['title'] is String)
          ? (GoRouterState.of(context).extra as Map)['title'] as String
          : (widget.competitionTitle ?? 'Submit Project');

  Map<String, dynamic> get _metaFromExtra {
    final extra = GoRouterState.of(context).extra;
    if (extra is Map && extra['meta'] is Map) {
      return Map<String, dynamic>.from(extra['meta'] as Map);
    }
    return widget.competitionMeta ?? const {};
  }

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeIn);
    _slide = Tween<Offset>(begin: const Offset(0, .04), end: Offset.zero)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _anim.forward();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _summaryCtrl.dispose();
    _repoCtrl.dispose();
    _driveCtrl.dispose();
    _anim.dispose();
    super.dispose();
  }

  /* --------------------------------- utils --------------------------------- */

  String _fmtBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /* -------------------------------- pickers -------------------------------- */

  // Only allow the server-approved extensions
  static const List<String> _videoExts = ['mp4', 'mpeg', 'mov', 'webm'];

  Future<void> _pickVideo() async {
    setState(() => _error = null);
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _videoExts,
      withData: true, // needed for web & for bytes upload
    );
    if (res != null && res.files.isNotEmpty) {
      final f = res.files.first;
      final ext = (f.extension ?? '').toLowerCase();
      if (!_videoExts.contains(ext)) {
        setState(() => _error = 'Please select a valid video file (MP4, MPEG, MOV, WebM).');
        return;
      }
      setState(() => _videoFile = f);
    }
  }

  Future<void> _pickZip() async {
    setState(() => _error = null);
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      withData: true,
    );
    if (res != null && res.files.isNotEmpty) {
      final f = res.files.first;
      if (f.extension?.toLowerCase() != 'zip') {
        setState(() => _error = 'Please select a ZIP file');
        return;
      }
      setState(() => _zipFile = f);
    }
  }

  Future<void> _pickAttachments() async {
    setState(() => _error = null);
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.any,
    );
    if (res != null && res.files.isNotEmpty) {
      setState(() => _attachments.addAll(res.files));
    }
  }

  void _removeAttachmentAt(int i) {
    setState(() => _attachments.removeAt(i));
  }

  /* -------------------------------- submit --------------------------------- */

  Future<void> _handleSubmit() async {
    if (_videoFile == null) {
      _toast('Please select a video file to submit');
      return;
    }
    if (_titleCtrl.text.trim().isEmpty) {
      _toast('Project title is required');
      return;
    }
    if (_competitionId.isEmpty) {
      _toast('Missing competition ID');
      return;
    }
    if (_videoFile!.bytes == null) {
      _toast('Could not read the selected video. Please reselect (withData: true).');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      // 1) Upload video (and optional files) using BYTES-based API (works on web + mobile)
      final uploadResp = await _api.uploadVideoFromBytes(
        videoBytes: _videoFile!.bytes!,
        videoFilename: _videoFile!.name,
        title: _titleCtrl.text.trim(),
        summary: _summaryCtrl.text.trim().isEmpty ? null : _summaryCtrl.text.trim(),
        repoUrl: _repoCtrl.text.trim().isEmpty ? null : _repoCtrl.text.trim(),
        driveUrl: _driveCtrl.text.trim().isEmpty ? null : _driveCtrl.text.trim(),
        competitionId: _competitionId.isEmpty ? null : _competitionId,
        zipBytes: _zipFile?.bytes,
        zipFilename: _zipFile?.name,
        attachmentsBytes: _attachments.where((f) => f.bytes != null).map((f) => f.bytes!).toList(),
        attachmentsFilenames: _attachments.map((f) => f.name).toList(),
      );

      final ok = (uploadResp is Map)
          ? (uploadResp['success'] == true || uploadResp['data'] != null || uploadResp['video'] != null)
          : false;

      if (!ok) {
        setState(() => _error = (uploadResp is Map ? uploadResp['message'] as String? : null) ?? 'Upload failed');
        setState(() => _submitting = false);
        return;
      }

      // Pull video URL & metadata.attachments if returned
      final data = (uploadResp is Map ? (uploadResp['data'] ?? uploadResp) : null) as Map?;
      final videoObj = (data?['video'] ?? data);
      final String? videoUrl = (videoObj is Map ? videoObj['url']?.toString() : null);
      final List metaAttachments = (videoObj is Map ? (videoObj['metadata']?['attachments'] as List?) : null) ?? const [];

      // 2) Create submission for this competition (best effort)
      final payload = <String, dynamic>{
        'title': _titleCtrl.text.trim(),
        if (_summaryCtrl.text.trim().isNotEmpty) 'summary': _summaryCtrl.text.trim(),
        if (_repoCtrl.text.trim().isNotEmpty) 'repo_url': _repoCtrl.text.trim(),
        if (_driveCtrl.text.trim().isNotEmpty) 'drive_url': _driveCtrl.text.trim(),
        if (videoUrl != null) 'video_url': videoUrl,
        if (metaAttachments.isNotEmpty) 'attachments': metaAttachments,
      };

      try {
        await _api.createCompetitionSubmission(_competitionId, payload);
      } catch (e) {
        // Don’t block success if backend allows late link
        debugPrint('createCompetitionSubmission failed: $e');
      }

      if (!mounted) return;
      _toast('Project submitted');
      if (mounted) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(true); // <- tells caller “it’s submitted”
        } else {
          context.go('/main?tab=competitions'); // deep link fallback
        }
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /* ---------------------------------- UI ---------------------------------- */

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = _metaFromExtra;

    return ScrollConfiguration(
      behavior: const ScrollBehavior().copyWith(scrollbars: false, overscroll: false),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Submit Project'),
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
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  _HeaderCard(
                    icon: Icons.cloud_upload_outlined,
                    title: 'Submit Project',
                    subtitle: _titleFromExtra,
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _MetaRow(meta: meta),
                  ],
                  const SizedBox(height: 12),
                  _form(theme),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _form(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.25)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title
          _LabeledField(
            label: 'Project Title *',
            child: _InputField(
              controller: _titleCtrl,
              hint: 'Enter your project title',
              leading: Icons.title,
            ),
          ),
          const SizedBox(height: 12),
          // Summary
          _LabeledField(
            label: 'Project Summary (optional)',
            child: _MultilineField(
              controller: _summaryCtrl,
              hint: 'Describe your project, what it does, how it works, key features…',
              leading: Icons.description_outlined,
            ),
          ),
          const SizedBox(height: 12),
          // Repo
          _LabeledField(
            label: 'Repository URL (optional)',
            child: _InputField(
              controller: _repoCtrl,
              hint: 'https://github.com/username/project',
              leading: Icons.link_outlined,
              keyboardType: TextInputType.url,
            ),
          ),
          const SizedBox(height: 12),
          // Drive
          _LabeledField(
            label: 'Drive / Cloud URL (optional)',
            child: _InputField(
              controller: _driveCtrl,
              hint: 'https://drive.google.com/...',
              leading: Icons.link_outlined,
              keyboardType: TextInputType.url,
            ),
          ),
          const SizedBox(height: 16),

          // Upload sections
          _UploadBox(
            title: 'Project Video *',
            hint: 'Upload a short demo video (required)',
            pickLabel: _videoFile == null ? 'Select Video' : 'Change Video',
            icon: Icons.ondemand_video_outlined,
            onPick: _pickVideo,
            pickedChild: _videoFile == null
                ? null
                : _PickedRow(
                    name: _videoFile!.name,
                    size: _fmtBytes(_videoFile!.size),
                    icon: Icons.check_circle,
                    iconColor: theme.colorScheme.primary,
                  ),
          ),
          const SizedBox(height: 12),

          _UploadBox(
            title: 'Project Archive',
            hint: 'Compressed archive of source code or additional files',
            pickLabel: _zipFile == null ? 'Select ZIP' : 'Change ZIP',
            icon: Icons.archive_outlined,
            onPick: _pickZip,
            pickedChild: _zipFile == null
                ? null
                : _PickedRow(
                    name: _zipFile!.name,
                    size: _fmtBytes(_zipFile!.size),
                    icon: Icons.check_circle,
                    iconColor: theme.colorScheme.primary,
                  ),
          ),
          const SizedBox(height: 12),

          _UploadBox(
            title: 'Attachments',
            hint: 'Screenshots, documentation, or other supporting files',
            pickLabel: 'Add Files',
            icon: Icons.attachment_outlined,
            onPick: _pickAttachments,
            pickedChild: _attachments.isEmpty
                ? null
                : Column(
                    children: [
                      for (int i = 0; i < _attachments.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _PickedRow(
                            name: _attachments[i].name,
                            size: _fmtBytes(_attachments[i].size),
                            icon: Icons.insert_drive_file_outlined,
                            trailing: IconButton(
                              onPressed: () => _removeAttachmentAt(i),
                              icon: const Icon(Icons.close),
                              tooltip: 'Remove',
                              splashRadius: 18,
                            ),
                          ),
                        ),
                    ],
                  ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
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
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.red.shade300),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: _submitting ? null : _handleSubmit,
              child: Text(_submitting ? 'Submitting Project…' : 'Submit Project'),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.center,
            child: TextButton.icon(
              onPressed: _submitting ? null : () => context.pop(),
              icon: const Icon(Icons.close),
              label: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }
}

/* --------------------------- small widgets --------------------------- */

class _HeaderCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _HeaderCard({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.25)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outline.withOpacity(0.25)),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final Map<String, dynamic> meta;
  const _MetaRow({required this.meta});

  String _fmtDate(dynamic d) {
    try {
      final dt = DateTime.tryParse('$d');
      if (dt == null) return '—';
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return '—';
    }
  }

  int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final start = meta['start_date'];
    final end = meta['end_date'];
    final seats = _asInt(meta['seats_remaining']);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.25)),
      ),
      padding: const EdgeInsets.all(14),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (start != null && end != null)
            _Pill(icon: Icons.calendar_today, label: '${_fmtDate(start)} — ${_fmtDate(end)}'),
          if (meta.containsKey('seats_remaining')) _Pill(icon: Icons.tag, label: 'Seats: $seats'),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Pill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label, style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabeledField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData? leading;
  final TextInputType? keyboardType;

  const _InputField({
    required this.controller,
    required this.hint,
    this.leading,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (leading != null) ...[
            Icon(leading, size: 18, color: theme.colorScheme.onSurfaceVariant.withOpacity(.8)),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              style: theme.textTheme.bodyMedium, // normal input text
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: hint,
                hintStyle: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MultilineField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData? leading;

  const _MultilineField({
    required this.controller,
    required this.hint,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null) ...[
            const SizedBox(height: 4),
            Icon(leading, size: 18, color: theme.colorScheme.onSurfaceVariant.withOpacity(.8)),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: 6,
              minLines: 3,
              style: theme.textTheme.bodyMedium,
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: hint,
                hintStyle: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadBox extends StatelessWidget {
  final String title;
  final String hint;
  final String pickLabel;
  final IconData icon;
  final VoidCallback onPick;
  final Widget? pickedChild;

  const _UploadBox({
    required this.title,
    required this.hint,
    required this.pickLabel,
    required this.icon,
    required this.onPick,
    this.pickedChild,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.25)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              ),
              SizedBox(
                height: 36,
                child: OutlinedButton(
                  onPressed: onPick,
                  child: Text(pickLabel),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (pickedChild != null)
            pickedChild!
          else
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                hint,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}

class _PickedRow extends StatelessWidget {
  final String name;
  final String size;
  final IconData icon;
  final Color? iconColor;
  final Widget? trailing;

  const _PickedRow({
    required this.name,
    required this.size,
    required this.icon,
    this.iconColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor ?? theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                Text(size, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}