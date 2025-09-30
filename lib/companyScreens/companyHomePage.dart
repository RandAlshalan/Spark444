import 'package:flutter/material.dart';
import '../models/company.dart';
import '../models/opportunity.dart';
import '../services/authService.dart';
import '../services/opportunityService.dart';
import 'editCompanyProfilePage.dart';
import 'PostOpportunityPage.dart';
import '../studentScreens/welcomeScreen.dart';

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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _fetchCompanyData();
  }

  /*Future<void> _fetchCompanyData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final company = await _authService.getCurrentCompany();
      final opportunities = await _opportunityService.getCompanyOpportunities(
        company?.uid ?? '',
      );
      setState(() {
        _company = company;
        _opportunities = opportunities;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error fetching data: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }*/

  // In lib/companyScreens/companyHomePage.dart

  // In lib/companyScreens/companyHomePage.dart

  Future<void> _fetchCompanyData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final company = await _authService.getCurrentCompany();

      print('DEBUG(CompanyHomePage): _fetchCompanyData started.');
      print(
        'DEBUG(CompanyHomePage): Fetched Company: ${company?.companyName ?? "N/A"}',
      );
      // NOW WE ARE RELYING ON THE EMAIL FROM THE COMPANY OBJECT
      print(
        'DEBUG(CompanyHomePage): Company Email (from authService): ${company?.email ?? "N/A - Company Email is null"}',
      );
      // For debugging purposes, you can still print UID to see it's there as a field, but not used as identifier
      print(
        'DEBUG(CompanyHomePage): Company Firebase Auth UID (from company object as field): ${company?.uid ?? "N/A - Company UID field is null"}',
      );

      // ************** CRITICAL CHANGE HERE **************
      // Use the company's UID to fetch opportunities for consistency.
      final opportunities = await _opportunityService.getCompanyOpportunities(
        company?.uid ?? '', // <-- Use UID to fetch opportunities
      );
      // **************************************************

      print(
        'DEBUG(CompanyHomePage): Number of opportunities received from service: ${opportunities.length}',
      );
      if (opportunities.isNotEmpty) {
        print(
          'DEBUG(CompanyHomePage): First opportunity name: ${opportunities.first.name}',
        );
        print(
          'DEBUG(CompanyHomePage): First opportunity companyId (should be email): ${opportunities.first.companyId}',
        );
        print(
          'DEBUG(CompanyHomePage): First opportunity ID: ${opportunities.first.id}',
        );
        print(
          'DEBUG(CompanyHomePage): First opportunity postedDate: ${opportunities.first.postedDate}',
        );
      } else {
        print('DEBUG(CompanyHomePage): No opportunities found.');
      }

      setState(() {
        _company = company;
        _opportunities = opportunities;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error fetching data: $e')));
      }
      print('DEBUG(CompanyHomePage): Error in _fetchCompanyData: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      print(
        'DEBUG(CompanyHomePage): _fetchCompanyData finished. _isLoading: $_isLoading',
      );
    }
  }

  void _navigateToPostOpportunityPage() async {
    print('DEBUG: Post New button pressed!');
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PostOpportunityPage()),
    );
    // After returning from PostOpportunityPage, refresh the list of opportunities
    _fetchCompanyData();
  }

  Future<void> _deleteOpportunity(String opportunityId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Opportunity'),
        content: const Text(
          'Are you sure you want to permanently delete this opportunity?',
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Opportunity deleted successfully.')),
        );
        _fetchCompanyData(); // Refresh the list
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting opportunity: $e')),
        );
      }
    }
  }

  Future<void> _showDeleteConfirmationDialog() async {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    // Close the drawer before showing the dialog
    Navigator.of(context).pop();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Account Permanently?'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'This action is irreversible. All your data, including posted opportunities, will be deleted. Please enter your password to confirm.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    return null;
                  },
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
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        print('DEBUG: _showDeleteConfirmationDialog: User confirmed deletion. Attempting to delete account.');
        await _authService.deleteCompanyAccount(passwordController.text);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Account deleted successfully.'),
                duration: Duration(seconds: 4),
            ),
          );
          print('DEBUG: _showDeleteConfirmationDialog: Account deletion successful. Navigating to WelcomeScreen.');
          // Use pushAndRemoveUntil to clear the navigation stack and go to the welcome screen
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const WelcomeScreen()),
            (route) => false, // This predicate ensures all previous routes are removed
          );
        } else {
          print('DEBUG: _showDeleteConfirmationDialog: Widget is not mounted after successful deletion, cannot show SnackBar or navigate.');
        }
      } catch (e) {
        print('DEBUG: _showDeleteConfirmationDialog: Error caught during account deletion: $e');
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(
            SnackBar(
                content: Text(e.toString().replaceFirst('Exception: ', '')), // Display the descriptive message
                duration: Duration(seconds: 8),
            ),
          );
        }
      }
    } else {
      print('DEBUG: _showDeleteConfirmationDialog: Delete action cancelled by user or form validation failed.');
    }
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
      expandedHeight: 250.0,
      pinned: true,
      floating: false,
      leading: IconButton(
        icon: const Icon(Icons.menu, color: Color(0xFF422F5D)),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: false,
        titlePadding: const EdgeInsets.only(left: 16.0, bottom: 16.0),
        title: _buildCompanyInfoRow(),
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
    return Padding(
      padding: const EdgeInsets.only(top: 80, left: 20, right: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.white,
                backgroundImage: _company?.logoUrl != null
                    ? NetworkImage(_company!.logoUrl!)
                    : const AssetImage('assets/spark_logo.png') as ImageProvider,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _company?.sector ?? 'Sector Not Specified',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context)
                      .push(
                        MaterialPageRoute(
                          builder: (_) => EditCompanyProfilePage(company: _company!),
                        ),
                      )
                      .then((_) => _fetchCompanyData());
                },
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Edit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.2),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _company?.description ?? 'No description available.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.8),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyInfoRow() {
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: Colors.white,
          backgroundImage: _company?.logoUrl != null
              ? NetworkImage(_company!.logoUrl!)
              : const AssetImage('assets/spark_logo.png') as ImageProvider,
        ),
        const SizedBox(width: 8),
        Text(
          _company?.companyName ?? 'Company Name',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildOpportunitySection() {
    return SliverList(
      delegate: SliverChildListDelegate([
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
            /*_buildGradientButton(
                text: 'Post New',
                onPressed: () {
                  // Dummy navigation for now
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Navigating to Create Opportunity Page...')),
                  );
                },
                icon: Icons.add,
              ),*/
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
        ..._opportunities.map((opportunity) {
          return _buildOpportunityCard(opportunity);
        }).toList(),
      ]),
    );
  }

  Widget _buildOpportunityCard(Opportunity opportunity) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      opportunity.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF422F5D),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      opportunity.role,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFFD64483),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                // Placeholder for applicants count
                const Icon(
                  Icons.people_alt_outlined,
                  color: Colors.grey,
                  size: 20,
                ),
              ],
            ),
            const Divider(height: 24),
            // --- New Info Rows ---
            _buildInfoRow(
              Icons.business_center_outlined,
              // Combine workMode and location for a clear display
              '${opportunity.workMode ?? opportunity.type}'
              '${(opportunity.workMode != 'Remote' && opportunity.location != null) ? ' - ${opportunity.location}' : ''}',
            ),
            if (opportunity.preferredMajor != null)
              _buildInfoRow(Icons.school_outlined, opportunity.preferredMajor!),
            _buildInfoRow(
              opportunity.isPaid
                  ? Icons.paid_outlined
                  : Icons.money_off_outlined,
              opportunity.isPaid ? 'Paid' : 'Unpaid',
              color: opportunity.isPaid
                  ? Colors.green.shade700
                  : Colors.red.shade700,
            ),
            // --- Skills Section ---
            if (opportunity.skills != null &&
                opportunity.skills!.isNotEmpty) ...[
              const SizedBox(height: 12),
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
                        backgroundColor: const Color(
                          0xFF422F5D,
                        ).withOpacity(0.1),
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
            const SizedBox(height: 10),
            // --- Action Buttons ---
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Viewing applicants for ${opportunity.name}',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.people_outline, size: 20),
                  label: const Text('View Applicants'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF6B4791),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blueGrey),
                  tooltip: 'Edit Opportunity',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Editing ${opportunity.name}')),
                    );
                    // TODO: Navigate to PostOpportunityPage with opportunity data
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: 'Delete Opportunity',
                  onPressed: () => _deleteOpportunity(opportunity.id),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color ?? Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color ?? Colors.grey.shade800,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
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
                    backgroundImage: _company?.logoUrl != null
                        ? NetworkImage(_company!.logoUrl!)
                        : const AssetImage('assets/spark_logo.png')
                              as ImageProvider,
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
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            _buildDrawerItem(Icons.group_outlined, 'My Followers', () {
              // Dummy navigation
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Navigating to Followers Page...'),
                ),
              );
              Navigator.of(context).pop();
            }),
            _buildDrawerItem(
              Icons.post_add_outlined,
              'Post a New Opportunity',
              () {
                Navigator.of(context).pop(); // Close drawer first
                _navigateToPostOpportunityPage(); // <--- DIRECT NAVIGATION HERE
              },
            ),

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
              if (mounted) {
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/', (route) => false);
              }
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