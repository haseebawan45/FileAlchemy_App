class FileFormat {
  final String extension;
  final String mimeType;
  final String name;
  final String description;
  final String? icon;

  const FileFormat({
    required this.extension,
    required this.mimeType,
    required this.name,
    required this.description,
    this.icon,
  });

  // Check if a file is of this format based on its path
  bool matchesFile(String filePath) {
    return filePath.toLowerCase().endsWith('.$extension');
  }

  @override
  String toString() => name;
}

// Pre-defined file formats
class FileFormats {
  // Text formats
  static const txt = FileFormat(
    extension: 'txt',
    mimeType: 'text/plain',
    name: 'Text File',
    description: 'Plain text file',
  );

  static const markdown = FileFormat(
    extension: 'md',
    mimeType: 'text/markdown',
    name: 'Markdown',
    description: 'Markdown document',
  );

  static const html = FileFormat(
    extension: 'html',
    mimeType: 'text/html',
    name: 'HTML',
    description: 'HTML document',
  );

  // Document formats
  static const pdf = FileFormat(
    extension: 'pdf',
    mimeType: 'application/pdf',
    name: 'PDF',
    description: 'Portable Document Format',
  );

  static const docx = FileFormat(
    extension: 'docx',
    mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    name: 'Word Document',
    description: 'Microsoft Word Document',
  );

  // Image formats
  static const jpeg = FileFormat(
    extension: 'jpeg',
    mimeType: 'image/jpeg',
    name: 'JPEG Image',
    description: 'JPEG image format',
  );

  static const jpg = FileFormat(
    extension: 'jpg',
    mimeType: 'image/jpeg',
    name: 'JPEG Image',
    description: 'JPEG image format',
  );

  static const png = FileFormat(
    extension: 'png',
    mimeType: 'image/png',
    name: 'PNG Image',
    description: 'Portable Network Graphics',
  );

  static const gif = FileFormat(
    extension: 'gif',
    mimeType: 'image/gif',
    name: 'GIF Image',
    description: 'Graphics Interchange Format',
  );

  static const bmp = FileFormat(
    extension: 'bmp',
    mimeType: 'image/bmp',
    name: 'BMP Image',
    description: 'Bitmap image format',
  );

  static const webp = FileFormat(
    extension: 'webp',
    mimeType: 'image/webp',
    name: 'WebP Image',
    description: 'WebP image format',
  );

  // List of all formats
  static final List<FileFormat> allFormats = [
    txt, markdown, html, pdf, docx, jpeg, jpg, png, gif, bmp, webp
  ];

  // Get a format by extension
  static FileFormat? getByExtension(String extension) {
    print('Looking up format for extension: $extension');
    final cleanExtension = extension.toLowerCase().replaceAll('.', '');
    try {
      final format = allFormats.firstWhere(
        (format) => format.extension == cleanExtension,
        orElse: () => throw Exception('Format not found for extension: $extension'),
      );
      print('Found format: ${format.mimeType}');
      return format;
    } catch (e) {
      print('Error finding format: $e');
      return null;
    }
  }

  // Get a format by mime type
  static FileFormat? getByMimeType(String mimeType) {
    print('Looking up format for MIME type: $mimeType');
    try {
      final format = allFormats.firstWhere(
        (format) => format.mimeType == mimeType,
        orElse: () => throw Exception('Format not found for MIME type: $mimeType'),
      );
      print('Found format: ${format.extension}');
      return format;
    } catch (e) {
      print('Error finding format: $e');
      return null;
    }
  }
} 