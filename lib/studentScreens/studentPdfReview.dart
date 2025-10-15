// lib/screens/pdf_preview_screen.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

class PdfPreviewScreen extends StatelessWidget {
  final Future<Uint8List> pdfFuture;
  final String resumeTitle;

  const PdfPreviewScreen({
    super.key,
    required this.pdfFuture,
    required this.resumeTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Preview: $resumeTitle')),
      // The PdfPreview widget from the 'printing' package does all the hard work.
      // It provides a beautiful UI with options to print, share, and save.
      body: PdfPreview(
        // We pass the function that generates the PDF data.
        build: (format) => pdfFuture,
        // You can customize the preview screen further if needed.
        useActions: true, // Shows the print/share buttons
        canChangePageFormat: false,
      ),
    );
  }
}
