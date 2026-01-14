import 'dart:convert';
import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:emergency_app/services/supabase.dart';

import 'package:emergency_app/Provider/location_provider.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:provider/provider.dart' as provider_pkg;

class ProcessingScreen extends StatefulWidget {
  final String type;
  final String name;
  final String mobile;
  final String imagePath;
  final String videoPath;

  const ProcessingScreen({
    required this.type,
    required this.name,
    required this.mobile,
    required this.imagePath,
    required this.videoPath,
    super.key,
  });

  @override
  _ProcessingScreenState createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  String _statusMessage = "Processing...";
  String _appBarTitle = "Processing...";
  bool _isLoading = true;
  final List<String> _steps = [];

  Position? _position;
  // If you want to use local compression, add a compressor here. For now we
  // upload directly to Supabase Storage using the public bucket configured in
  // `lib/services/supabase.dart`.

  @override
  void initState() {
    super.initState();
    _startProcessing();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _startProcessing() async {
    try {
      final locationProvider =
          provider_pkg.Provider.of<LocationProvider>(context, listen: false);

      await locationProvider.fetchLocation();
      _position = locationProvider.currentPosition;
      print(_position);
      // Upload image if provided (preserve existing ML verification flow)
      String? imageUrl;
      String? imageClass;
      String? videoUrl;

      if (widget.imagePath.isNotEmpty) {
        _addStep("Uploading image...");
        final imageResult = await _uploadImage(File(widget.imagePath));
        imageUrl = imageResult['imageUrl'];
        imageClass = imageResult['imageClass'];
      } else {
        _addStep("No image provided, skipping image upload.");
      }

      if (widget.videoPath.isNotEmpty) {
        _addStep("Uploading video...");
        videoUrl = await _uploadVideo(File(widget.videoPath));
      } else {
        _addStep("No video provided, skipping video upload.");
      }

      // Send consolidated data to server (include whichever URLs are available)
      await _sendCombinedDataToServer(imageUrl, imageClass, videoUrl);

      // If everything goes fine
      setState(() {
        _appBarTitle = "Request Sent";
        _statusMessage = "Request is sent";
      });
    } catch (e) {
      _addStep("❌ Error: $e");
      setState(() {
        _appBarTitle = "Request Failed";
        _statusMessage = "Request declined";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _addStep(String step) {
    setState(() {
      _steps.add(step);
      _statusMessage = step;
    });
  }

  // New consolidated sender: accepts optional image and video URLs and sends them
  Future<void> _sendCombinedDataToServer(
      String? imageUrl, String? imageClass, String? videoUrl) async {
    try {
      _addStep("Sending consolidated data to server...");
      final url =
          Uri.parse('https://sos-backend-uj48.onrender.com/send-request');
      final headers = {
        'Content-Type': 'application/json',
      };
      final deviceId = await _getDeviceId();

      final body = {
        "name": widget.name,
        "mobile": widget.mobile,
        "device_id": deviceId,
        "request_type": widget.type,
        "longitude": _position?.longitude,
        "latitude": _position?.latitude,
      };

      if (imageUrl != null && imageUrl.isNotEmpty) {
        body['image_url'] = imageUrl;
        if (imageClass != null) body['image_classification'] = imageClass;
      }
      if (videoUrl != null && videoUrl.isNotEmpty) {
        body['video_url'] = videoUrl;
      }

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        _addStep("✅ Consolidated data sent successfully!");
      } else {
        _addStep("❌ Failed to send consolidated data: ${response.body}");
        setState(() {
          _appBarTitle = "Request Failed";
        });
      }
    } catch (e) {
      _addStep("❌ Error sending consolidated data: $e");
      setState(() {
        _appBarTitle = "Request Failed";
      });
    }
  }

  Future<String> _getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? "unknown_ios";
    }
    return "unknown_device";
  }

  Future<File> _compressImage(File file) async {
    try {
      final originalPath = file.absolute.path;
      // Build a target path with _compressed suffix (always JPEG output)
      final extIndex = originalPath.lastIndexOf('.');
      final targetPath = extIndex != -1
          ? '${originalPath.substring(0, extIndex)}_compressed.jpg'
          : '${originalPath}_compressed.jpg';
      final compressed = await FlutterImageCompress.compressAndGetFile(
        originalPath,
        targetPath,
        quality: 75,
        minWidth: 1280,
        minHeight: 720,
        format: CompressFormat.jpeg,
        keepExif: false,
      );
      if (compressed == null) return file; // fallback
      final originalSize = await file.length();
      final newSize = await compressed.length();
      _addStep(
          "Compressed image ${(originalSize / 1024).toStringAsFixed(1)}KB -> ${(newSize / 1024).toStringAsFixed(1)}KB");
      return File(compressed.path);
    } catch (e) {
      _addStep("Compression failed, using original: $e");
      return file;
    }
  }

  Future<Map<String, String?>> _uploadImage(File imageFile) async {
    try {
      // Compress before upload
      final toUpload = await _compressImage(imageFile);
      final url =
          Uri.parse('https://sos-backend-uj48.onrender.com/upload-file');
      final request = http.MultipartRequest('POST', url);

      request.files.add(await http.MultipartFile.fromPath(
        'image',
        toUpload.path,
      ));
      request.fields['requestType'] = widget.type;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final imageUrl =
            data['imageUrl'] ?? data['fileUrl'] ?? data['url'] ?? '';
        final imageClass = data['predictionClassification'] ??
            data['image_classification'] ??
            '';
        print('uploadImage response data: $data');
        _addStep("✅ Image uploaded successfully!");
        return {
          'imageUrl': imageUrl as String,
          'imageClass': imageClass as String,
        };
      } else {
        _addStep(
            "❌ Failed to upload image: ${response.statusCode} - ${response.reasonPhrase}");
        setState(() {
          _appBarTitle = "Request Failed";
        });
        return {'imageUrl': null, 'imageClass': null};
      }
    } catch (e) {
      _addStep("❌ Error uploading image: $e");
      setState(() {
        _appBarTitle = "Request Failed";
      });
      return {'imageUrl': null, 'imageClass': null};
    }
  }

  // Upload video directly (no ML verification) and then notify the server
  Future<String?> _uploadVideo(File videoFile) async {
    const int maxAttempts = 2;
    int attempt = 0;
    while (attempt < maxAttempts) {
      attempt++;
      try {
        // Try direct upload to Supabase Storage first. This requires
        // `lib/services/supabase.dart` to contain `supabaseUrl`, `supabaseKey`
        // and `supabaseBucket` (bucket must exist and be public or have
        // appropriate access rules).
        try {
          _addStep('Uploading video directly to Supabase Storage...');
          final uploadedUrl = await _uploadVideoToSupabase(videoFile);
          if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
            _addStep('✅ Video uploaded to Supabase: $uploadedUrl');
            return uploadedUrl;
          } else {
            _addStep(
                'Direct Supabase upload returned no URL, falling back to backend upload.');
          }
        } catch (se) {
          _addStep('Supabase upload failed, will try backend upload: $se');
          print('Supabase upload exception: $se');
        }

        // Fallback: upload via backend like before
        final url =
            Uri.parse('https://sos-backend-uj48.onrender.com/upload-file');
        final request = http.MultipartRequest('POST', url);

        request.files.add(await http.MultipartFile.fromPath(
          'video',
          videoFile.path,
        ));
        request.fields['requestType'] = widget.type;

        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          // backend may return different keys; try common ones
          final videoUrl =
              data['videoUrl'] ?? data['fileUrl'] ?? data['url'] ?? '';
          print('uploadVideo response data: $data');
          _addStep('✅ Video uploaded successfully!');
          if ((videoUrl as String).isNotEmpty) {
            return videoUrl;
          } else {
            _addStep(
                '❌ Video uploaded but no URL returned from server. Response body: ${response.body}');
            return null;
          }
        } else {
          // Log more details for debugging (body + headers)
          _addStep(
              '❌ Failed to upload video (attempt $attempt): ${response.statusCode} - ${response.reasonPhrase}');
          _addStep('Response body: ${response.body}');
          print(
              'Video upload failed. Status: ${response.statusCode}, Headers: ${response.headers}, Body: ${response.body}');

          if (attempt >= maxAttempts) {
            setState(() {
              _appBarTitle = 'Request Failed';
            });
            return null;
          }

          // Small delay before retrying
          await Future.delayed(const Duration(seconds: 2));
        }
      } catch (e, st) {
        _addStep('❌ Error uploading video (attempt $attempt): $e');
        print('Exception uploading video: $e\n$st');
        if (attempt >= maxAttempts) {
          setState(() {
            _appBarTitle = 'Request Failed';
          });
          return null;
        }
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    // If we exit the loop without success
    return null;
  }

  // Upload file directly to Supabase Storage and return public URL.
  Future<String?> _uploadVideoToSupabase(File file) async {
    try {
      if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
        _addStep('Supabase configuration missing - skip direct upload.');
        return null;
      }

      final client = SupabaseClient(supabaseUrl, supabaseKey);
      const bucket = supabaseBucket;
      final fileName =
          'videos/${DateTime.now().millisecondsSinceEpoch}_${p.basename(file.path)}';

      // Upload the file (Supabase flutter client accepts File in upload)
      await client.storage.from(bucket).upload(fileName, file);
      // Construct the public URL for the uploaded object
      final publicUrl =
          '${supabaseUrl.replaceAll(RegExp(r'\/$'), '')}/storage/v1/object/public/$bucket/$fileName';
      return publicUrl;
    } catch (e) {
      _addStep('❌ Supabase upload exception: $e');
      print('Supabase upload exception: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitle),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Processing Steps:",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: _steps.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: Icon(
                        _steps[index].startsWith("✅")
                            ? Icons.check_circle
                            : _steps[index].startsWith("❌")
                                ? Icons.error
                                : Icons.info,
                        color: _steps[index].startsWith("✅")
                            ? Colors.green
                            : _steps[index].startsWith("❌")
                                ? Colors.red
                                : Colors.blue,
                      ),
                      title: Text(
                        _steps[index],
                        style: const TextStyle(fontSize: 16),
                      ),
                    );
                  },
                ),
              ),
              if (_isLoading)
                const Center(
                  child: CircularProgressIndicator(),
                )
              else
                Center(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 12),
                      backgroundColor: Colors.blue,
                    ),
                    child: const Text(
                      "Back",
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
