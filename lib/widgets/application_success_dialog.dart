import 'package:flutter/material.dart';

class ApplicationSuccessDialog extends StatelessWidget {
  final String opportunityTitle;
  final String? companyName;
  final String resumeTitle;
  final bool includeCoverLetter;
  final VoidCallback? onViewApplications;

  const ApplicationSuccessDialog({
    super.key,
    required this.opportunityTitle,
    required this.resumeTitle,
    this.companyName,
    this.includeCoverLetter = false,
    this.onViewApplications,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x14422F5D),
                ),
                child: const Icon(
                  Icons.check_circle,
                  size: 52,
                  color: Color(0xFF422F5D),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Application Sent!',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF422F5D),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _buildMessage(),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.black87,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              _InfoTile(
                label: 'Resume Submitted',
                value: resumeTitle,
                icon: Icons.description_outlined,
              ),
              if (includeCoverLetter) ...[
                const SizedBox(height: 12),
                _InfoTile(
                  label: 'Cover Letter',
                  value: 'Included',
                  icon: Icons.mark_email_read_outlined,
                ),
              ],
              const SizedBox(height: 28),
              if (onViewApplications != null)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onViewApplications!();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF422F5D),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'View My Applications',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              if (onViewApplications != null) const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    side: const BorderSide(color: Color(0xFF422F5D)),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      color: Color(0xFF422F5D),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildMessage() {
    final trimmedCompany = companyName?.trim();
    if (trimmedCompany != null && trimmedCompany.isNotEmpty) {
      return 'We\'ll notify you once $trimmedCompany reviews your application for "$opportunityTitle".';
    }
    return 'We\'ll notify you once your application for "$opportunityTitle" is reviewed.';
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0FA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF422F5D)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: const Color(0xFF6B4791),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF422F5D),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
