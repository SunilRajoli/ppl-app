import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/services/api_service.dart';

class ContactHistoryScreen extends StatefulWidget {
  const ContactHistoryScreen({super.key});

  @override
  State<ContactHistoryScreen> createState() => _ContactHistoryScreenState();
}

class _ContactHistoryScreenState extends State<ContactHistoryScreen> {
  final _api = ApiService();
  List<Map<String, dynamic>> _contacts = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  String _selectedFilter = 'All';

  final List<String> _filterOptions = ['All', 'Recent', 'This Week', 'This Month'];

  @override
  void initState() {
    super.initState();
    _loadContactHistory();
  }

  Future<void> _loadContactHistory() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final res = await _api.getContactHistory();
      if (!mounted) return;

      final ok = (res is Map) && (res['success'] == true);
      if (ok) {
        // Backend returns: { success: true, data: [contact1, contact2, ...] }
        final data = res['data'] ?? res;
        final contactsList = data is List ? data : [];
        
        final contacts = (contactsList is List)
            ? contactsList.cast<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
            : <Map<String, dynamic>>[];

        setState(() {
          _contacts = contacts;
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load contact history';
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load contact history: ${e.toString()}';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredContacts {
    var filtered = _contacts.where((contact) {
      final recipient = contact['recipient'] ?? contact;
      final name = recipient['name'] ?? '';
      final email = recipient['email'] ?? '';
      final subject = contact['subject'] ?? '';
      final query = _searchQuery.toLowerCase();
      
      return name.toLowerCase().contains(query) || 
             email.toLowerCase().contains(query) || 
             subject.toLowerCase().contains(query);
    }).toList();

    // Apply date filter
    final now = DateTime.now();
    switch (_selectedFilter) {
      case 'Recent':
        filtered = filtered.where((contact) {
          final date = DateTime.parse(contact['contacted_date']);
          return now.difference(date).inDays <= 3;
        }).toList();
        break;
      case 'This Week':
        filtered = filtered.where((contact) {
          final date = DateTime.parse(contact['contacted_date']);
          return now.difference(date).inDays <= 7;
        }).toList();
        break;
      case 'This Month':
        filtered = filtered.where((contact) {
          final date = DateTime.parse(contact['contacted_date']);
          return now.difference(date).inDays <= 30;
        }).toList();
        break;
    }

    // Sort by date (newest first)
    filtered.sort((a, b) => 
      DateTime.parse(b['contacted_date']).compareTo(DateTime.parse(a['contacted_date']))
    );

    return filtered;
  }

  String _formatDate(String dateString) {
    final date = DateTime.parse(dateString);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.read<AuthProvider?>();
    final currentUser = auth?.user;
    final currentUserRole = (currentUser?.role ?? '').toLowerCase();

    // Only show for hiring and investor roles
    if (currentUserRole != 'hiring' && currentUserRole != 'investor') {
      return Scaffold(
        appBar: AppBar(title: const Text('Contact History')),
        body: const Center(
          child: Text('Access denied. This feature is only available for hiring managers and investors.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'My Contacts',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadContactHistory,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search and Filter Section
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Search Bar
                  TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'Search contacts by name, email, or subject...',
                      prefixIcon: Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _filterOptions.map((filter) {
                        final isSelected = _selectedFilter == filter;
                        return Container(
                          margin: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(filter),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() => _selectedFilter = filter);
                            },
                            backgroundColor: theme.colorScheme.surfaceContainerHighest,
                            selectedColor: theme.colorScheme.primary.withOpacity(0.15),
                            checkmarkColor: theme.colorScheme.primary,
                            labelStyle: TextStyle(
                              color: isSelected 
                                ? theme.colorScheme.primary 
                                : theme.colorScheme.onSurfaceVariant,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            // Contact List
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
                              const SizedBox(height: 16),
                              Text(_error!, style: theme.textTheme.bodyLarge),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadContactHistory,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : _filteredContacts.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.mail_outline, size: 48, color: theme.colorScheme.onSurfaceVariant),
                                  const SizedBox(height: 16),
                                  Text(
                                    _searchQuery.isNotEmpty 
                                      ? 'No contacts found for "$_searchQuery"'
                                      : 'No contacts yet',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _searchQuery.isNotEmpty
                                      ? 'Try adjusting your search terms'
                                      : 'Start contacting students to see them here',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              itemCount: _filteredContacts.length,
                              itemBuilder: (context, index) {
                                final contact = _filteredContacts[index];
                                return _buildContactCard(theme, contact);
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard(ThemeData theme, Map<String, dynamic> contact) {
    // Backend structure: contact has 'recipient' (student) and 'sender' (hiring/investor)
    final recipient = contact['recipient'] ?? contact;
    final name = recipient['name'] ?? 'Unknown';
    final email = recipient['email'] ?? '';
    final college = recipient['college'] ?? recipient['college_name'] ?? '';
    final branch = recipient['branch'] ?? recipient['branch_name'] ?? '';
    final year = recipient['year'] ?? recipient['year_of_study'] ?? '';
    final subject = contact['subject'] ?? '';
    final message = contact['message'] ?? '';
    final contactedDate = contact['created_at'] ?? contact['contacted_date'] ?? '';
    final status = contact['status'] ?? 'sent';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with student info
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (college.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          '$college${branch.isNotEmpty ? ' • $branch' : ''}${year.isNotEmpty ? ' • $year' : ''}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Message content
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subject,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: theme.textTheme.bodyMedium,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Footer with date
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDate(contactedDate),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  'Email sent',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
