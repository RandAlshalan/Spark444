import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spark/services/fcm_token_manager.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../models/student.dart';
import '../models/opportunity.dart';
import '../models/bookmark.dart';
import '../services/authService.dart';
import '../services/opportunityService.dart';
import '../services/notification_helper.dart';
import '../widgets/CustomBottomNavBar.dart';
import 'studentCompaniesPage.dart';
import 'studentOppPage.dart';
import 'StudentChatPage.dart';
import 'studentViewProfile.dart';
import 'StudentNotificationsPage.dart';
import '../widgets/profile_completion_banner.dart';

// Color Constants
const Color _purple = Color(0xFF422F5D);
const Color _sparkOrange = Color(0xFFF99D46);
const Color _sparkPink = Color(0xFFD64483);
const Color _backgroundColor = Color(0xFFF8F9FA);
const Color _cardColor = Color(0xFFFFFFFF);
const Color _textColor = Color(0xFF1E1E1E);

class StudentHomePage extends StatefulWidget {
  const StudentHomePage({super.key});

  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage> {
  final AuthService _authService = AuthService();
  final OpportunityService _opportunityService = OpportunityService();

  Student? _student;
  bool _loading = true;
  List<Opportunity> _recentOpportunities = [];
  int _applicationCount = 0;
  int _bookmarkCount = 0;

  // Calendar state
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Opportunity>> _deadlineEvents = {};

  @override
  void initState() {
    super.initState();
    _loadData();
      FcmTokenManager.saveUserFcmToken();
  }


  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      // Load student data
      final student = await _authService.getCurrentStudent();

      // Load recent opportunities (last 5)
      final opportunities = await _opportunityService.getOpportunities();
      final recent = opportunities.take(5).toList();

      // Count applications
      int appCount = 0;
      if (student != null) {
        final appsSnapshot = await FirebaseFirestore.instance
            .collection('applications')
            .where('studentId', isEqualTo: student.id)
            .get();
        appCount = appsSnapshot.docs.length;
      }

      // Count bookmarks and load deadline events
      int bookmarkCount = 0;
      Map<DateTime, List<Opportunity>> deadlineEvents = {};

      if (student != null) {
        final bookmarksSnapshot = await FirebaseFirestore.instance
            .collection('bookmarks')
            .where('studentId', isEqualTo: student.id)
            .get();
        bookmarkCount = bookmarksSnapshot.docs.length;

        // Load bookmarked opportunities with deadlines
        for (var bookmarkDoc in bookmarksSnapshot.docs) {
          final bookmark = Bookmark.fromFirestore(bookmarkDoc);
          try {
            final oppDoc = await FirebaseFirestore.instance
                .collection('opportunities')
                .doc(bookmark.opportunityId)
                .get();

            if (oppDoc.exists) {
              final opp = Opportunity.fromFirestore(oppDoc);
              if (opp.applicationDeadline != null) {
                final deadlineDate = DateTime(
                  opp.applicationDeadline!.toDate().year,
                  opp.applicationDeadline!.toDate().month,
                  opp.applicationDeadline!.toDate().day,
                );

                if (deadlineEvents[deadlineDate] == null) {
                  deadlineEvents[deadlineDate] = [];
                }
                deadlineEvents[deadlineDate]!.add(opp);
              }
            }
          } catch (e) {
            debugPrint('Error loading opportunity ${bookmark.opportunityId}: $e');
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _student = student;
        _recentOpportunities = recent;
        _applicationCount = appCount;
        _bookmarkCount = bookmarkCount;
        _deadlineEvents = deadlineEvents;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading home data: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _onNavigationTap(int index) {
    if (!mounted) return;
    if (index == 0) return; // Already on home

    switch (index) {
      case 1: // Companies
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const StudentCompaniesPage()),
        );
        break;
      case 2: // Chatbot
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => StudentChatPage()),
        );
        break;
      case 3: // Opportunities
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => studentOppPgae()),
        );
        break;
      case 4: // Profile
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const StudentViewProfile()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: _purple,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: Text(
          'Home',
          style: GoogleFonts.lato(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_student != null)
            StreamBuilder<int>(
              stream: NotificationHelper().getUnreadCountStream(_student!.id),
              builder: (context, snapshot) {
                final unreadCount = snapshot.data ?? 0;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.notifications_outlined,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const StudentNotificationsPage(),
                          ),
                        );
                      },
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                            style: GoogleFonts.lato(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: _purple,
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              color: _purple,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderSection(),
                    const SizedBox(height: 20),
                    const ProfileCompletionBanner(),
                    const SizedBox(height: 20),
                    _buildStatsSection(),
                    const SizedBox(height: 24),
                    if (_deadlineEvents.isNotEmpty) ...[
                      _buildDeadlineCalendarSection(),
                      const SizedBox(height: 24),
                    ],
                    _buildQuickActionsSection(),
                    const SizedBox(height: 24),
                    _buildRecentOpportunitiesSection(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: 0,
        onTap: _onNavigationTap,
      ),
    );
  }

  Widget _buildHeaderSection() {
    final firstName = _student?.firstName ?? 'Student';
    final greeting = _getGreeting();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_purple, _sparkPink],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$greeting,',
            style: GoogleFonts.lato(
              color: Colors.white.withOpacity(0.9),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            firstName,
            style: GoogleFonts.lato(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Ready to explore new opportunities?',
            style: GoogleFonts.lato(
              color: Colors.white.withOpacity(0.85),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Activity',
            style: GoogleFonts.lato(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.work_outline,
                  label: 'Applications',
                  count: _applicationCount.toString(),
                  color: _purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.bookmark_border,
                  label: 'Saved',
                  count: _bookmarkCount.toString(),
                  color: _sparkOrange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            count,
            style: GoogleFonts.lato(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.lato(
              fontSize: 14,
              color: _textColor.withOpacity(0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeadlineCalendarSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Application Deadlines',
            style: GoogleFonts.lato(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                TableCalendar(
                  firstDay: DateTime.now().subtract(const Duration(days: 365)),
                  lastDay: DateTime.now().add(const Duration(days: 365)),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  calendarFormat: CalendarFormat.month,
                  startingDayOfWeek: StartingDayOfWeek.sunday,
                  eventLoader: (day) {
                    final normalizedDay = DateTime(day.year, day.month, day.day);
                    return _deadlineEvents[normalizedDay] ?? [];
                  },
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: _sparkOrange.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: const BoxDecoration(
                      color: _purple,
                      shape: BoxShape.circle,
                    ),
                    markerDecoration: const BoxDecoration(
                      color: _sparkPink,
                      shape: BoxShape.circle,
                    ),
                    markersMaxCount: 3,
                    outsideDaysVisible: false,
                  ),
                  headerStyle: HeaderStyle(
                    titleCentered: true,
                    formatButtonVisible: false,
                    titleTextStyle: GoogleFonts.lato(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _textColor,
                    ),
                    leftChevronIcon: const Icon(Icons.chevron_left, color: _purple),
                    rightChevronIcon: const Icon(Icons.chevron_right, color: _purple),
                  ),
                  daysOfWeekStyle: DaysOfWeekStyle(
                    weekdayStyle: GoogleFonts.lato(
                      fontWeight: FontWeight.w600,
                      color: _textColor.withOpacity(0.7),
                    ),
                    weekendStyle: GoogleFonts.lato(
                      fontWeight: FontWeight.w600,
                      color: _sparkPink.withOpacity(0.7),
                    ),
                  ),
                ),
                if (_selectedDay != null && _deadlineEvents[DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day)] != null) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  Text(
                    'Deadlines on ${DateFormat('MMM d, y').format(_selectedDay!)}',
                    style: GoogleFonts.lato(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _sparkOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _sparkOrange.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          color: _sparkOrange,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Remember to apply before the deadline closes!',
                            style: GoogleFonts.lato(
                              fontSize: 12,
                              color: _textColor.withOpacity(0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...(_deadlineEvents[DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day)]!.map((opp) {
                    final deadline = opp.applicationDeadline!.toDate();
                    final timeLeft = deadline.difference(DateTime.now());
                    final isUrgent = timeLeft.inDays < 3;
                    final isPast = timeLeft.isNegative;

                    // Calculate time remaining text
                    String timeRemainingText = '';
                    if (!isPast) {
                      if (timeLeft.inDays > 0) {
                        timeRemainingText = '${timeLeft.inDays} day${timeLeft.inDays == 1 ? '' : 's'} left';
                      } else if (timeLeft.inHours > 0) {
                        timeRemainingText = '${timeLeft.inHours} hour${timeLeft.inHours == 1 ? '' : 's'} left';
                      } else if (timeLeft.inMinutes > 0) {
                        timeRemainingText = '${timeLeft.inMinutes} minute${timeLeft.inMinutes == 1 ? '' : 's'} left';
                      } else {
                        timeRemainingText = 'Closing soon!';
                      }
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isUrgent
                            ? _sparkPink.withOpacity(0.1)
                            : _purple.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isUrgent
                              ? _sparkPink.withOpacity(0.3)
                              : _purple.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.work_outline,
                            color: isUrgent ? _sparkPink : _purple,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  opp.role,
                                  style: GoogleFonts.lato(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: _textColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Closes at ${DateFormat.jm().format(deadline)}',
                                  style: GoogleFonts.lato(
                                    fontSize: 11,
                                    color: _textColor.withOpacity(0.5),
                                  ),
                                ),
                                if (!isPast) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isUrgent
                                          ? _sparkPink.withOpacity(0.2)
                                          : _purple.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      timeRemainingText,
                                      style: GoogleFonts.lato(
                                        fontSize: 11,
                                        color: isUrgent ? _sparkPink : _purple,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (!isPast)
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 14,
                              color: _textColor.withOpacity(0.3),
                            ),
                        ],
                      ),
                    );
                  }).toList()),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: GoogleFonts.lato(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.business_outlined,
                  label: 'Browse Companies',
                  color: _purple,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const StudentCompaniesPage(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.work_outline,
                  label: 'Find Opportunities',
                  color: _sparkPink,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => studentOppPgae()),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lato(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentOpportunitiesSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Opportunities',
                style: GoogleFonts.lato(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _textColor,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => studentOppPgae()),
                  );
                },
                child: Text(
                  'View All',
                  style: GoogleFonts.lato(
                    color: _purple,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _recentOpportunities.isEmpty
              ? _buildEmptyOpportunities()
              : Column(
                  children: _recentOpportunities
                      .map((opp) => _buildOpportunityCard(opp))
                      .toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildEmptyOpportunities() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.work_outline,
            size: 48,
            color: _textColor.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No opportunities yet',
            style: GoogleFonts.lato(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _textColor.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for new opportunities',
            textAlign: TextAlign.center,
            style: GoogleFonts.lato(
              fontSize: 14,
              color: _textColor.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpportunityCard(Opportunity opportunity) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Navigate to opportunity details
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => studentOppPgae()),
            );
          },
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        opportunity.role,
                        style: GoogleFonts.lato(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (opportunity.isPaid)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Paid',
                          style: GoogleFonts.lato(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.business_outlined,
                      size: 14,
                      color: _textColor.withOpacity(0.6),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        opportunity.name,
                        style: GoogleFonts.lato(
                          fontSize: 13,
                          color: _textColor.withOpacity(0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: _textColor.withOpacity(0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      opportunity.location ?? 'Not specified',
                      style: GoogleFonts.lato(
                        fontSize: 13,
                        color: _textColor.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.work_outline,
                      size: 14,
                      color: _textColor.withOpacity(0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      opportunity.type,
                      style: GoogleFonts.lato(
                        fontSize: 13,
                        color: _textColor.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
