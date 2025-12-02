import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/company.dart';
import '../models/opportunity.dart';
import '../services/authService.dart';
import '../services/opportunityService.dart';
import '../services/applicationService.dart';
import '../utils/page_transitions.dart';
import 'editCompanyProfilePage.dart';
import 'PostOpportunityPage.dart';
import 'EditOpportunityPage.dart';
import 'opportunityAnalyticsPage.dart';
import 'opportunityDetailPage.dart';
import 'allApplicantsPage.dart';
import 'followersPage.dart';
import 'notificationsPage.dart';
import 'company_theme.dart';
import '../studentScreens/welcomeScreen.dart';
import 'package:intl/intl.dart';
import 'companyReviewsPage.dart';

class CompanyHomePage extends StatefulWidget {
  const CompanyHomePage({super.key});

  @override
  _CompanyHomePageState createState() => _CompanyHomePageState();
}

class _NotificationPreview {
  const _NotificationPreview({
    required this.title,
    required this.message,
    required this.timestamp,
  });

  final String title;
  final String message;
  final DateTime timestamp;
}

class _CompanyHomePageState extends State<CompanyHomePage> {
  final AuthService _authService = AuthService();
  final OpportunityService _opportunityService = OpportunityService();
  final ApplicationService _applicationService = ApplicationService();
  Company? _company;
  List<Opportunity> _opportunities = [];
  bool _isLoading = true;
  final double _headerHeight = 20.0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  String _sortBy = 'newest'; // 'newest', 'oldest'

  @override
  void initState() {
    super.initState();
    _fetchCompanyData();
  }

  int _totalApplicants = 0;
  int _pendingApplicants = 0;
  int _activeOpportunities = 0;
  final List<_NotificationPreview> _latestNotifications = [];

