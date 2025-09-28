import 'package:flutter/material.dart';
import '../models/company.dart';
import '../models/opportunity.dart';
import '../services/authService.dart';
import '../services/opportunityService.dart';
import 'editCompanyProfilePage.dart';
import 'PostOpportunityPage.dart';

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
      // Use company?.email to fetch opportunities, as per your preference
      final opportunities = await _opportunityService.getCompanyOpportunities(
        company?.email ??
            '', // <--- CHANGED FROM company?.uid to company?.email
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
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.white,
                backgroundImage: _company?.logoUrl != null
                    ? NetworkImage(_company!.logoUrl!)
                    : const AssetImage('assets/spark_logo.png')
                          as ImageProvider,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _company?.companyName ?? 'Company Name',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
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
          const SizedBox(height: 10),
          ElevatedButton.icon(
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
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('Edit Profile'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.2),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
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
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
                    const SizedBox(height: 5),
                    Text(
                      opportunity.role,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFFD64483),
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {}, // Dummy onPressed
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.people_alt_outlined,
                        color: Colors.grey,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${opportunity.applicants} Applicants',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: Colors.grey,
                ),
                const SizedBox(width: 5),
                Text(
                  opportunity.location,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  opportunity.isPaid
                      ? Icons.paid_outlined
                      : Icons.money_off_outlined,
                  size: 16,
                  color: opportunity.isPaid ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 5),
                Text(
                  opportunity.isPaid ? 'Paid' : 'Unpaid',
                  style: TextStyle(
                    color: opportunity.isPaid ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    // Dummy navigation
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Navigating to applicants for ${opportunity.name}',
                        ),
                      ),
                    );
                  },
                  child: const Text(
                    'View Applicants',
                    style: TextStyle(color: Color(0xFF6B4791)),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blueGrey),
                  onPressed: () {
                    // Dummy edit action
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Editing ${opportunity.name}')),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    // Dummy delete action
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Deleting ${opportunity.name}')),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
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

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(title, style: const TextStyle(color: Colors.white)),
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
