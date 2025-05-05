# FileAlchemy

A Flutter application for converting files between different formats.

## Features

- Convert text files to PDF, HTML, and Markdown
- Convert PDF files to text and DOCX
- Convert images between various formats (JPEG, PNG, GIF, BMP, WebP)
- Easy file selection and conversion
- Share converted files

## Getting Started

1. Clone this repository
2. Run `flutter pub get` to install dependencies
3. Run `flutter run` to start the app

## Supported Conversions

Currently, FileAlchemy supports the following conversions:

- Text files (.txt) → PDF, HTML, Markdown
- PDF files (.pdf) → Text, DOCX
- Images:
  - JPEG ↔ PNG, GIF, BMP, WebP
  - PNG ↔ JPEG, GIF, BMP, WebP

**Note:** The current implementation simulates file conversion by copying the original file with a new extension. In a production app, you would implement the actual conversion logic for each format pair.

## Adding New Conversion Types

To add new conversion types:

1. Update the `supportedConversions` map in `lib/services/conversion_service.dart`
2. Add new formats to the `FileFormats` class in `lib/models/file_format.dart`
3. Implement the conversion logic in the `ConversionService.convertFile` method

## Dependencies

- file_picker: For selecting files
- path: For path manipulation
- path_provider: For accessing system directories
- mime: For determining file types
- permission_handler: For handling storage permissions
- share_plus: For sharing converted files

## Future Improvements

- Implement actual conversion logic for each format pair
- Add more file formats and conversion options
- Add batch conversion support
- Add conversion settings and options
- Improve UI and user experience
