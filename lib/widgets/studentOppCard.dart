/*import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_app/models/company.dart';
import 'package:my_app/models/opportunity.dart';
import 'package:my_app/services/authService.dart';
import 'package:my_app/services/bookmarkService.dart';

class StudentOppCard extends StatefulWidget {
  final Opportunity opportunity;
  final String? studentId;

  const StudentOppCard({
    super.key,
    required this.opportunity,
    required this.studentId,
  });

  @override
  State<StudentOppCard> createState() => _StudentOppCardState();
}

class _StudentOppCardState extends State<StudentOppCard> {
  final BookmarkService _bookmarkService = BookmarkService();
  final AuthService _authService = AuthService();

  Future<void> _toggleBookmark(bool isCurrentlyBookmarked) async {
    if (widget.studentId == null || widget.studentId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save. User not identified.')),
      );
      return;
    }

    try {
      if (isCurrentlyBookmarked) {
        await _bookmarkService.removeBookmark(
          studentId: widget.studentId!,
          opportunityId: widget.opportunity.id,
        );
      } else {
        await _bookmarkService.addBookmark(
          studentId: widget.studentId!,
          opportunityId: widget.opportunity.id,
        );
      }
    } catch (e) {
      debugPrint("Error toggling bookmark: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update bookmark.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  future: _authService.getCompany(widget.opportunity.companyId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.grey,
                      );
                    }
                    if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
                      return const CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.grey,
                        child: Icon(Icons.business, color: Colors.white),
                      );
                    }

                    final company = snapshot.data!;
                    final logoUrl = company.logoUrl;

                    return CircleAvatar(
                      radius: 25,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: (logoUrl != null && logoUrl.isNotEmpty)
                          ? NetworkImage(logoUrl)
                          : null,
                      child: (logoUrl == null || logoUrl.isEmpty)
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
                        widget.opportunity.role,
                        style: GoogleFonts.lato(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.opportunity.name,
                        style: GoogleFonts.lato(
                          fontSize: 15,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.studentId != null)
                  StreamBuilder<bool>(
                    stream: _bookmarkService.isBookmarkedStream(
                      studentId: widget.studentId!,
                      opportunityId: widget.opportunity.id,
                    ),
                    builder: (context, snapshot) {
                      final isBookmarked = snapshot.data ?? false;
                      return IconButton(
                        icon: Icon(
                          isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                          color: const Color(0xFF422F5D),
                        ),
                        onPressed: () => _toggleBookmark(isBookmarked),
                        tooltip: isBookmarked ? 'Remove Bookmark' : 'Save Bookmark',
                      );
                    },
                  )
                else
                  const IconButton(
                    icon: Icon(Icons.bookmark_border, color: Colors.grey),
                    onPressed: null,
                    tooltip: 'Login required to save',
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: [
                if (widget.opportunity.location != null)
                  _buildInfoChip(Icons.location_on_outlined, widget.opportunity.location!),
                if (widget.opportunity.workMode != null)
                  _buildInfoChip(Icons.work_outline, widget.opportunity.workMode!),
                _buildInfoChip(
                  Icons.attach_money,
                  widget.opportunity.isPaid ? 'Paid' : 'Unpaid',
                  color: widget.opportunity.isPaid ? Colors.green : Colors.orange,
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
}*/