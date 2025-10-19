import 'package:flutter/material.dart';
import '../models/company.dart';
import '../models/opportunity.dart';
import '../services/authService.dart';
import '../services/opportunityService.dart';
import 'editCompanyProfilePage.dart';
import 'PostOpportunityPage.dart';
import 'opportunityAnalyticsPage.dart';
import 'allApplicantsPage.dart';
import 'company_theme.dart';
import '../studentScreens/welcomeScreen.dart';
import 'package:intl/intl.dart';

class CompanyHomePage extends StatefulWidget {
  const CompanyHomePage({super.key});

  @override
  _CompanyHomePageState createState() => _CompanyHomePageState();
}

class _CompanyHomePageState extends State<CompanyHomePage> {
  final AuthService _authService = AuthService();
  final OpportunityService _opportunityService = OpportunityService();
  Company? _company;
  List<Opportunity> _opportunities = [];
  bool _isLoading = true;
  final double _headerHeight = 20.0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _fetchCompanyData();
  }

  Future<void> _fetchCompanyData() async {
    setState(() => _isLoading = true);
    try {
      final company = await _authService.getCurrentCompany();
      final opportunities = await _opportunityService.getCompanyOpportunities(
        company?.uid ?? '',
      );

      if (!mounted) return;
      setState(() {
        _company = company;
        _opportunities = opportunities;
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
      MaterialPageRoute(builder: (context) => const PostOpportunityPage()),
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
      MaterialPageRoute(
        builder: (_) =>
            AllApplicantsPage(company: company, opportunity: opportunity),
      ),
    );
    if (!mounted) return;
    _fetchCompanyData();
  }

  Future<void> _navigateToAnalytics(Opportunity opportunity) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OpportunityAnalyticsPage(opportunity: opportunity),
      ),
    );
    if (!mounted) return;
    _fetchCompanyData();
  }

  Future<void> _navigateToAllApplicants() async {
    final company = _company;
    if (company == null) {
      _showSnackBar('Company information is still loading. Please try again.');
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AllApplicantsPage(company: company)),
    );
    if (!mounted) return;
    _fetchCompanyData();
  }

  Future<void> _deleteOpportunity(String opportunityId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Opportunity'),
        content: const SingleChildScrollView(
          child: Text(
            'Are you sure you want to permanently delete this opportunity?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _opportunityService.deleteOpportunity(opportunityId);
        if (!mounted) return;
        _showSnackBar('Opportunity deleted successfully.');
        _fetchCompanyData();
      } catch (e) {
        if (!mounted) return;
        _showSnackBar('Error deleting opportunity: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFEFE8E2), // Updated background color
      drawer: _buildDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                _buildSliverAppBar(),
                SliverPadding(
                  padding: const EdgeInsets.all(16.0),
                  sliver: _buildOpportunitySection(),
                ),
              ],
            ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      backgroundColor: const Color(0xFFEFE8E2),
      expandedHeight: _headerHeight,
      pinned: true,
      floating: false,
      leading: IconButton(
        icon: const Icon(Icons.menu, color: Color(0xFF422F5D)),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: false,
        titlePadding: const EdgeInsets.only(left: 16.0, bottom: 16.0),
        title: null,
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF99D46), Color(0xFFD64483)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: _buildProfileHeaderContent(),
        ),
      ),
    );
  }

  Widget _buildProfileHeaderContent() {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          margin: const EdgeInsets.only(top: 6),
          constraints: const BoxConstraints(maxWidth: 90),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.35)),
          ),
          child: const Text(
            'Profile',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
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
      color: const Color(0xFFFBFAFF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 4,
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
                  backgroundColor: const Color(0xFFEDE7F6),
                  backgroundImage:
                      company.logoUrl != null && company.logoUrl!.isNotEmpty
                      ? NetworkImage(company.logoUrl!)
                      : null,
                  child: (company.logoUrl == null || company.logoUrl!.isEmpty)
                      ? const Icon(
                          Icons.apartment_outlined,
                          color: Color(0xFF6B4791),
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
                          color: Color(0xFF422F5D),
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
                          color: Color(0xFF6B4791),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Color(0xFF6B4791)),
                  tooltip: 'Edit Company Profile',
                  onPressed: () {
                    Navigator.of(context)
                        .push(
                          MaterialPageRoute(
                            builder: (_) =>
                                EditCompanyProfilePage(company: _company!),
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
              background: const Color.fromRGBO(232, 234, 246, 1),
              iconColor: const Color(0xFF5E35B1),
              textColor: const Color(0xFF4527A0),
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 18),
              const Text(
                'About the company',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF422F5D),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF4A4A4A),
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOpportunitySection() {
    return SliverList(
      delegate: SliverChildListDelegate([
        if (_company != null) _buildCompanyInfoCard(),
        if (_company != null) const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'My Opportunities',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF422F5D),
              ),
            ),
            _buildGradientButton(
              text: 'Post New',
              icon: Icons.add,
              onPressed:
                  _navigateToPostOpportunityPage, // <--- DIRECT NAVIGATION HERE
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (_opportunities.isEmpty)
          const Center(
            child: Text(
              'You have not posted any opportunities yet.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
        ..._opportunities.map(_buildOpportunityCard),
      ]),
    );
  }

  Widget _buildOpportunityCard(Opportunity opportunity) {
    final postedDate = opportunity.postedDate?.toDate();
    final postedLabel = postedDate != null
        ? DateFormat('MMM d, yyyy').format(postedDate)
        : null;

    final metaChips = <Widget>[
      _buildMetaChip(Icons.badge_outlined, opportunity.type),
      if (opportunity.workMode != null &&
          opportunity.workMode!.trim().isNotEmpty)
        _buildMetaChip(
          Icons.apartment_outlined,
          _buildWorkModeLabel(opportunity),
        ),
      if (opportunity.preferredMajor != null &&
          opportunity.preferredMajor!.trim().isNotEmpty)
        _buildMetaChip(Icons.school_outlined, opportunity.preferredMajor!),
      _buildMetaChip(
        opportunity.isPaid
            ? Icons.payments_outlined
            : Icons.volunteer_activism_outlined,
        opportunity.isPaid ? 'Paid' : 'Unpaid',
        background: opportunity.isPaid
            ? const Color.fromRGBO(76, 175, 80, 0.14)
            : const Color.fromRGBO(244, 67, 54, 0.14),
        iconColor: opportunity.isPaid
            ? const Color(0xFF2E7D32)
            : const Color(0xFFC62828),
        textColor: opportunity.isPaid
            ? const Color(0xFF2E7D32)
            : const Color(0xFFC62828),
      ),
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF422F5D), Color(0xFFD64483)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  opportunity.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  opportunity.role,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color.fromRGBO(255, 255, 255, 0.85),
                  ),
                ),
                if (postedLabel != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule,
                        size: 16,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Posted $postedLabel',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(spacing: 10, runSpacing: 10, children: metaChips),
                if (opportunity.skills != null &&
                    opportunity.skills!.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const Text(
                    'Key Skills',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF422F5D),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 4.0,
                    children: opportunity.skills!
                        .map(
                          (skill) => Chip(
                            label: Text(
                              skill,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF422F5D),
                              ),
                            ),
                            backgroundColor: const Color.fromRGBO(
                              66,
                              47,
                              93,
                              0.12,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            side: BorderSide.none,
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: () => _navigateToApplicantsList(opportunity),
                    icon: const Icon(Icons.people_outline, size: 20),
                    label: const Text('View Applicants'),
                    style: TextButton.styleFrom(
                      foregroundColor: CompanyColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _navigateToAnalytics(opportunity),
                    icon: const Icon(Icons.auto_graph_outlined, size: 20),
                    label: const Text('Analytics'),
                    style: TextButton.styleFrom(
                      foregroundColor: CompanyColors.secondary,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blueGrey),
                    tooltip: 'Edit Opportunity',
                    onPressed: () => _showSnackBar(
                      'Editing ${opportunity.name} (coming soon)',
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Color(0xFFC62828)),
                    tooltip: 'Delete Opportunity',
                    onPressed: () => _deleteOpportunity(opportunity.id),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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

  Widget _buildMetaChip(
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

  String _buildWorkModeLabel(Opportunity opportunity) {
    final mode = (opportunity.workMode ?? opportunity.type).trim();
    final location = opportunity.location?.trim();

    if (mode.toLowerCase() == 'remote' ||
        location == null ||
        location.isEmpty) {
      return mode;
    }
    return '$mode · $location';
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        color: const Color(0xFF422F5D),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFF99D46), Color(0xFFD64483)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.white,
                    backgroundImage:
                        _company?.logoUrl != null &&
                            _company!.logoUrl!.isNotEmpty
                        ? NetworkImage(_company!.logoUrl!)
                        : null,
                    child:
                        (_company?.logoUrl == null ||
                            _company!.logoUrl!.isEmpty)
                        ? const Icon(
                            Icons.apartment_outlined,
                            color: Color(0xFF6B4791),
                            size: 32,
                          )
                        : null,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _company?.companyName ?? 'Company Name',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _company?.email ?? 'Email Not Found',
                    style: const TextStyle(
                      color: Color.fromRGBO(255, 255, 255, 0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            _buildDrawerItem(Icons.group_outlined, 'My Followers', () {
              _showSnackBar('Navigating to Followers Page...');
              Navigator.of(context).pop();
            }),
            _buildDrawerItem(
              Icons.post_add_outlined,
              'Post a New Opportunity',
              () {
                Navigator.of(context).pop();
                _navigateToPostOpportunityPage();
              },
            ),
            _buildDrawerItem(Icons.people_alt_outlined, 'All Applicants', () {
              Navigator.of(context).pop();
              _navigateToAllApplicants();
            }),

            _buildDrawerItem(Icons.edit_outlined, 'Edit Profile', () {
              Navigator.of(context).pop();
              Navigator.of(context)
                  .push(
                    MaterialPageRoute(
                      builder: (_) =>
                          EditCompanyProfilePage(company: _company!),
                    ),
                  )
                  .then((_) => _fetchCompanyData());
            }),
            const Divider(color: Colors.white54),
            _buildDrawerItem(
              Icons.delete_forever,
              'Delete Account',
              _showDeleteConfirmationDialog,
              color: Colors.red[300],
            ),
            _buildDrawerItem(Icons.logout, 'Log Out', () async {
              // Dummy logout action
              await _authService.signOut();
              if (!mounted) return;
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/', (route) => false);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    IconData icon,
    String title,
    VoidCallback onTap, {
    Color? color,
  }) {
    final itemColor = color ?? Colors.white;
    return ListTile(
      leading: Icon(icon, color: itemColor),
      title: Text(title, style: TextStyle(color: itemColor)),
      onTap: onTap,
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
            colors: [Color(0xFFF99D46), Color(0xFFD64483)],
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