  Future<void> _fetchCompanyData() async {
    setState(() => _isLoading = true);
    try {
      final company = await _authService.getCurrentCompany();
      final opportunities = await _opportunityService.getCompanyOpportunities(
        company?.uid ?? '',
      );

      // Calculate analytics - fetch all applications in parallel for better performance
      int totalApplicants = 0;
      int pendingApplicants = 0;
      int activeOps = 0;

      final now = DateTime.now();

      // Fetch all applications in parallel instead of sequentially
      final applicationFutures = opportunities
          .map(
            (opp) => _applicationService.getApplicationsForOpportunity(opp.id),
          )
          .toList();

      final allApplications = await Future.wait(applicationFutures);

      for (int i = 0; i < opportunities.length; i++) {
        final opp = opportunities[i];
        final applicationOpenDate = opp.applicationOpenDate?.toDate();
        final isUpcoming =
            applicationOpenDate != null && now.isBefore(applicationOpenDate);

        if (opp.isActive && !isUpcoming) {
          activeOps++;
        }

        final applications = allApplications[i];
        totalApplicants += applications.length;
        pendingApplicants += applications
            .where((app) => app.status.toLowerCase() == 'pending')
            .length;
      }

      if (!mounted) return;
      setState(() {
        _company = company;
        _opportunities = opportunities;
        _totalApplicants = totalApplicants;
        _pendingApplicants = pendingApplicants;
        _activeOpportunities = activeOps;
      });
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error fetching data: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToPostOpportunityPage() async {
    await Navigator.push(
      context,
      SmoothPageRoute(page: const PostOpportunityPage()),
    );
    if (!mounted) return;
    _fetchCompanyData();
  }

  Future<void> _navigateToApplicantsList(Opportunity opportunity) async {
    final company = _company;
    if (company == null) {
      _showSnackBar('Company information is still loading. Please try again.');
      return;
    }

    await Navigator.push(
      context,
      SmoothPageRoute(
        page: AllApplicantsPage(company: company, opportunity: opportunity),
      ),
    );
    if (!mounted) return;
    _fetchCompanyData();
  }

  Future<void> _navigateToAnalytics(Opportunity opportunity) async {
    await Navigator.push(
      context,
      SmoothPageRoute(page: OpportunityAnalyticsPage(opportunity: opportunity)),
    );
    if (!mounted) return;
    _fetchCompanyData();
  }

  Future<void> _navigateToEditOpportunity(Opportunity opportunity) async {
    final result = await Navigator.push(
      context,
      SmoothPageRoute(page: EditOpportunityPage(opportunity: opportunity)),
    );

    // If the edit was successful, refresh the opportunities list
    if (result == true && mounted) {
      _fetchCompanyData();
      _showSnackBar('Opportunity updated successfully!');
    }
  }

  Future<void> _navigateToAllApplicants() async {
    final company = _company;
    if (company == null) {
      _showSnackBar('Company information is still loading. Please try again.');
      return;
    }
    await Navigator.push(
      context,
      SmoothPageRoute(page: AllApplicantsPage(company: company)),
    );
    if (!mounted) return;
    _fetchCompanyData();
  }

  void _navigateToFollowersPage() {
    final company = _company;
    if (company == null) {
      _showSnackBar('Company information is still loading. Please try again.');
      return;
    }
    Navigator.push(
      context,
      SmoothPageRoute(page: FollowersPage(company: company)),
    );
  }

  void _navigateToNotificationsPage() {
    Navigator.push(context, FadePageRoute(page: const NotificationsPage()));
  }

  Future<void> _deleteOpportunity(String opportunityId) async {
    if (opportunityId.isEmpty) {
      _showSnackBar('Invalid opportunity ID');
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(
          'Delete Opportunity',
          style: TextStyle(color: CompanyColors.primary),
        ),
        content: const SingleChildScrollView(
          child: Text(
            'Are you sure you want to permanently delete this opportunity? This action cannot be undone.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
              backgroundColor: Colors.red.withOpacity(0.1),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Deleting opportunity...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      try {
        await _opportunityService.deleteOpportunity(opportunityId);
        if (!mounted) return;
        _showSnackBar('Opportunity deleted successfully.');
        await _fetchCompanyData();
      } catch (e) {
        if (!mounted) return;
        _showSnackBar(
          'Error deleting opportunity: ${e.toString().replaceAll('Exception: ', '')}',
        );
      }
    }
  }

  // Method for deleting from detail page - includes navigation back
  void _deleteOpportunityFromDetail(String opportunityId) async {
    if (opportunityId.isEmpty) {
      _showSnackBar('Invalid opportunity ID');
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(
          'Delete Opportunity',
          style: TextStyle(color: CompanyColors.primary),
        ),
        content: const SingleChildScrollView(
          child: Text(
            'Are you sure you want to permanently delete this opportunity? This action cannot be undone.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
              backgroundColor: Colors.red.withOpacity(0.1),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Deleting opportunity...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      try {
        await _opportunityService.deleteOpportunity(opportunityId);
        if (!mounted) return;

        // Navigate back before showing success message
        Navigator.of(context).pop();

        _showSnackBar('Opportunity deleted successfully.');
        await _fetchCompanyData();
      } catch (e) {
        if (!mounted) return;
        _showSnackBar(
          'Error deleting opportunity: ${e.toString().replaceAll('Exception: ', '')}',
        );
      }
    }
  }

  Future<void> _showDeleteConfirmationDialog() async {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    Navigator.of(context).pop();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account Permanently?'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'This action is irreversible. All of your data, including posted opportunities, will be deleted. Please enter your password to confirm.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Password is required'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(true);
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _authService.deleteCompanyAccount(passwordController.text.trim());
        if (!mounted) return;
        _showSnackBar('Account deleted successfully.');
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          (route) => false,
        );
      } catch (e) {
        if (!mounted) return;
        _showSnackBar(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _onNavigationTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        // Already on home, scroll to top
        break;
      case 1:
        // Scroll to opportunities section
        break;
      case 2:
        _navigateToPostOpportunityPage();
        break;
      case 3:
        // Notifications - show notifications section
        break;
      case 4:
        // Profile - show profile section
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF422F5D), Color(0xFFD64483)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.transparent,
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : RefreshIndicator(
                onRefresh: _fetchCompanyData,
                child: CustomScrollView(
                  slivers: [_buildSliverAppBar(), _buildCurrentSection()],
                ),
              ),
        bottomNavigationBar: _buildBottomNavigationBar(),
      ),
    );
  }

  Widget _buildCurrentSection() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardSection();
      case 1:
        return _buildOpportunitiesListSection();
      case 3:
        return _buildNotificationsSection();
      case 4:
        return _buildProfileSection();
      default:
        return _buildDashboardSection();
    }
  }

  Widget _buildNotificationsSection() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.notifications_outlined,
                size: 120,
                color: CompanyColors.muted.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 24),
              const Text(
                'No Notifications',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: CompanyColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'You\'re all caught up! When you have new notifications, they\'ll appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: CompanyColors.muted,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardSection() {
    return SliverPadding(
      padding: const EdgeInsets.all(16.0),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          _buildAnalyticsCards(),
          const SizedBox(height: 32),
          _buildQuickActions(),
          const SizedBox(height: 32),
          _buildRecentActivity(),
          const SizedBox(height: 100),
        ]),
      ),
    );
  }

  Widget _buildProfileSection() {
    final company = _company;
    if (company == null)
      return SliverList(delegate: SliverChildListDelegate([]));

    final contact = (company.contactInfo).trim();
    final email = company.email.trim();
    final description = (company.description ?? '').trim();
    final contactPills = _buildContactChips(contact);

    return SliverPadding(
      padding: const EdgeInsets.all(16.0),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Manage Profile',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: CompanyColors.primary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: CompanyColors.secondary),
                iconSize: 28,
                tooltip: 'Edit Profile',
                onPressed: () {
                  Navigator.of(context)
                      .push(
                        SmoothPageRoute(
                          page: EditCompanyProfilePage(company: company),
                        ),
                      )
                      .then((_) => _fetchCompanyData());
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            color: CompanyColors.surface,
            elevation: CompanySpacing.cardElevation,
            shape: RoundedRectangleBorder(
              borderRadius: CompanySpacing.cardRadius,
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: CompanyColors.primary.withValues(
                        alpha: 0.1,
                      ),
                      backgroundImage:
                          company.logoUrl != null && company.logoUrl!.isNotEmpty
                          ? CachedNetworkImageProvider(company.logoUrl!)
                          : null,
                      child:
                          (company.logoUrl == null || company.logoUrl!.isEmpty)
                          ? const Icon(
                              Icons.apartment_outlined,
                              color: CompanyColors.primary,
                              size: 50,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      company.companyName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: CompanyColors.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: CompanyColors.secondary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        company.sector.isNotEmpty
                            ? company.sector
                            : 'Sector not specified',
                        style: const TextStyle(
                          fontSize: 14,
                          color: CompanyColors.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 24),
                  _buildProfileInfoRow(
                    icon: Icons.alternate_email_outlined,
                    label: 'Email',
                    value: email.isNotEmpty ? email : 'Email not provided',
                  ),
                  if (contactPills.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildProfileInfoRow(
                      icon: Icons.contact_phone_outlined,
                      label: 'Contact',
                      value: '',
                      customWidget: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: contactPills,
                      ),
                    ),
                  ],
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 24),
                    const Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: CompanyColors.primary,
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'About the Company',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: CompanyColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: CompanyColors.muted,
                        height: 1.6,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildProfileActionCard(
            icon: Icons.group_outlined,
            title: 'My Followers',
            onTap: _navigateToFollowersPage,
          ),
          const SizedBox(height: 12),
          _buildProfileActionCard(
            icon: Icons.star_outline,
            title: 'My Reviews',
            onTap: () {
              if (_company == null) {
                _showSnackBar(
                  'Company information is still loading. Please try again.',
                );
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CompanyReviewsPage(
                    companyId: _company!.uid!,
                    companyName: _company!.companyName,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          Card(
            color: CompanyColors.surface,
            elevation: CompanySpacing.cardElevation,
            shape: RoundedRectangleBorder(
              borderRadius: CompanySpacing.cardRadius,
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.logout,
                    color: CompanyColors.secondary,
                  ),
                  title: const Text(
                    'Log Out',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: CompanyColors.primary,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: CompanyColors.muted,
                  ),
                  onTap: () async {
                    await _authService.signOut();
                    if (!mounted) return;
                    Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil('/', (route) => false);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text(
                    'Delete Account',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.red,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: CompanyColors.muted,
                  ),
                  onTap: _showDeleteConfirmationDialog,
                ),
              ],
            ),
          ),
          const SizedBox(height: 100),
        ]),
      ),
    );
  }

  Widget _buildProfileActionCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Card(
      color: CompanyColors.surface,
      elevation: CompanySpacing.cardElevation,
      shape: RoundedRectangleBorder(borderRadius: CompanySpacing.cardRadius),
      child: ListTile(
        leading: Icon(icon, color: CompanyColors.primary),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: CompanyColors.primary,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: CompanyColors.muted,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildProfileInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Widget? customWidget,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: CompanyColors.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: CompanyColors.muted,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              customWidget ??
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 15,
                      color: CompanyColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOpportunitiesListSection() {
    final now = DateTime.now();

    bool isUpcoming(Opportunity opp) {
      final applicationOpenDate = opp.applicationOpenDate?.toDate();
      return applicationOpenDate != null && now.isBefore(applicationOpenDate);
    }

    final upcomingOpportunities = _opportunities.where(isUpcoming).toList();

    final activeOpportunities = _opportunities
        .where((opp) => opp.isActive && !isUpcoming(opp))
        .toList();
    final pastOpportunities = _opportunities
        .where((opp) => !opp.isActive && !isUpcoming(opp))
        .toList();

    // Apply sorting to both lists
    void sortOpportunities(List<Opportunity> opportunities) {
      switch (_sortBy) {
        case 'newest':
          opportunities.sort((a, b) {
            final aDate = a.postedDate?.toDate() ?? DateTime.now();
            final bDate = b.postedDate?.toDate() ?? DateTime.now();
            return bDate.compareTo(aDate);
          });
          break;
        case 'oldest':
          opportunities.sort((a, b) {
            final aDate = a.postedDate?.toDate() ?? DateTime.now();
            final bDate = b.postedDate?.toDate() ?? DateTime.now();
            return aDate.compareTo(bDate);
          });
          break;
      }
    }

    sortOpportunities(activeOpportunities);
    sortOpportunities(pastOpportunities);

    return SliverPadding(
      padding: const EdgeInsets.all(16.0),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildGradientButton(
                text: 'Post New',
                icon: Icons.add,
                onPressed: _navigateToPostOpportunityPage,
              ),
              Row(
                children: [
                  const Text(
                    'Sort by: ',
                    style: TextStyle(
                      color: CompanyColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: CompanyColors.primary.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _sortBy,
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: CompanyColors.primary,
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          color: CompanyColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                        dropdownColor: Colors.white,
                        items: const [
                          DropdownMenuItem(
                            value: 'newest',
                            child: Text('Newest'),
                          ),
                          DropdownMenuItem(
                            value: 'oldest',
                            child: Text('Oldest'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _sortBy = value;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Active Opportunities Section
          const Text(
            'Active Opportunities',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: CompanyColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          if (_opportunities.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.work_outline,
                      size: 64,
                      color: CompanyColors.muted.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No opportunities posted yet',
                      style: TextStyle(
                        fontSize: 16,
                        color: CompanyColors.muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _navigateToPostOpportunityPage,
                      icon: const Icon(Icons.add),
                      label: const Text('Post Your First Opportunity'),
                    ),
                  ],
                ),
              ),
            )
          else if (activeOpportunities.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32.0),
                child: Text(
                  'No active opportunities',
                  style: TextStyle(
                    fontSize: 14,
                    color: CompanyColors.muted.withValues(alpha: 0.7),
                  ),
                ),
              ),
            )
          else
            ...activeOpportunities.map(
              (opp) => _buildCompactOpportunityCard(opp),
            ),

          if (upcomingOpportunities.isNotEmpty) ...[
            const SizedBox(height: 32),
            _buildUpcomingOpportunitiesSection(upcomingOpportunities, now),
          ],

          // Past Opportunities Section
          if (pastOpportunities.isNotEmpty) ...[
            const SizedBox(height: 32),
            const Text(
              'Past Opportunities',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: CompanyColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            ...pastOpportunities.map(_buildCompactOpportunityCard),
          ],
          const SizedBox(height: 100),
        ]),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: CompanyColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 70,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0,
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Home',
              ),
              _buildNavItem(
                index: 1,
                icon: Icons.work_outline,
                activeIcon: Icons.work,
                label: 'Opportunities',
              ),
              _buildCenterFAB(),
              _buildNavItem(
                index: 3,
                icon: Icons.notifications_outlined,
                activeIcon: Icons.notifications,
                label: 'Notifications',
              ),
              _buildNavItem(
                index: 4,
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterFAB() {
    return Expanded(
      child: InkWell(
        onTap: _navigateToPostOpportunityPage,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [CompanyColors.secondary, CompanyColors.accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: CompanyColors.secondary.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 28),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => _onNavigationTapped(index),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                color: isSelected
                    ? CompanyColors.secondary
                    : CompanyColors.muted,
                size: 22,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  color: isSelected
                      ? CompanyColors.secondary
                      : CompanyColors.muted,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [CompanyColors.secondary, CompanyColors.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: CompanyColors.secondary.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onNavigationTapped(1),
          borderRadius: BorderRadius.circular(32),
          child: const Icon(Icons.add, color: Colors.white, size: 32),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      backgroundColor: CompanyColors.background,
      expandedHeight: _headerHeight,
      pinned: true,
      floating: false,
      leading: const SizedBox.shrink(),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: false,
        titlePadding: const EdgeInsets.only(left: 16.0, bottom: 16.0),
        title: null,
        background: Container(
          decoration: const BoxDecoration(gradient: CompanyColors.heroGradient),
          child: _buildProfileHeaderContent(),
        ),
      ),
    );
  }

  Widget _buildProfileHeaderContent() {
    String headerText;
    switch (_selectedIndex) {
      case 0:
        headerText = 'Dashboard';
        break;
      case 1:
        headerText = 'Opportunities';
        break;
      case 3:
        headerText = 'Notifications';
        break;
      case 4:
        headerText = 'Profile';
        break;
      default:
        headerText = 'Dashboard';
    }

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            headerText,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompanyInfoCard() {
    final company = _company;
    if (company == null) return const SizedBox.shrink();

    final contact = (company.contactInfo).trim();
    final email = company.email.trim();
    final description = (company.description ?? '').trim();

    final contactPills = _buildContactChips(contact);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      color: CompanyColors.surface,
      shape: RoundedRectangleBorder(borderRadius: CompanySpacing.cardRadius),
      elevation: CompanySpacing.cardElevation,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: CompanyColors.primary.withValues(alpha: 0.1),
                  backgroundImage:
                      company.logoUrl != null && company.logoUrl!.isNotEmpty
                      ? CachedNetworkImageProvider(company.logoUrl!)
                      : null,
                  child: (company.logoUrl == null || company.logoUrl!.isEmpty)
                      ? const Icon(
                          Icons.apartment_outlined,
                          color: CompanyColors.primary,
                          size: 30,
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        company.companyName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: CompanyColors.primary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        company.sector.isNotEmpty
                            ? company.sector
                            : 'Sector not specified',
                        style: const TextStyle(
                          fontSize: 14,
                          color: CompanyColors.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: CompanyColors.secondary),
                  tooltip: 'Edit Company Profile',
                  onPressed: () {
                    Navigator.of(context)
                        .push(
                          SmoothPageRoute(
                            page: EditCompanyProfilePage(company: _company!),
                          ),
                        )
                        .then((_) => _fetchCompanyData());
                  },
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (contactPills.isNotEmpty) ...[
              Wrap(spacing: 10, runSpacing: 10, children: contactPills),
              const SizedBox(height: 12),
            ],
            _buildInfoPill(
              Icons.alternate_email_outlined,
              email.isNotEmpty ? email : 'Email not provided',
              background: CompanyColors.primary.withValues(alpha: 0.08),
              iconColor: CompanyColors.primary,
              textColor: CompanyColors.primary,
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 18),
              const Text(
                'About the company',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: CompanyColors.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 13,
                  color: CompanyColors.muted,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Overview',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: CompanyColors.primary,
          ),
        ),
        const SizedBox(height: 16),
        IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: _buildAnalyticCard(
                  icon: Icons.work_outline,
                  title: 'Active Opportunities',
                  value: _activeOpportunities.toString(),
                  color: CompanyColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAnalyticCard(
                  icon: Icons.people_outline,
                  title: 'Total Applicants',
                  value: _totalApplicants.toString(),
                  color: CompanyColors.secondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyticCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Card(
      color: CompanyColors.surface,
      elevation: CompanySpacing.cardElevation,
      shape: RoundedRectangleBorder(borderRadius: CompanySpacing.cardRadius),
      child: Container(
        constraints: const BoxConstraints(minHeight: 150, maxHeight: 170),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: color,
                      height: 1.0,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      color: CompanyColors.muted,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: CompanyColors.primary,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.add_circle_outline,
                title: 'Post Opportunity',
                onTap: _navigateToPostOpportunityPage,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                icon: Icons.people_outline,
                title: 'View Applicants',
                onTap: _navigateToAllApplicants,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Card(
      color: CompanyColors.surface,
      elevation: CompanySpacing.cardElevation,
      shape: RoundedRectangleBorder(borderRadius: CompanySpacing.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: CompanySpacing.cardRadius,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(icon, color: CompanyColors.secondary, size: 36),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: CompanyColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    final notifications = _latestNotifications;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Latest Notifications',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: CompanyColors.primary,
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() => _selectedIndex = 3);
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (notifications.isEmpty)
          Card(
            color: CompanyColors.surface,
            elevation: CompanySpacing.cardElevation,
            shape: RoundedRectangleBorder(
              borderRadius: CompanySpacing.cardRadius,
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CompanyColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.notifications_active_outlined,
                      color: CompanyColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'You\'re all caught up!',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: CompanyColors.primary,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'When students interact with your opportunities or profile, their updates will surface here. '
                          'Visit the notifications tab to review past activity.',
                          style: TextStyle(
                            fontSize: 13,
                            color: CompanyColors.muted,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Column(
            children: notifications
                .map(
                  (notification) => Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    color: CompanyColors.surface,
                    elevation: CompanySpacing.cardElevation,
                    shape: RoundedRectangleBorder(
                      borderRadius: CompanySpacing.cardRadius,
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: CompanyColors.primary.withValues(
                          alpha: 0.12,
                        ),
                        foregroundColor: CompanyColors.primary,
                        child: const Icon(Icons.notifications_outlined),
                      ),
                      title: Text(
                        notification.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: CompanyColors.primary,
                        ),
                      ),
                      subtitle: Text(
                        '${notification.message}\n${DateFormat('MMM d, h:mm a').format(notification.timestamp)}',
                        style: const TextStyle(
                          color: CompanyColors.muted,
                          height: 1.4,
                        ),
                      ),
                      isThreeLine: true,
                      onTap: _navigateToNotificationsPage,
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  Widget _buildCompactOpportunityCard(
    Opportunity opportunity, {
    String? badge,
    Color badgeColor = CompanyColors.secondary,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: CompanyColors.surface,
      elevation: CompanySpacing.cardElevation,
      shape: RoundedRectangleBorder(borderRadius: CompanySpacing.cardRadius),
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            SmoothPageRoute(
              page: OpportunityDetailPage(
                opportunity: opportunity,
                onDelete: () => _deleteOpportunityFromDetail(opportunity.id),
                onUpdate: _fetchCompanyData,
              ),
            ),
          );
          _fetchCompanyData(); // Refresh data when returning
        },
        borderRadius: CompanySpacing.cardRadius,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: CompanyColors.heroGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.work, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      opportunity.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: CompanyColors.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      opportunity.role,
                      style: const TextStyle(
                        fontSize: 14,
                        color: CompanyColors.muted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (badge != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: badgeColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: CompanyColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingOpportunitiesSection(
    List<Opportunity> upcomingOpps,
    DateTime now,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: const [
                Icon(Icons.schedule, color: CompanyColors.secondary, size: 24),
                SizedBox(width: 8),
                Text(
                  'Upcoming Opportunities',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: CompanyColors.primary,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: CompanyColors.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${upcomingOpps.length}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: CompanyColors.secondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Applications will open soon for these opportunities',
          style: TextStyle(fontSize: 14, color: CompanyColors.muted),
        ),
        const SizedBox(height: 16),
        ...upcomingOpps.map((opp) {
          final applicationOpenDate = opp.applicationOpenDate!.toDate();
          final difference = applicationOpenDate.difference(now);
          final daysUntil = difference.inDays;
          final hoursUntil = difference.inHours;

          String opensIn;
          if (daysUntil > 0) {
            opensIn = 'Opens in $daysUntil ${daysUntil == 1 ? 'day' : 'days'}';
          } else if (hoursUntil > 0) {
            opensIn =
                'Opens in $hoursUntil ${hoursUntil == 1 ? 'hour' : 'hours'}';
          } else {
            opensIn = 'Opens soon';
          }

          return _buildCompactOpportunityCard(
            opp,
            badge: opensIn,
            badgeColor: CompanyColors.secondary,
          );
        }),
      ],
    );
  }

  List<Widget> _buildContactChips(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return [];

    // Check if the format is "Name - +966XXXXXXXXX"
    if (trimmed.contains(' - +966')) {
      final parts = trimmed.split(' - ');
      if (parts.length == 2) {
        final name = parts[0].trim();
        final number = parts[1].trim();
        return _buildContactPills(
          name.isNotEmpty ? name : null,
          number.isNotEmpty ? number : null,
        );
      }
    }

    // Fallback to original regex parsing
    final match = RegExp(r'[+]?\d[\d\s-]*').firstMatch(trimmed);
    String? number = match?.group(0)?.trim();
    String? name;

    if (match != null) {
      name = trimmed.substring(0, match.start).trim();
      final remainder = trimmed.substring(match.end).trim();
      if (remainder.isNotEmpty) {
        number = '$number $remainder'.trim();
      }
      if (name.isEmpty) name = null;
    } else {
      name = trimmed;
    }

    return _buildContactPills(name, number);
  }

  List<Widget> _buildContactPills(String? name, String? number) {
    final pills = <Widget>[];
    if (name != null && name.isNotEmpty) {
      pills.add(
        _buildInfoPill(
          Icons.person_outline,
          name,
          background: const Color.fromRGBO(232, 245, 233, 1),
          iconColor: const Color(0xFF2E7D32),
          textColor: const Color(0xFF1B5E20),
        ),
      );
    }
    if (number != null && number.isNotEmpty) {
      pills.add(
        _buildInfoPill(
          Icons.phone_outlined,
          number,
          background: const Color.fromRGBO(227, 242, 253, 1),
          iconColor: const Color(0xFF1565C0),
          textColor: const Color(0xFF0D47A1),
        ),
      );
    }
    return pills;
  }

  Widget _buildInfoPill(
    IconData icon,
    String label, {
    Color background = const Color(0xFFEDE7F6),
    Color iconColor = const Color(0xFF6B4791),
    Color textColor = const Color(0xFF422F5D),
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientButton({
    required String text,
    required VoidCallback onPressed,
    required IconData icon,
  }) {
    return SizedBox(
      height: 40,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [CompanyColors.accent, CompanyColors.secondary],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(30),
        ),
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 18, color: Colors.white),
          label: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
      ),
    );
  }
}
