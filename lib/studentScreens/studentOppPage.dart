// lib/studentScreens/studentOppPage.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:my_app/models/company.dart';
import 'package:my_app/models/opportunity.dart';
import 'package:my_app/services/authService.dart';
import 'package:my_app/services/bookmarkService.dart';
import 'package:my_app/services/opportunityService.dart';
import '../studentScreens/studentViewProfile.dart'; // For navigation
import '../widgets/CustomBottomNavBar.dart'; // For the navigation bar
import '../studentScreens/studentSavedOpp.dart';

// Enum for clearer state management
enum ScreenState { initialLoading, loading, success, error, empty }

class studentOppPgae extends StatefulWidget {
  const studentOppPgae({super.key});
  @override
  State<studentOppPgae> createState() => _studentOppPgaeState();
}

class _studentOppPgaeState extends State<studentOppPgae> {
  // Services
  final OpportunityService _opportunityService = OpportunityService();
  final AuthService _authService = AuthService();
  final BookmarkService _bookmarkService = BookmarkService();

  // Controllers
  final _searchController = TextEditingController();
  final _cityController = TextEditingController();

  // State variables
  List<Opportunity> _opportunities = [];
  ScreenState _state = ScreenState.initialLoading;
  String? _errorMessage;
  String? _studentId;
  Timer? _debounce;
  int _currentIndex = 2; // Set to 2 for the "Opportunities" page

