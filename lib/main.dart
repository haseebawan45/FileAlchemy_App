import 'dart:io';
import 'dart:typed_data';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:image/image.dart' as img;
import 'package:html/parser.dart' as html_parser;
import 'package:markdown/markdown.dart' as md;
import 'package:archive/archive.dart';

import 'models/file_format.dart';
import 'services/conversion_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FileAlchemy',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const FileAlchemyHomePage(),
    );
  }
}

class FileAlchemyHomePage extends StatefulWidget {
  const FileAlchemyHomePage({super.key});

  @override
  State<FileAlchemyHomePage> createState() => _FileAlchemyHomePageState();
}

class _FileAlchemyHomePageState extends State<FileAlchemyHomePage> {
  File? selectedFile;
  Uint8List? selectedFileBytes;
  String? selectedFileName;
  String? selectedOutputFormat;
  bool isConverting = false;
  String? conversionError;
  File? convertedFile;
  Uint8List? convertedBytes;
  
  // Image conversion options
  int imageQuality = 90; // Default JPEG quality (0-100)
  int? targetWidth;
  int? targetHeight;
  bool maintainAspectRatio = true;

  Future<void> pickFile() async {
    print('Starting file picker...');
    final result = await FilePicker.platform.pickFiles();
    
    if (result != null) {
      print('File selected: ${result.files.single.name}');
      setState(() {
        selectedFileName = result.files.single.name;
        selectedOutputFormat = null;
        convertedFile = null;
        convertedBytes = null;
        conversionError = null;
        
        // Handle differently for web and mobile/desktop
        if (kIsWeb) {
          print('Web platform detected');
          // On web, we get bytes directly
          selectedFileBytes = result.files.single.bytes;
          print('File size: ${selectedFileBytes?.length} bytes');
          selectedFile = null;
        } else {
          print('Mobile/Desktop platform detected');
          // On mobile/desktop, we get a file path
          selectedFile = File(result.files.single.path!);
          print('File path: ${selectedFile?.path}');
          selectedFileBytes = null;
        }
      });
    } else {
      print('No file selected');
    }
  }

  List<String> getAvailableOutputFormats() {
    print('Getting available output formats...');
    // For web, we'll use the filename to guess the format
    if (kIsWeb) {
      if (selectedFileName == null) {
        print('No file selected');
        return [];
      }
      final extension = path.extension(selectedFileName!).toLowerCase().replaceAll('.', '');
      print('File extension: $extension');
      try {
        final format = FileFormats.getByExtension(extension);
        if (format == null) {
          print('Could not determine file format from extension');
          return [];
        }
        print('Detected format: ${format.mimeType}');
        
        // Find formats that this format can convert to
        for (final entry in ConversionService.supportedConversions.entries) {
          if (entry.key.contains(format.mimeType)) {
            print('Available output formats: ${entry.value}');
            return entry.value;
          }
        }
        print('No conversion options available for this format');
        return [];
      } catch (e) {
        print('Error determining format: $e');
        return [];
      }
    } else {
      // For mobile/desktop
      if (selectedFile == null) {
        print('No file selected');
        return [];
      }
      return ConversionService.getAvailableOutputFormats(selectedFile!);
    }
  }

  bool isImageFile() {
    if (selectedFileName == null) return false;
    
    final extension = path.extension(selectedFileName!).toLowerCase().replaceAll('.', '');
    final format = FileFormats.getByExtension(extension);
    return format != null && format.mimeType.startsWith('image/');
  }

  bool isConvertingToImage() {
    if (selectedOutputFormat == null) return false;
    
    // Image format extensions
    final imageFormats = ['png', 'jpeg', 'jpg', 'gif', 'bmp', 'webp'];
    return imageFormats.contains(selectedOutputFormat);
  }

