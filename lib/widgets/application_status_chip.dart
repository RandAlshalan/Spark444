import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ApplicationStatusChip extends StatelessWidget {
  final String status;
  final double horizontalPadding;
  final double verticalPadding;
  final double fontSize;
  final bool capitalize;

  const ApplicationStatusChip({
    super.key,
    required this.status,
    this.horizontalPadding = 10,
    this.verticalPadding = 5,
    this.fontSize = 12,
    this.capitalize = false,
  });

  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'hired':
      case 'accepted':
        return Colors.green.shade600;
      case 'reviewed':
        return Colors.blue.shade600;
      case 'rejected':
        return Colors.red.shade600;
      case 'withdrawn':
        return Colors.grey.shade600;
      case 'pending':
      default:
        return Colors.orange.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = getStatusColor(status);
    final label = capitalize
        ? (status.isEmpty ? status : '${status[0].toUpperCase()}${status.substring(1)}')
        : status;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.lato(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: fontSize,
        ),
      ),
    );
  }
}
