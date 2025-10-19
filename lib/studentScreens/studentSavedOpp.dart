import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:my_app/models/company.dart'; // Import Company model
import 'package:my_app/models/opportunity.dart';
import 'package:my_app/services/authService.dart'; // Import AuthService
import 'package:my_app/services/bookmarkService.dart';

// This widget defines the "Saved Opportunities" screen.
// It is a "StatefulWidget" because its content will change.
class SavedstudentOppPgae extends StatefulWidget {
  // It requires the student's ID to know whose bookmarks to fetch.
  final String studentId;
  const SavedstudentOppPgae({super.key, required this.studentId});

  @override
  State<SavedstudentOppPgae> createState() => _SavedstudentOppPgaeState();
}

// This class holds the "state" (the data and UI) for the screen.
class _SavedstudentOppPgaeState extends State<SavedstudentOppPgae> {
  // --- 1. Services ---
  // We need services to interact with our database (Firebase).

  // BookmarkService handles fetching and removing bookmarks.
  final BookmarkService _bookmarkService = BookmarkService();
  // AuthService handles fetching user/company data (like the company logo).
  final AuthService _authService = AuthService();

  // --- 2. Main Build Method ---

  @override
  Widget build(BuildContext context) {
    // Scaffold is the basic layout structure of the screen.
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Saved Opportunities',
          style: GoogleFonts.lato(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      // StreamBuilder automatically listens for changes in the database.
      // It will rebuild its content whenever the bookmarked opportunities change.
      body: StreamBuilder<List<Opportunity>>(
        // This is the "stream" we are listening to.
        stream: _bookmarkService.getBookmarkedOpportunitiesStream(
          studentId: widget.studentId, // We pass the student's ID here.
        ),
        // The "builder" decides what to show based on the stream's state.
        builder: (context, snapshot) {
          // --- Handle Loading State ---
          // While waiting for data, show a loading spinner.
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF422F5D)),
            );
          }

          // --- Handle Error State ---
          // If something goes wrong, show an error message.
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading saved opportunities.',
                style: GoogleFonts.lato(color: Colors.red),
              ),
            );
          }

          // --- Handle Empty State ---
          // If we have data, but the list is empty, show a message.
          final savedOpportunities = snapshot.data ?? [];
          if (savedOpportunities.isEmpty) {
            return _buildEmptyState(); // Call our helper widget
          }

          // --- Handle Success State ---
          // If we have data, build a ListView.
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: savedOpportunities.length,
            // For each item in the list, build an opportunity card.
            itemBuilder: (context, index) {
              return _buildOpportunityCard(savedOpportunities[index]);
            },
          );
        },
      ),
    );
  }

  // --- 3. Core UI Builders ---

  // This widget is shown when the list of saved opportunities is empty.
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

  // --- 4. Component Builders ---

  // This function builds a single card for an opportunity.
  // It was previously in its own file (StudentOppCard) but is now integrated here.
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
            // --- Card Header: Logo, Title, Bookmark Icon ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // FutureBuilder fetches the company data (logo) for this card.
                FutureBuilder<Company?>(
                  future: _authService.getCompany(opportunity.companyId),
                  builder: (context, snapshot) {
                    // Show a grey circle while loading company data
                    if (!snapshot.hasData) {
                      return const CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.grey,
                      );
                    }
                    // Once data is loaded, display the company logo
                    final company = snapshot.data!;
                    return CircleAvatar(
                      radius: 25,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: (company.logoUrl != null &&
                              company.logoUrl!.isNotEmpty)
                          ? NetworkImage(company.logoUrl!)
                          : null,
                      // Show a default icon if there is no logo URL
                      child:
                          (company.logoUrl == null || company.logoUrl!.isEmpty)
                              ? const Icon(Icons.business, color: Colors.grey)
                              : null,
                    );
                  },
                ),
                const SizedBox(width: 12),
                // Role and Opportunity Name
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
                        opportunity.name, // The name of the opportunity
                        style: GoogleFonts.lato(
                          fontSize: 15,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                // Bookmark Icon
                IconButton(
                  icon: const Icon(
                    Icons.bookmark, // Icon is "filled" because it's saved
                    color: Color(0xFF422F5D),
                  ),
                  // When pressed, call the toggle function to remove it
                  onPressed: () => _toggleBookmark(opportunity),
                  tooltip: 'Remove Bookmark',
                ),
              ],
            ),
            const SizedBox(height: 16),
            // --- Card Body: Info Chips ---
            // Wrap allows chips to move to the next line if they don't fit
            Wrap(
              spacing: 8.0, // Horizontal space between chips
              runSpacing: 8.0, // Vertical space between lines of chips
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
                // Show response deadline if the company made it visible
                if (opportunity.responseDeadlineVisible == true &&
                    opportunity.responseDeadline != null)
                  _buildInfoChip(
                    Icons.event_available,
                    // Format the date to be readable
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

  // --- 5. Helper Widgets ---

  // A small, reusable widget for displaying an icon and text in a colored chip.
  Widget _buildInfoChip(IconData icon, String label, {Color? color}) {
    // Use the provided color or default to purple
    final chipColor = color ?? const Color(0xFF422F5D);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1), // Light background color
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min, // Make the chip only as wide as needed
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

  // --- 6. User Actions ---

  // This function is called when the user presses the bookmark icon.
  Future<void> _toggleBookmark(Opportunity opportunity) async {
    // On this "Saved" screen, toggling a bookmark always means *removing* it.
    try {
      await _bookmarkService.removeBookmark(
        studentId: widget.studentId,
        opportunityId: opportunity.id,
      );
      // Show a brief confirmation message (SnackBar)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Removed from saved opportunities.'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      // Show an error message if something fails
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update bookmark.')),
        );
      }
    }
  }
}