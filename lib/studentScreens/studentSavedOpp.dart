import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:my_app/models/company.dart'; // Added import
import 'package:my_app/models/opportunity.dart';
import 'package:my_app/services/authService.dart'; // Added import
import 'package:my_app/services/bookmarkService.dart';

class SavedstudentOppPgae extends StatefulWidget {
  final String studentId;
  const SavedstudentOppPgae({super.key, required this.studentId});

  @override
  State<SavedstudentOppPgae> createState() => _SavedstudentOppPgaeState();
}

class _SavedstudentOppPgaeState extends State<SavedstudentOppPgae> {
  // Services needed for the integrated card UI
  final BookmarkService _bookmarkService = BookmarkService();
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Saved Opportunities',
          style: GoogleFonts.lato(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: StreamBuilder<List<Opportunity>>(
        stream: _bookmarkService.getBookmarkedOpportunitiesStream(
          studentId: widget.studentId,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF422F5D)),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading saved opportunities.',
                style: GoogleFonts.lato(color: Colors.red),
              ),
            );
          }

          final savedOpportunities = snapshot.data ?? [];

          if (savedOpportunities.isEmpty) {
            return _buildEmptyState();
          }

          // The ListView now calls a local method to build the card
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: savedOpportunities.length,
            itemBuilder: (context, index) {
              return _buildOpportunityCard(savedOpportunities[index]);
            },
          );
        },
      ),
    );
  }

  // --- UI for Empty State ---
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.bookmark_remove_outlined,
            size: 60,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            'No Saved Opportunities',
            style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your saved items will appear here.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // --- Integrated Card UI Logic (from the deleted StudentOppCard) ---

  Future<void> _toggleBookmark(Opportunity opportunity) async {
    // On this screen, a toggle will always be a "remove" action.
    try {
      await _bookmarkService.removeBookmark(
        studentId: widget.studentId,
        opportunityId: opportunity.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Removed from saved opportunities.'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update bookmark.')),
        );
      }
    }
  }

  Widget _buildOpportunityCard(Opportunity opportunity) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FutureBuilder<Company?>(
                  future: _authService.getCompany(opportunity.companyId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.grey,
                      );
                    }
                    final company = snapshot.data!;
                    return CircleAvatar(
                      radius: 25,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage:
                          (company.logoUrl != null &&
                              company.logoUrl!.isNotEmpty)
                          ? NetworkImage(company.logoUrl!)
                          : null,
                      child:
                          (company.logoUrl == null || company.logoUrl!.isEmpty)
                          ? const Icon(Icons.business, color: Colors.grey)
                          : null,
                    );
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        opportunity.role,
                        style: GoogleFonts.lato(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        opportunity.name,
                        style: GoogleFonts.lato(
                          fontSize: 15,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.bookmark,
                    color: Color(0xFF422F5D),
                  ), // Always bookmarked on this screen
                  onPressed: () => _toggleBookmark(opportunity),
                  tooltip: 'Remove Bookmark',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: [
                if (opportunity.location != null)
                  _buildInfoChip(
                    Icons.location_on_outlined,
                    opportunity.location!,
                  ),
                if (opportunity.workMode != null)
                  _buildInfoChip(Icons.work_outline, opportunity.workMode!),
                _buildInfoChip(
                  Icons.attach_money,
                  opportunity.isPaid ? 'Paid' : 'Unpaid',
                  color: opportunity.isPaid ? Colors.green : Colors.orange,
                ),
                // Show response deadline to students when the company enabled visibility
                if (opportunity.responseDeadlineVisible == true &&
                    opportunity.responseDeadline != null)
                  _buildInfoChip(
                    Icons.event_available,
                    'Respond by ${DateFormat('MMM d, yyyy').format(opportunity.responseDeadline!.toDate())}',
                    color: Colors.blueGrey,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, {Color? color}) {
    final chipColor = color ?? const Color(0xFF422F5D);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: chipColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.lato(
              color: chipColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
