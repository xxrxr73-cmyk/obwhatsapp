import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cryptography/cryptography.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

void main() {
  runApp(const OBWhatsAppViewerApp());
}

class OBWhatsAppViewerApp extends StatelessWidget {
  const OBWhatsAppViewerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OBWhatsApp Backup Viewer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _keyPath;
  String? _dbPath;
  bool _isProcessing = false;
  List<Map<String, dynamic>> _messages = [];
  String _statusMessage = 'يرجى اختيار ملف المفتاح وملف النسخة الاحتياطية';

  Future<void> _pickKeyFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      setState(() {
        _keyPath = result.files.single.path;
      });
    }
  }

  Future<void> _pickDbFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      setState(() {
        _dbPath = result.files.single.path;
      });
    }
  }

  Future<void> _decryptAndLoad() async {
    if (_keyPath == null || _dbPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء تحديد كلا الملفين أولاً')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'جاري جلب وفك تشفير البيانات...';
    });

    try {
      final keyFile = File(_keyPath!);
      final dbFile = File(_dbPath!);

      final keyBytes = await keyFile.readAsBytes();
      final dbBytes = await dbFile.readAsBytes();

      if (keyBytes.length < 158) {
        throw Exception('ملف المفتاح غير صالحة بنيته.');
      }

      final aesKeyBytes = keyBytes.sublist(126, 158);
      final iv = dbBytes.sublist(51, 67);
      final cipherText = dbBytes.sublist(67, dbBytes.length - 16);
      final macTag = dbBytes.sublist(dbBytes.length - 16);

      final algorithm = AesGcm.with256bits();
      final secretKey = await algorithm.newSecretKeyFromBytes(aesKeyBytes);

      final secretBox = SecretBox(
        cipherText,
        nonce: iv,
        mac: Mac(macTag),
      );

      final decryptedBytes = await algorithm.decrypt(
        secretBox,
        secretKey: secretKey,
      );

      final tempDir = await getTemporaryDirectory();
      final decryptedDbPath = p.join(tempDir.path, 'decrypted_msgstore.db');
      final decryptedFile = File(decryptedDbPath);
      await decryptedFile.writeAsBytes(decryptedBytes);

      await _readDatabase(decryptedDbPath);

      setState(() {
        _statusMessage = 'تم فك التشفير وعرض المحادثات بنجاح';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'فشل فك التشفير: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _readDatabase(String dbPath) async {
    final Database db = await openDatabase(dbPath, readOnly: true);

    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT 
        j.raw_string AS sender,
        m.text_data AS message,
        datetime(m.timestamp / 1000, 'unixepoch', 'localtime') AS time
      FROM message m
      LEFT JOIN jid j ON m.sender_jid_row_id = j._id
      WHERE m.text_data IS NOT NULL AND m.text_data != ''
      ORDER BY m.timestamp DESC
      LIMIT 100;
    ''');

    setState(() {
      _messages = result;
    });

    await db.close();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مستعرض OBWhatsApp'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.vpn_key, color: Colors.teal),
                      title: Text(_keyPath == null ? 'اختر ملف المفتاح (key)' : p.basename(_keyPath!)),
                      trailing: ElevatedButton(
                        onPressed: _pickKeyFile,
                        child: const Text('تحديد'),
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.storage, color: Colors.teal),
                      title: Text(_dbPath == null ? 'اختر ملف msgstore.db.crypt14' : p.basename(_dbPath!)),
                      trailing: ElevatedButton(
                        onPressed: _pickDbFile,
                        child: const Text('تحديد'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _decryptAndLoad,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                icon: const Icon(Icons.lock_open),
                label: const Text('فك التشفير وعرض الرسائل', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 12),
            if (_isProcessing) const CircularProgressIndicator(),
            Text(
              _statusMessage,
              style: TextStyle(color: _statusMessage.contains('فشل') ? Colors.red : Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _messages.isEmpty
                  ? const Center(child: Text('لا يوجد محادثات معروضة'))
                  : ListView.builder(
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            title: Text(
                              msg['sender'] ?? 'مجهول/أنت',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.teal),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(msg['message'] ?? '', style: const TextStyle(fontSize: 15, color: Colors.black87)),
                            ),
                            trailing: Text(
                              msg['time'] ?? '',
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
