import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class DocumentViewer extends StatefulWidget {
  final String documentUrl;
  final String documentName;

  const DocumentViewer({
    super.key,
    required this.documentUrl,
    required this.documentName,
  });

  @override
  State<DocumentViewer> createState() => _DocumentViewerState();
}

class _DocumentViewerState extends State<DocumentViewer> {
  bool _isLoading = true;
  String? _errorMessage;
  Uint8List? _documentData;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint('Loading document from URL: ${widget.documentUrl}');

      final uri = Uri.parse(widget.documentUrl);
      debugPrint('Parsed URI: ${uri.toString()}');

      final response = await http.get(uri).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Connection timeout - please check your internet connection');
        },
      );

      debugPrint('Response status code: ${response.statusCode}');
      debugPrint('Response content length: ${response.bodyBytes.length}');

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _documentData = response.bodyBytes;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to load document (Status: ${response.statusCode}).\n'
                'This might be a permissions issue with the document URL.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading document: $e');
      if (mounted) {
        setState(() {
          if (e.toString().contains('SocketException') ||
              e.toString().contains('Connection')) {
            _errorMessage = 'Unable to establish connection.\n'
                'Please check your internet connection and try again.';
          } else if (e.toString().contains('timeout')) {
            _errorMessage = 'Connection timeout.\n'
                'The document is taking too long to load. Please try again.';
          } else {
            _errorMessage = 'Error loading document:\n${e.toString()}';
          }
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildContent() {
    debugPrint('Building content - isLoading: $_isLoading, hasError: ${_errorMessage != null}, hasData: ${_documentData != null}');

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Loading document...'),
            const SizedBox(height: 8),
            Text(
              'Please wait',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadDocument,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_documentData == null) {
      return const Center(
        child: Text('No document data available'),
      );
    }

    final extension = widget.documentName.split('.').last.toLowerCase();
    debugPrint('Rendering document with extension: $extension');

    // Display images
    if (extension == 'png' || extension == 'jpg' || extension == 'jpeg') {
      debugPrint('Displaying image with ${_documentData!.length} bytes');
      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Center(
          child: Image.memory(
            _documentData!,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('Error displaying image: $error');
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.broken_image, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text('Error displaying image: $error'),
                  ],
                ),
              );
            },
          ),
        ),
      );
    }

    // Display PDFs with actual rendering from memory
    if (extension == 'pdf') {
      debugPrint('Displaying PDF with ${_documentData!.length} bytes');
      return _PDFViewer(pdfData: _documentData!);
    }

    // Display text files
    if (extension == 'txt') {
      try {
        final text = String.fromCharCodes(_documentData!);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            text,
            style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
          ),
        );
      } catch (e) {
        return Center(
          child: Text('Error displaying text: $e'),
        );
      }
    }

    // For other file types (DOC, DOCX, etc.)
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getFileIcon(extension),
            size: 64,
            color: Colors.blue.shade700,
          ),
          const SizedBox(height: 16),
          Text(
            widget.documentName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              'Preview not available for this file type.\nTap the download button to view externally.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String extension) {
    switch (extension) {
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'txt':
        return Icons.text_snippet;
      default:
        return Icons.insert_drive_file;
    }
  }

  Future<void> _downloadDocument() async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final uri = Uri.parse(widget.documentUrl);

      // Try to launch the URL
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Could not open document URL'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error opening document: $e');
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error opening document: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(
          widget.documentName,
          style: const TextStyle(fontSize: 16),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _downloadDocument,
            tooltip: 'Download',
          ),
        ],
      ),
      body: _buildContent(),
    );
  }
}

// PDF Viewer Widget
class _PDFViewer extends StatefulWidget {
  final Uint8List pdfData;

  const _PDFViewer({required this.pdfData});

  @override
  State<_PDFViewer> createState() => _PDFViewerState();
}

class _PDFViewerState extends State<_PDFViewer> {
  final PdfViewerController _pdfViewerController = PdfViewerController();

  @override
  void dispose() {
    _pdfViewerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SfPdfViewer.memory(
      widget.pdfData,
      controller: _pdfViewerController,
      canShowScrollHead: true,
      canShowScrollStatus: true,
      enableDoubleTapZooming: true,
      enableTextSelection: true,
      onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
        debugPrint('PDF load failed: ${details.error}');
        debugPrint('PDF load description: ${details.description}');
      },
    );
  }
}

// Network PDF Viewer Widget
class _PDFNetworkViewer extends StatefulWidget {
  final String url;

  const _PDFNetworkViewer({required this.url});

  @override
  State<_PDFNetworkViewer> createState() => _PDFNetworkViewerState();
}

class _PDFNetworkViewerState extends State<_PDFNetworkViewer> {
  final PdfViewerController _pdfViewerController = PdfViewerController();

  @override
  void dispose() {
    _pdfViewerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SfPdfViewer.network(
      widget.url,
      controller: _pdfViewerController,
      canShowScrollHead: true,
      canShowScrollStatus: true,
      enableDoubleTapZooming: true,
      enableTextSelection: true,
      onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
        debugPrint('PDF network load failed: ${details.error}');
        debugPrint('PDF network load description: ${details.description}');

        // Show error to user
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load PDF: ${details.description}'),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: () {
                  // Trigger a rebuild to retry
                  if (mounted) {
                    setState(() {});
                  }
                },
              ),
            ),
          );
        }
      },
    );
  }
}