  Future<void> convertFile() async {
    print('Starting file conversion...');
    if ((selectedFile == null && selectedFileBytes == null) || selectedOutputFormat == null) {
      print('No file selected or output format not chosen');
      return;
    }
    
    setState(() {
      isConverting = true;
      conversionError = null;
      convertedFile = null;
      convertedBytes = null;
    });
    
    try {
      if (kIsWeb) {
        print('Web platform conversion');
        if (selectedFileBytes == null) {
          print('No file bytes available');
          return;
        }
        
        // Get the input file's MIME type from its extension
        final extension = path.extension(selectedFileName!).toLowerCase().replaceAll('.', '');
        print('File extension: $extension');
        final format = FileFormats.getByExtension(extension);
        if (format == null) {
          print('Could not determine input file type');
          throw Exception('Cannot determine input file type');
        }
        print('Detected format: ${format.mimeType}');
        
        // Perform the appropriate conversion based on input and output formats
        if (format.mimeType == 'text/plain') {
          print('Converting text file...');
          final text = String.fromCharCodes(selectedFileBytes!);
          
          switch (selectedOutputFormat) {
            case 'pdf':
              print('Converting text to PDF...');
              convertedBytes = await _convertTextToPdfWeb(text);
              break;
            case 'html':
              print('Converting text to HTML...');
              convertedBytes = await _convertTextToHtmlWeb(text);
              break;
            case 'markdown':
              print('Converting text to Markdown...');
              convertedBytes = await _convertTextToMarkdownWeb(text);
              break;
            default:
              print('Unsupported conversion: text to $selectedOutputFormat');
              throw Exception('Unsupported conversion: text to $selectedOutputFormat');
          }
        } else if (format.mimeType == 'application/pdf') {
          print('Converting PDF file...');
          switch (selectedOutputFormat) {
            case 'text':
              print('Converting PDF to text...');
              convertedBytes = await _convertPdfToTextWeb(selectedFileBytes!);
              break;
            case 'docx':
              print('Converting PDF to DOCX...');
              convertedBytes = await _convertPdfToDocxWeb(selectedFileBytes!);
              break;
            default:
              print('Unsupported conversion: PDF to $selectedOutputFormat');
              throw Exception('Unsupported conversion: PDF to $selectedOutputFormat');
          }
        } else if (format.mimeType.startsWith('image/')) {
          print('Converting image file...');
          try {
            print('Starting image conversion from ${format.mimeType} to $selectedOutputFormat');
            convertedBytes = await _convertImageFormatWeb(
              selectedFileBytes!, 
              selectedOutputFormat!,
              quality: imageQuality,
              width: targetWidth,
              height: targetHeight
            );
            print('Image conversion successful: ${convertedBytes!.length} bytes');
          } catch (e) {
            print('Image conversion error: $e');
            throw Exception('Failed to convert image: $e');
          }
        } else {
          print('Unsupported conversion: ${format.mimeType} to $selectedOutputFormat');
          throw Exception('Unsupported conversion: ${format.mimeType} to $selectedOutputFormat');
        }
        
        print('Conversion completed successfully');
        setState(() {
          isConverting = false;
        });
      } else {
        print('Mobile/Desktop platform conversion');
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          print('Storage permission denied');
          throw Exception('Storage permission is required');
        }
        
        final tempDir = await getTemporaryDirectory();
        print('Temporary directory: ${tempDir.path}');
        final newFile = await ConversionService.convertFile(
          selectedFile!, 
          selectedOutputFormat!, 
          tempDir.path,
          quality: imageQuality,
          width: targetWidth,
          height: targetHeight
        );
        
        print('Conversion completed successfully');
        setState(() {
          convertedFile = newFile;
          isConverting = false;
        });
      }
    } catch (e) {
      print('Error during conversion: $e');
      setState(() {
        conversionError = e.toString();
        isConverting = false;
      });
    }
  }

  // Web-specific conversion methods
  Future<Uint8List> _convertTextToPdfWeb(String text) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Text(text),
          );
        },
      ),
    );
    
    return await pdf.save();
  }

  Future<Uint8List> _convertTextToHtmlWeb(String text) async {
    final html = '''
      <!DOCTYPE html>
      <html>
        <head>
          <meta charset="UTF-8">
          <title>Converted Text</title>
        </head>
        <body>
          <pre>${text.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;')}</pre>
        </body>
      </html>
    '''.codeUnits;
    
    return Uint8List.fromList(html);
  }

  Future<Uint8List> _convertTextToMarkdownWeb(String text) async {
    final markdown = '```\n$text\n```'.codeUnits;
    return Uint8List.fromList(markdown);
  }

  Future<Uint8List> _convertImageFormatWeb(Uint8List imageBytes, String outputFormat, {int? quality, int? width, int? height}) async {
    print('Starting web image format conversion to $outputFormat');
    print('Input image size: ${imageBytes.length} bytes');
    
    final inputImage = img.decodeImage(imageBytes);
    if (inputImage == null) {
      print('Failed to decode input image');
      throw Exception('Failed to decode input image');
    }
    print('Image decoded successfully. Dimensions: ${inputImage.width}x${inputImage.height}');
    
    // Apply resizing if specified
    img.Image outputImage = inputImage;
    if (width != null || height != null) {
      final targetWidth = width ?? (height != null ? (inputImage.width * height / inputImage.height).round() : inputImage.width);
      final targetHeight = height ?? (width != null ? (inputImage.height * width / inputImage.width).round() : inputImage.height);
      
      print('Resizing image to ${targetWidth}x${targetHeight}');
      outputImage = img.copyResize(
        inputImage, 
        width: targetWidth, 
        height: targetHeight,
        interpolation: img.Interpolation.average
      );
    }
    
    // Set quality for formats that support it
    final jpegQuality = quality ?? 90; // Default JPEG quality
    
    switch (outputFormat) {
      case 'png':
        print('Encoding to PNG...');
        return Uint8List.fromList(img.encodePng(outputImage));
      case 'jpeg':
        print('Encoding to JPEG with quality $jpegQuality...');
        return Uint8List.fromList(img.encodeJpg(outputImage, quality: jpegQuality));
      case 'gif':
        print('Encoding to GIF...');
        return Uint8List.fromList(img.encodeGif(outputImage));
      case 'bmp':
        print('Encoding to BMP...');
        return Uint8List.fromList(img.encodeBmp(outputImage));
      case 'webp':
        print('WebP encoding not directly supported on web');
        print('Falling back to PNG encoding');
        return Uint8List.fromList(img.encodePng(outputImage));
      default:
        print('Unsupported image format: $outputFormat');
        throw Exception('Unsupported image format: $outputFormat');
    }
  }

  // PDF to Text conversion for web
  Future<Uint8List> _convertPdfToTextWeb(Uint8List pdfBytes) async {
    print('Starting PDF to text conversion in web');
    try {
      // Create a new PDF document
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Text('PDF to text conversion is not fully implemented yet.'),
            );
          },
        ),
      );
      
      // For now, return a simple text message
      final text = 'PDF to text conversion is not fully implemented yet.';
      return Uint8List.fromList(text.codeUnits);
    } catch (e) {
      print('Error during PDF to text conversion: $e');
      return Uint8List.fromList('PDF conversion error: $e'.codeUnits);
    }
  }

  // PDF to DOCX conversion for web
  Future<Uint8List> _convertPdfToDocxWeb(Uint8List pdfBytes) async {
    print('Starting PDF to DOCX conversion in web');
    try {
      // Use our service implementation for consistency
      return await ConversionService.createDocxFromPdf(pdfBytes);
    } catch (e) {
      print('Error during PDF to DOCX conversion: $e');
      return Uint8List.fromList('PDF to DOCX conversion error: $e'.codeUnits);
    }
  }

  Future<void> shareConvertedFile() async {
    print('Sharing converted file...');
    if (kIsWeb) {
      if (convertedBytes != null && selectedFileName != null) {
        final outputFileName = '${path.basenameWithoutExtension(selectedFileName!)}.$selectedOutputFormat';
        print('Downloading file: $outputFileName');
        final blob = html.Blob([convertedBytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', outputFileName)
          ..click();
        html.Url.revokeObjectUrl(url);
        print('File download initiated');
      } else {
        print('No converted file available for download');
      }
    } else {
      if (convertedFile != null) {
        print('Sharing file: ${convertedFile!.path}');
        await Share.shareXFiles([XFile(convertedFile!.path)]);
        print('File shared successfully');
      } else {
        print('No converted file available for sharing');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableFormats = getAvailableOutputFormats();
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('FileAlchemy'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: pickFile,
              icon: const Icon(Icons.file_upload),
              label: const Text('Select File'),
            ),
            const SizedBox(height: 20),
            
            if (selectedFileName != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selected File:',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        selectedFileName ?? '',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Convert to:',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 8),
                      if (availableFormats.isEmpty)
                        const Text('No conversion options available for this file type'),
                      if (availableFormats.isNotEmpty)
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          value: selectedOutputFormat,
                          hint: const Text('Select output format'),
                          onChanged: (value) {
                            setState(() {
                              selectedOutputFormat = value;
                            });
                          },
                          items: availableFormats
                              .map((format) => DropdownMenuItem(
                                    value: format,
                                    child: Text(format.toUpperCase()),
                                  ))
                              .toList(),
                        ),
                        
                        // Image conversion options
                        if (isImageFile() && selectedOutputFormat != null) ...[
                          const SizedBox(height: 16),
                          const Text(
                            'Image Options:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          
                          // Quality slider for JPEG
                          if (selectedOutputFormat == 'jpeg') ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Text('Quality:'),
                                Expanded(
                                  child: Slider(
                                    value: imageQuality.toDouble(),
                                    min: 10,
                                    max: 100,
                                    divisions: 9,
                                    label: imageQuality.toString(),
                                    onChanged: (value) {
                                      setState(() {
                                        imageQuality = value.round();
                                      });
                                    },
                                  ),
                                ),
                                Text('$imageQuality%'),
                              ],
                            ),
                          ],
                          
                          // Resize options
                          const SizedBox(height: 8),
                          const Text('Resize:'),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  decoration: const InputDecoration(
                                    labelText: 'Width',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (value) {
                                    setState(() {
                                      targetWidth = value.isEmpty ? null : int.tryParse(value);
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  decoration: const InputDecoration(
                                    labelText: 'Height',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (value) {
                                    setState(() {
                                      targetHeight = value.isEmpty ? null : int.tryParse(value);
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          
                          // Maintain aspect ratio
                          Row(
                            children: [
                              Checkbox(
                                value: maintainAspectRatio,
                                onChanged: (value) {
                                  setState(() {
                                    maintainAspectRatio = value ?? true;
                                  });
                                },
                              ),
                              const Text('Maintain aspect ratio'),
                            ],
                          ),
                        ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              ElevatedButton.icon(
                onPressed: (selectedOutputFormat != null && !isConverting)
                    ? convertFile
                    : null,
                icon: const Icon(Icons.autorenew),
                label: const Text('Convert'),
              ),
              
              if (isConverting) ...[
                const SizedBox(height: 20),
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 8),
                const Center(child: Text('Converting...')),
              ],
              
              if (conversionError != null) ...[
                const SizedBox(height: 20),
                Card(
                  color: Colors.red[100],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Error: $conversionError',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ],
              
              if (convertedFile != null || convertedBytes != null) ...[
                const SizedBox(height: 20),
                Card(
                  color: Colors.green[100],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Conversion Complete!',
                          style: TextStyle(
                            color: Colors.green[800],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Output File: ${convertedFile != null ? path.basename(convertedFile!.path) : 
                            '${path.basenameWithoutExtension(selectedFileName!)}.$selectedOutputFormat'}',
                          style: TextStyle(color: Colors.green[800]),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: shareConvertedFile,
                          icon: const Icon(Icons.share),
                          label: Text(kIsWeb ? 'Download' : 'Share'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
