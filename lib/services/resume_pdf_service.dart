import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/resume.dart';

/// Utility responsible for converting a [Resume] model into a PDF document.
class ResumePdfService {
  const ResumePdfService._();

  /// Builds a printable PDF from the provided [resume].
  static Future<Uint8List> generate(Resume resume) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => _buildHeader(context, resume),
        build: (context) => _buildBody(resume),
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader(pw.Context context, Resume resume) {
    final personalDetails = resume.personalDetails;
    final fullName =
        '${personalDetails['firstName'] ?? ''} ${personalDetails['lastName'] ?? ''}'
            .trim();
    final email = personalDetails['email'] ?? '';
    final phone = personalDetails['phone'] ?? '';

    if (context.pageNumber == 1) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            fullName,
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 5),
          if (email.isNotEmpty || phone.isNotEmpty)
            pw.Text(
              [
                if (email.isNotEmpty) email,
                if (phone.isNotEmpty) phone,
              ].join(' | '),
            ),
          pw.SizedBox(height: 15),
          pw.Divider(),
        ],
      );
    }

    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Text(
        '$fullName - Page ${context.pageNumber}',
        style: const pw.TextStyle(color: PdfColors.grey),
      ),
    );
  }

  static List<pw.Widget> _buildBody(Resume resume) {
    final summary = resume.personalDetails['summary'] ?? '';

    return <pw.Widget>[
      if ((summary as String).trim().isNotEmpty) ...[
        _buildSectionTitle('Summary'),
        pw.Text(
          summary,
          style: const pw.TextStyle(fontSize: 11),
          textAlign: pw.TextAlign.justify,
        ),
      ],
      if (resume.experiences.isNotEmpty) ...[
        _buildSectionTitle('Work Experience'),
        ...resume.experiences.map(_buildExperienceItem),
      ],
      if (resume.education.isNotEmpty) ...[
        _buildSectionTitle('Education'),
        ...resume.education.map(_buildEducationItem),
      ],
      if (resume.projects.isNotEmpty) ...[
        _buildSectionTitle('Projects'),
        ...resume.projects.map(_buildProjectItem),
      ],
      if (resume.skills.isNotEmpty) ...[
        _buildSectionTitle('Skills'),
        _buildSkillsBlock(resume.skills),
      ],
      if (resume.extracurriculars.isNotEmpty) ...[
        _buildSectionTitle('Extracurricular Activities'),
        ...resume.extracurriculars.map(_buildExtracurricularItem),
      ],
      if (resume.licenses.isNotEmpty) ...[
        _buildSectionTitle('Licenses & Certifications'),
        ...resume.licenses.map(_buildLicenseItem),
      ],
      if (resume.customSections.isNotEmpty)
        ...resume.customSections.expand(
          (section) {
            if (section.entries.isEmpty) return <pw.Widget>[];
            return [
              _buildSectionTitle(section.sectionTitle),
              ...section.entries.map(_buildCustomFieldEntryItem),
            ];
          },
        ),
      if (resume.awards.isNotEmpty) ...[
        _buildSectionTitle('Awards'),
        ...resume.awards.map(_buildAwardItem),
      ],
      if (resume.languages.isNotEmpty) ...[
        _buildSectionTitle('Languages'),
        ...resume.languages.map(_buildLanguageItem),
      ],
    ];
  }

  static pw.Widget _buildSectionTitle(String title) {
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
          ),
          pw.Container(
            height: 2,
            color: PdfColors.grey700,
            margin: const pw.EdgeInsets.only(top: 2),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildExperienceItem(Experience exp) {
    final duration = _formatRange(
      exp.startDate,
      exp.endDate,
      exp.isPresent,
    );

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                exp.title,
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(duration, style: const pw.TextStyle(fontSize: 11)),
            ],
          ),
          pw.Text(
            exp.organization,
            style: pw.TextStyle(fontSize: 11, fontStyle: pw.FontStyle.italic),
          ),
          if ((exp.description ?? '').trim().isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Text(exp.description!),
            ),
        ],
      ),
    );
  }

  static pw.Widget _buildEducationItem(Education edu) {
    final graduationDate = edu.isPresent
        ? 'Present'
        : (edu.endDate != null
            ? DateFormat.yMMMd().format(edu.endDate!)
            : 'N/A');

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                edu.degreeName,
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(graduationDate, style: const pw.TextStyle(fontSize: 11)),
            ],
          ),
          pw.Text(edu.instituteName, style: const pw.TextStyle(fontSize: 11)),
          if (edu.gpa != null)
            pw.Text(
              'GPA: ${edu.gpa!.toStringAsFixed(2)}',
              style: const pw.TextStyle(fontSize: 11),
            ),
        ],
      ),
    );
  }

  static pw.Widget _buildProjectItem(Project project) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            project.title,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          if (project.description.trim().isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Text(project.description),
            ),
          if ((project.link ?? '').trim().isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Text(
                project.link!,
                style: const pw.TextStyle(
                  color: PdfColors.blue,
                  decoration: pw.TextDecoration.underline,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static pw.Widget _buildSkillsBlock(List<String> skills) {
    final bulletSkills = skills.map((skill) => '• $skill').join('   ');
    return pw.Text(
      bulletSkills,
      style: const pw.TextStyle(fontSize: 11),
    );
  }

  static pw.Widget _buildExtracurricularItem(Extracurricular activity) {
    final duration = _formatRange(
      activity.startDate,
      activity.endDate,
      activity.isPresent,
      fallback: 'Present',
    );

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            activity.organizationName,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          if ((activity.eventName ?? '').trim().isNotEmpty)
            pw.Text(activity.eventName!),
          pw.Text(
            '${activity.role} • $duration',
            style: const pw.TextStyle(fontSize: 11),
          ),
          if ((activity.description ?? '').trim().isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Text(activity.description!),
            ),
        ],
      ),
    );
  }

  static pw.Widget _buildLicenseItem(License license) {
    final expiration = license.expirationDate != null
        ? DateFormat.yMMMd().format(license.expirationDate!)
        : null;

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            license.name,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            license.issuingOrganization,
            style: const pw.TextStyle(fontSize: 11),
          ),
          pw.Text(
            'Issued ${DateFormat.yMMMd().format(license.issueDate)}'
            '${expiration != null ? ' • Expires $expiration' : ''}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildCustomFieldEntryItem(CustomFieldEntry entry) {
    final range = _formatRange(
      entry.startDate,
      entry.endDate,
      entry.currently,
      fallback: '',
    );

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if ((entry.title ?? '').trim().isNotEmpty)
            pw.Text(
              entry.title!,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          if ((entry.description ?? '').trim().isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 2),
              child: pw.Text(entry.description!),
            ),
          if (range.isNotEmpty)
            pw.Text(
              range,
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
        ],
      ),
    );
  }

  static pw.Widget _buildAwardItem(Award award) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            award.title,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(award.organization),
          pw.Text(
            DateFormat('MMM yyyy').format(award.issueDate),
            style: const pw.TextStyle(color: PdfColors.grey),
          ),
          if (award.description.trim().isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Text(award.description),
            ),
        ],
      ),
    );
  }

  static pw.Widget _buildLanguageItem(Language language) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(
        '${language.name} • ${language.proficiency}',
        style: const pw.TextStyle(fontSize: 11),
      ),
    );
  }

  static String _formatRange(
    DateTime? start,
    DateTime? end,
    bool isPresent, {
    String fallback = 'Present',
  }) {
    if (start == null) return '';
    final startStr = DateFormat.yMMMd().format(start);
    if (isPresent) return '$startStr - $fallback';
    if (end == null) return '$startStr - $fallback';
    return '$startStr - ${DateFormat.yMMMd().format(end)}';
  }
}
