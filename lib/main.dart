                    import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

void main() {
  runApp(const OBWhatsAppViewerApp());
}

class OBWhatsAppViewerApp extends StatelessWidget {
  const OBWhatsAppViewerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OBWhatsApp Database Viewer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _selectedFilePath;
  String _statusMessage = 'لم يتم اختيار ملف قاعدة البيانات بعد.';
  bool _isLoading = false;

  Future<void> _pickDatabaseFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFilePath = result.files.single.path;
          _statusMessage = 'تم اختيار الملف بنجاح:\n${result.files.single.name}';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'حدث خطأ أثناء اختيار الملف: $e';
      });
    }
  }

  void _processDatabase() {
    if (_selectedFilePath == null) return;
    setState(() {
      _isLoading = true;
      _statusMessage = 'جاري معالجة وقراءة ملف قاعدة البيانات...';
    });

    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _isLoading = false;
        _statusMessage = 'تم تحميل الملف بنجاح!\nالمسار: $_selectedFilePath';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('عارض قاعدة بيانات OBWhatsApp'),
        centerTitle: true,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.folder_zip_rounded,
              size: 80,
              color: Colors.teal,
            ),
            const SizedBox(height: 24),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _pickDatabaseFile,
              icon: const Icon(Icons.file_open),
              label: const Text('اختيار ملف crypt14 / SQLite'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            if (_selectedFilePath != null)
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _processDatabase,
                icon: const Icon(Icons.analytics),
                label: const Text('قراءة وفك التشفير'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            if (_isLoading) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }
}