  // Filter state variables
  String _activeTypeFilter = 'All';
  String? _selectedCity;
  String? _selectedLocationType;
  bool? _isPaid;
  String? _selectedDuration;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _cityController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _fetchOpportunities);
  }

  Future<void> _loadInitialData() async {
    setState(() => _state = ScreenState.initialLoading);
    try {
      final student = await _authService.getCurrentStudent();
      if (!mounted) return;
      if (student != null) {
        setState(() => _studentId = student.id);
        await _fetchOpportunities();
      } else {
        throw Exception("Could not find logged in student.");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Error: ${e.toString()}";
          _state = ScreenState.error;
        });
      }
    }
  }

  String getDurationCategory(dynamic start, dynamic end) {
    if (start == null || end == null) return "Unknown";
    final DateTime startDate = start is DateTime ? start : (start as dynamic).toDate();
    final DateTime endDate = end is DateTime ? end : (end as dynamic).toDate();
    final durationDays = endDate.difference(startDate).inDays;
    if (durationDays < 30) return "less than a month";
    if (durationDays >= 30 && durationDays < 90) return "1-3 months";
    if (durationDays >= 90 && durationDays < 180) return "3-6 months";
    return "more than 6 months";
  }

  Future<void> _fetchOpportunities() async {
    if (_state != ScreenState.initialLoading) {
      setState(() => _state = ScreenState.loading);
    }
    try {
      // Fetch all opportunities from service
      final opportunities = await _opportunityService.getOpportunities(
        searchQuery: null,
        type: null,
        city: null,
        locationType: null,
        isPaid: null,
      );

      final query = _searchController.text.toLowerCase();
      final filtered = opportunities.where((opp) {
        final matchesType = _activeTypeFilter == 'All' || opp.type == _activeTypeFilter;
        final matchesSearch = query.isEmpty ||
            opp.role.toLowerCase().contains(query) ||
            opp.name.toLowerCase().contains(query);
        final matchesCity = _selectedCity == null ||
            (opp.location?.toLowerCase() == _selectedCity?.toLowerCase());
        final matchesLocation = _selectedLocationType == null ||
            (opp.workMode?.toLowerCase() == _selectedLocationType?.toLowerCase());
        final matchesPaid = _isPaid == null || (opp.isPaid == _isPaid);
        final durationCategory = getDurationCategory(opp.startDate, opp.endDate);
        final matchesDuration = _selectedDuration == null || durationCategory == _selectedDuration;

        return matchesType && matchesSearch && matchesCity && matchesLocation && matchesPaid && matchesDuration;
      }).toList();

      if (mounted) {
        setState(() {
          _opportunities = filtered;
          _state = filtered.isEmpty ? ScreenState.empty : ScreenState.success;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load opportunities.';
          _state = ScreenState.error;
        });
      }
    }
  }

  Future<void> _toggleBookmark(Opportunity opportunity, bool isCurrentlyBookmarked) async {
    if (_studentId == null || _studentId!.isEmpty) return;
    try {
      if (isCurrentlyBookmarked) {
        await _bookmarkService.removeBookmark(studentId: _studentId!, opportunityId: opportunity.id);
      } else {
        await _bookmarkService.addBookmark(studentId: _studentId!, opportunityId: opportunity.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not update bookmark.')));
      }
    }
  }

  void _resetAllFilters() {
    setState(() {
      _cityController.clear();
      _selectedCity = null;
      _selectedLocationType = null;
      _isPaid = null;
      _selectedDuration = null;
      _activeTypeFilter = 'All';
      _searchController.clear();
    });
    _fetchOpportunities();
  }

  // --- Navigation Logic ---
  void _showInfoMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.lato()),
        backgroundColor: const Color(0xFF422F5D),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _onNavigationTap(int index) {
    if (index == _currentIndex) return; // Do nothing if already on this page

    switch (index) {
      case 0: // Home
        _showInfoMessage('Home page coming soon!');
        break;
      case 1: // Companies
        _showInfoMessage('Companies page coming soon!');
        break;
      case 2: // Opportunities
        // This is the current page, so the check at the top handles it.
        break;
      case 3: // Profile
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
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Opportunities', style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.filter_list), onPressed: _showFilterSheet, tooltip: 'Filter'),
          IconButton(icon: const Icon(Icons.bookmarks_outlined), onPressed: _navigateToSaved, tooltip: 'Saved'),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildTypeFilterChips(),
          _buildActiveFiltersBar(),
          Expanded(child: _buildContent()),
        ],
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onNavigationTap,
      ),
    );
  }

  // --- UI Components ---
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by role or company...',
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide.none
          ),
        ),
      ),
    );
  }

  Widget _buildTypeFilterChips() {
    final types = ['All', 'Internship', 'Co-op', 'Graduate Program', 'Bootcamp'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: types.length,
          itemBuilder: (context, index) {
            final type = types[index];
            final isSelected = _activeTypeFilter == type;
            return ChoiceChip(
              label: Text(type),
              selected: isSelected,
              onSelected: (_) {
                setState(() => _activeTypeFilter = type);
                _fetchOpportunities();
              },
              selectedColor: const Color(0xFF422F5D),
              labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
              backgroundColor: Colors.white,
            );
          },
          separatorBuilder: (_, __) => const SizedBox(width: 8),
        ),
      ),
    );
  }

  Widget _buildDurationFilterChips() {
    final durations = ["less than a month", "1-3 months", "3-6 months", "more than 6 months"];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: durations.length,
          itemBuilder: (context, index) {
            final duration = durations[index];
            final isSelected = _selectedDuration == duration;
            return ChoiceChip(
              label: Text(duration),
              selected: isSelected,
              onSelected: (_) {
                setState(() => _selectedDuration = isSelected ? null : duration);
                _fetchOpportunities();
              },
              selectedColor: const Color(0xFF422F5D),
              labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
              backgroundColor: Colors.white,
            );
          },
          separatorBuilder: (_, __) => const SizedBox(width: 8),
        ),
      ),
    );
  }

  Widget _buildActiveFiltersBar() {
    final hasActiveFilters = _selectedCity != null || _selectedLocationType != null || _isPaid != null || _selectedDuration != null;
    if (!hasActiveFilters) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 4.0,
        children: [
          if (_selectedCity != null && _selectedCity!.isNotEmpty)
            Chip(
              label: Text('City: $_selectedCity'),
              onDeleted: () { setState(() => _selectedCity = null); _cityController.clear(); _fetchOpportunities(); },
            ),
          if (_selectedLocationType != null)
            Chip(
              label: Text(_selectedLocationType!.capitalize()),
              onDeleted: () { setState(() => _selectedLocationType = null); _fetchOpportunities(); },
            ),
          if (_isPaid != null)
            Chip(
              label: Text(_isPaid! ? 'Paid' : 'Unpaid'),
              backgroundColor: _isPaid! ? Colors.green.shade100 : Colors.orange.shade100,
              onDeleted: () { setState(() => _isPaid = null); _fetchOpportunities(); },
            ),
          if (_selectedDuration != null)
            Chip(
              label: Text(_selectedDuration!),
              onDeleted: () { setState(() => _selectedDuration = null); _fetchOpportunities(); },
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_state) {
      case ScreenState.initialLoading:
      case ScreenState.loading:
        return const Center(child: CircularProgressIndicator(color: Color(0xFF422F5D)));
      case ScreenState.error:
        return _buildErrorWidget();
      case ScreenState.empty:
        return _buildEmptyState();
      case ScreenState.success:
        return RefreshIndicator(
          onRefresh: _fetchOpportunities,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            itemCount: _opportunities.length,
            itemBuilder: (context, index) => _buildOpportunityCard(_opportunities[index]),
          ),
        );
    }
  }

  // --- Opportunity Card, Date, Chips UI (unchanged from your original code) ---
  Widget _buildOpportunityCard(Opportunity opportunity) {
    String formatDate(DateTime? date) {
      if (date == null) return 'N/A';
      return DateFormat('MMM d, yyyy').format(date);
    }

    final startDate = opportunity.startDate?.toDate();
    final endDate = opportunity.endDate?.toDate();
    final deadline = opportunity.applicationDeadline?.toDate();

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 3,
      shadowColor: Colors.black.withOpacity(0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          print("Tapped on card for ${opportunity.name}");
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FutureBuilder<Company?>(
                future: _authService.getCompany(opportunity.companyId),
                builder: (context, snapshot) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage: (snapshot.data?.logoUrl != null && snapshot.data!.logoUrl!.isNotEmpty) ? NetworkImage(snapshot.data!.logoUrl!) : null,
                        child: (snapshot.data?.logoUrl == null || snapshot.data!.logoUrl!.isEmpty) ? const Icon(Icons.business, color: Colors.grey) : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(opportunity.role, style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(snapshot.data?.companyName ?? "...", style: GoogleFonts.lato(fontSize: 14, color: Colors.grey.shade700)),
                          ],
                        ),
                      ),
                      if (_studentId != null)
                        StreamBuilder<bool>(
                          stream: _bookmarkService.isBookmarkedStream(studentId: _studentId!, opportunityId: opportunity.id),
                          builder: (context, snapshot) => IconButton(
                            icon: Icon(snapshot.data == true ? Icons.bookmark : Icons.bookmark_border, color: const Color(0xFF422F5D)),
                            onPressed: () => _toggleBookmark(opportunity, snapshot.data ?? false),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildDateInfo(Icons.calendar_today_outlined, 'Duration', '${formatDate(startDate)} - ${formatDate(endDate)}'),
                  const SizedBox(width: 16),
                  _buildDateInfo(Icons.event_available_outlined, 'Apply By', formatDate(deadline)),
                ],
              ),
              const SizedBox(height: 12),
              if (opportunity.description != null && opportunity.description!.isNotEmpty)
                Text(
                  opportunity.description!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.lato(color: Colors.black.withOpacity(0.65), height: 1.5),
                ),
              const Padding(padding: EdgeInsets.symmetric(vertical: 12.0), child: Divider()),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: [
                  _buildMetaChip(Icons.badge_outlined, opportunity.type),
                  if (opportunity.workMode != null) _buildMetaChip(Icons.apartment_outlined, _buildWorkModeLabel(opportunity)),
                  if (opportunity.preferredMajor != null) _buildMetaChip(Icons.school_outlined, opportunity.preferredMajor!),
                  _buildMetaChip(
                    Icons.attach_money,
                    opportunity.isPaid ? 'Paid' : 'Unpaid',
                    color: opportunity.isPaid ? Colors.green.shade700 : Colors.orange.shade800,
                  ),
                ],
              ),
              if (opportunity.skills != null && opportunity.skills!.isNotEmpty)
                _buildTitledChipList('Key Skills', opportunity.skills!),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () { print("Navigate to details for ${opportunity.name}"); },
                    child: const Text('View More', style: TextStyle(color: Color(0xFF422F5D), fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateInfo(IconData icon, String title, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(title, style: GoogleFonts.lato(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildTitledChipList(String title, List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF422F5D))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: items.map((item) => Chip(
              label: Text(item, style: const TextStyle(fontSize: 12, color: Color(0xFF422F5D))),
              backgroundColor: const Color.fromRGBO(66, 47, 93, 0.12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              side: BorderSide.none,
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaChip(IconData icon, String label, {Color? color}) {
    final chipColor = color ?? const Color(0xFF422F5D);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: chipColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: chipColor),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.lato(color: chipColor, fontWeight: FontWeight.w600, fontSize: 12)),
        ],
      ),
    );
  }

  String _buildWorkModeLabel(Opportunity opportunity) {
    final mode = (opportunity.workMode ?? opportunity.type).trim();
    final location = opportunity.location?.trim();
    if (mode.toLowerCase() == 'remote' || location == null || location.isEmpty) return mode;
    return '$mode · $location';
  }

  Widget _buildEmptyState() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.search_off, size: 80, color: Colors.grey),
      const SizedBox(height: 16),
      Text('No Opportunities Found', style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const Text('Try adjusting your search or filters.', style: TextStyle(color: Colors.grey)),
      const SizedBox(height: 20),
      ElevatedButton(onPressed: _resetAllFilters, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF422F5D), foregroundColor: Colors.white), child: const Text('Clear All Filters'))
    ]));
  }

  Widget _buildErrorWidget() {
    return Center(child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.cloud_off, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        Text('Something Went Wrong', style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(_errorMessage ?? "We couldn't load opportunities.", textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: _loadInitialData, child: const Text('Try Again'))
      ]),
    ));
  }

  void _navigateToSaved() {
    if (_studentId != null) Navigator.push(context, MaterialPageRoute(builder: (context) => SavedstudentOppPgae(studentId: _studentId!)));
  }

  void _showFilterSheet() {
    _cityController.text = _selectedCity ?? '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(builder: (BuildContext context, StateSetter setModalState) {
          Widget buildModalChips<T>({
            required List<T> options,
            required T? selectedValue,
            required String Function(T) labelBuilder,
            required Function(T?) onSelected,
          }) {
            return Wrap(
              spacing: 8.0,
              children: options.map((option) {
                final isSelected = selectedValue == option;
                return ChoiceChip(
                  label: Text(labelBuilder(option)),
                  selected: isSelected,
                  onSelected: (selected) => onSelected(selected ? option : null),
                  selectedColor: const Color(0xFF422F5D),
                  labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
                  backgroundColor: Colors.grey[200],
                );
              }).toList(),
            );
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Filters', style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                Text('City', style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                TextField(controller: _cityController, decoration: InputDecoration(hintText: 'e.g., Riyadh', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
                const SizedBox(height: 24),
                Text('Location Type', style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                buildModalChips<String>(
                  options: ['remote', 'in-person', 'hybrid'],
                  selectedValue: _selectedLocationType,
                  labelBuilder: (s) => s.capitalize(),
                  onSelected: (value) => setModalState(() => _selectedLocationType = value),
                ),
                const SizedBox(height: 24),
                Text('Payment', style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                buildModalChips<bool>(
                  options: [true, false],
                  selectedValue: _isPaid,
                  labelBuilder: (p) => p ? 'Paid' : 'Unpaid',
                  onSelected: (value) => setModalState(() => _isPaid = value),
                ),
                const SizedBox(height: 24),
                Text('Duration', style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                buildModalChips<String>(
                  options: ["less than a month", "1-3 months", "3-6 months", "more than 6 months"],
                  selectedValue: _selectedDuration,
                  labelBuilder: (d) => d,
                  onSelected: (value) => setModalState(() => _selectedDuration = value),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(child: OutlinedButton(onPressed: () => setModalState(() { _cityController.clear(); _selectedLocationType = null; _isPaid = null; _selectedDuration = null; }), child: const Text('Clear'))),
                    const SizedBox(width: 12),
                    Expanded(child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF422F5D), foregroundColor: Colors.white),
                      onPressed: () {
                        setState(() => _selectedCity = _cityController.text.trim().isEmpty ? null : _cityController.text.trim());
                        _fetchOpportunities();
                        Navigator.pop(context);
                      },
                      child: const Text('Apply Filters'),
                    ))
                  ],
                )
              ],
            ),
          );
        });
      }
    );
  }
}

// --- String Extension ---
extension StringExtension on String { 
  String capitalize() { if (isEmpty) return this; return "${this[0].toUpperCase()}${substring(1)}"; } 
}