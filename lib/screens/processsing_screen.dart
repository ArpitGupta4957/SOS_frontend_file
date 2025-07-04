import 'dart:convert';
import 'dart:io';

import 'package:emergency_app/Provider/location_provider.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:provider/provider.dart';

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

  @override
  void initState() {
    super.initState();
    _startProcessing();
  }

  Future<void> _startProcessing() async {
    try {
      final locationProvider =
          Provider.of<LocationProvider>(context, listen: false);

      await locationProvider.fetchLocation();
      _position = locationProvider.currentPosition;
      print(_position);
      _addStep("Uploading image...");
      await _uploadImage(File(widget.imagePath));

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

  Future<void> _sendDataToServer(String imageUrl, String imageClass) async {
    try {
      _addStep("Sending data to server...");
      final url =
          Uri.parse('https://sos-backend-uj48.onrender.com/send-request');
      final headers = {
        'Content-Type': 'application/json',
      };
      final deviceId = await _getDeviceId();

      final body = {
        "name": widget.name,
        "mobile": widget.mobile,
        "image_url": imageUrl,
        "device_id": deviceId,
        "request_type": widget.type,
        "longitude": _position?.longitude,
        "latitude": _position?.latitude,
        "image_classification": imageClass,
      };

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        _addStep("✅ Data sent successfully!");
      } else {
        _addStep("❌ Failed to send data: ${response.body}");
        setState(() {
          _appBarTitle = "Request Failed";
        });
      }
    } catch (e) {
      _addStep("❌ Error sending data: $e");
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

  Future<void> _uploadImage(File imageFile) async {
    try {
      final url =
          Uri.parse('https://sos-backend-uj48.onrender.com/upload-file');
      final request = http.MultipartRequest('POST', url);

      request.files.add(await http.MultipartFile.fromPath(
        'image',
        imageFile.path,
      ));
      request.fields['requestType'] = widget.type;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final imageUrl = data['imageUrl'];
        final imageClass = data['predictionClassification'];
        print(data);
        _addStep("✅ Image uploaded successfully!");
        await _sendDataToServer(imageUrl, imageClass);
      } else {
        _addStep(
            "❌ Failed to upload image: ${response.statusCode} - ${response.reasonPhrase}");
        setState(() {
          _appBarTitle = "Request Failed";
        });
      }
    } catch (e) {
      _addStep("❌ Error uploading image: $e");
      setState(() {
        _appBarTitle = "Request Failed";
      });
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
