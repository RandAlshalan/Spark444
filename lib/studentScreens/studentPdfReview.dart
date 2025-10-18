// lib/screens/pdf_preview_screen.dart

import 'dart:typed_data'; // Used for the raw PDF data
import 'package:flutter/material.dart';
import 'package:printing/printing.dart'; // The package that provides the PdfPreview widget

/// This class defines the PDF Preview Screen.
///
/// It's a "StatelessWidget" because it just *displays* data. It doesn't
/// need to manage any internal changes or state.
class PdfPreviewScreen extends StatelessWidget {
  // This variable holds the *function* that will create the PDF.
  // It's a "Future" because it takes time to generate the PDF data.
  final Future<Uint8List> pdfFuture;

  // This variable holds the title of the resume 
  // so we can display it in the app bar at the top.
  final String resumeTitle;

  /// This is the constructor.
  /// It requires the [pdfFuture] function and a [resumeTitle] to be
  /// provided when this screen is created.
  const PdfPreviewScreen({
    super.key,
    required this.pdfFuture,
    required this.resumeTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The bar at the top of the screen
      appBar: AppBar(title: Text('Preview: $resumeTitle')),

      // This is the main content of the screen.
      // We use the 'PdfPreview' widget from the 'printing' package.
      // This one widget does everything for us:
      // 1. Shows a loading spinner while the 'pdfFuture' is running.
      // 2. Displays the PDF pages when ready.
      // 3. Provides buttons for printing, sharing, and saving the PDF.
      body: PdfPreview(
        // This 'build' property tells the widget *how* to get the PDF data.
        // We just pass it the 'pdfFuture' function that was given to this screen.
        build: (format) => pdfFuture,

        // --- Optional Customizations ---

        // 'useActions: true' shows the print and share buttons in the app bar.
        useActions: true,
        // 'canChangePageFormat: false' hides the button that lets the user
        // change the paper size (like from A4 to Letter). We don't need this.
        canChangePageFormat: false,
      ),
    );
  }
}