/*import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;

class UploadDocumentScreen extends StatefulWidget {
  final String patientId;
  final String patientName;
  final String doctorId;

  const UploadDocumentScreen({
    super.key,
    required this.patientId,
    required this.patientName,
    required this.doctorId,
  });

  @override
  State<UploadDocumentScreen> createState() => _UploadDocumentScreenState();
}

class _UploadDocumentScreenState extends State<UploadDocumentScreen> {
  File? _selectedFile;
  final TextEditingController _docTitleController = TextEditingController();
  bool _isUploading = false;

  final String cloudName = "dij8c34qm"; // Your Cloudinary Cloud Name
  final String uploadPreset = "medi360_unsigned"; // Your unsigned preset

  /// Pick file from device
  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result != null && result.files.single.path != null) {
      setState(() => _selectedFile = File(result.files.single.path!));
    }
  }

  /// Upload document to Cloudinary and save metadata in Firebase
  Future<void> _uploadFile() async {
    if (_selectedFile == null || _docTitleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a file and enter a document title."),
        ),
      );
      return;
    }

    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("User not logged in!")));
      return;
    }

    final String doctorId = currentUser.uid;
    setState(() => _isUploading = true);

    try {
      // Upload to Cloudinary
      final uri = Uri.parse(
        "https://api.cloudinary.com/v1_1/dij8c34qm/auto/upload",
      );

      final request = http.MultipartRequest("POST", uri)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(
          await http.MultipartFile.fromPath(
            'file',
            _selectedFile!.path,
            filename: path.basename(_selectedFile!.path),
            contentType: MediaType('application', 'octet-stream'),
          ),
        );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final fileUrl = data['secure_url'];

        final metadata = {
          "title": _docTitleController.text.trim(),
          "fileUrl": fileUrl,
          "uploadedAt": DateTime.now().toIso8601String(),
          "patientId": widget.patientId,
          "patientName": widget.patientName,
          "doctorId": doctorId,
        };

        // Store in Firebase
        final db = FirebaseDatabase.instance.ref();

        // Doctor side
        await db
            .child("doctor_documents/$doctorId/${widget.patientId}")
            .push()
            .set(metadata);

        // Patient side
        await db
            .child("patient_documents/${widget.patientId}/$doctorId")
            .push()
            .set(metadata);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("File uploaded successfully!")),
        );

        // Reset
        _docTitleController.clear();
        setState(() {
          _selectedFile = null;
          _isUploading = false;
        });

        Navigator.pop(context);
      } else {
        throw Exception("Cloudinary upload failed: ${response.body}");
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Upload failed: $e")));
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Upload Report - ${widget.patientName}"),
        backgroundColor: const Color(0xff0064FA),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _docTitleController,
              decoration: const InputDecoration(
                labelText: "Document Title",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.attach_file),
              label: Text(
                _selectedFile != null ? "File Selected" : "Select Document",
              ),
              onPressed: _pickFile,
            ),
            const SizedBox(height: 20),
            _selectedFile != null
                ? Text(
                    "Selected File: ${path.basename(_selectedFile!.path)}",
                    style: const TextStyle(color: Colors.black54),
                  )
                : const Text("No file selected yet."),
            const SizedBox(height: 30),
            _isUploading
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text("Upload to Cloud"),
                    onPressed: _uploadFile,
                  ),
          ],
        ),
      ),
    );
  }
}
*/
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;

class UploadDocumentScreen extends StatefulWidget {
  final String patientId;
  final String doctorId;
  final String appointmentId;
  final String patientName; // NEW

  const UploadDocumentScreen({
    super.key,
    required this.patientId,
    required this.doctorId,
    required this.appointmentId,
    required this.patientName,
  });

  @override
  State<UploadDocumentScreen> createState() => _UploadDocumentScreenState();
}

class _UploadDocumentScreenState extends State<UploadDocumentScreen> {
  File? _selectedFile;
  final TextEditingController _docTitleController = TextEditingController();
  bool _isUploading = false;

  final String cloudName = "dij8c34qm";
  final String uploadPreset = "medi360_unsigned";

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result != null && result.files.single.path != null) {
      setState(() => _selectedFile = File(result.files.single.path!));
    }
  }

  Future<void> _uploadFile() async {
    if (_selectedFile == null || _docTitleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a file & enter a report name."),
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      /// -------- Upload to Cloudinary --------
      final uri = Uri.parse(
        "https://api.cloudinary.com/v1_1/dij8c34qm/auto/upload",
      );

      final request = http.MultipartRequest("POST", uri)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(
          await http.MultipartFile.fromPath(
            'file',
            _selectedFile!.path,
            filename: path.basename(_selectedFile!.path),
            contentType: MediaType("application", "octet-stream"),
          ),
        );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        throw Exception("Cloudinary upload failed: ${response.body}");
      }

      final data = jsonDecode(response.body);
      final reportUrl = data['secure_url'];

      /// -------- Prepare Metadata --------
      final reportData = {
        "patientId": widget.patientId,
        "doctorId": widget.doctorId,
        "appointmentId": widget.appointmentId, // ✅ added
        "reportName": _docTitleController.text.trim(),
        "reportUrl": reportUrl,
        "uploadedOn": DateTime.now().toIso8601String(),
      };

      /// -------- Save to ONLY THIS NODE --------
      final db = FirebaseDatabase.instance.ref();
      await db.child("reports").push().set(reportData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Report uploaded successfully!")),
      );

      setState(() {
        _selectedFile = null;
        _docTitleController.clear();
        _isUploading = false;
      });

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Upload failed: $e")));
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Upload Report"),
        backgroundColor: Color(0xff0064FA),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _docTitleController,
              decoration: const InputDecoration(
                labelText: "Report Name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.attach_file),
              label: Text(
                _selectedFile != null ? "File Selected" : "Select Report File",
              ),
              onPressed: _pickFile,
            ),
            const SizedBox(height: 20),
            _selectedFile != null
                ? Text(path.basename(_selectedFile!.path))
                : const Text("No file selected."),
            const SizedBox(height: 30),
            _isUploading
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text("Upload Report"),
                    onPressed: _uploadFile,
                  ),
          ],
        ),
      ),
    );
  }
}
