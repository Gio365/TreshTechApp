import 'dart:io';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'profile_screen.dart';

// const String baseUrl = "https://web-apb.vercel.app";
const String baseUrl = "http://10.0.2.2:5000";

class EditProfilePage extends StatefulWidget {
  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController phoneNumberController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final ValueNotifier<File?> _image = ValueNotifier<File?>(null);
  final ValueNotifier<String?> profilePictureUrl = ValueNotifier<String?>(null);
  late Future<void> _profileFuture;
  int userId = 0;
  bool isOffline = false;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadUserId();
    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      isOffline = connectivityResult == ConnectivityResult.none;
    });
  }

  Future<void> _loadUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? storedUserId = prefs.getString("user_id");
    if (storedUserId != null) {
      userId = int.tryParse(storedUserId) ?? 0;
      await _getProfileData();
    }
  }

  Future<void> _getProfileData() async {
    if (userId == 0 || isOffline) return;
    try {
      var response = await Dio().get("$baseUrl/get-profile/$userId");
      if (response.statusCode == 200 && response.data["success"]) {
        var data = response.data["data"];
        fullNameController.text = data["full_name"] ?? "";
        phoneNumberController.text = data["phone_number"] ?? "";
        addressController.text = data["address"] ?? "";
        profilePictureUrl.value = data["profile_picture"];
      }
    } catch (e) {
      print("Error mengambil data profil: $e");
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      _image.value = File(pickedFile.path);
    }
  }

  Future<void> _updateProfile() async {
    if (userId == 0) {
      _showSnackbar(" User ID tidak ditemukan", Colors.red);
      return;
    }
    if (isOffline) {
      _showSnackbar(" Anda sedang offline", Colors.red);
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => ProfileScreen()),
    );

    try {
      var formData = FormData.fromMap({
        "user_id": userId.toString(),
        "full_name": fullNameController.text,
        "phone_number": phoneNumberController.text,
        "address": addressController.text,
        if (_image.value != null)
          "profile_picture": await MultipartFile.fromFile(_image.value!.path),
      });

      var response = await Dio().put("$baseUrl/update-profile", data: formData);

      if (!(response.statusCode == 200 &&
          response.data["message"] == "✅ Profil berhasil diperbarui!")) {
        _showSnackbar(" Gagal memperbarui profil", Colors.red);
      }
    } catch (e) {
      print(" Error saat update profil: $e");
    }
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.warning, color: Colors.white),
            SizedBox(width: 10),
            Text(message),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[50],
      appBar: AppBar(
        title: Text("Edit Profile"),
        backgroundColor: Colors.green,
      ),
      body: FutureBuilder(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          return SingleChildScrollView(
            padding: EdgeInsets.all(20.0),
            child: Column(
              children: [
                if (isOffline) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_off, color: Colors.red, size: 24),
                      SizedBox(width: 8),
                      Text(
                        "Anda sedang offline",
                        style: TextStyle(color: Colors.red, fontSize: 16),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                ],
                Center(
                  child: Stack(
                    children: [
                      ValueListenableBuilder<File?>(
                        valueListenable: _image,
                        builder: (context, image, child) {
                          return CircleAvatar(
                            radius: 60,
                            backgroundImage:
                                image != null
                                    ? FileImage(image)
                                    : (profilePictureUrl.value != null
                                            ? CachedNetworkImageProvider(
                                              profilePictureUrl.value!,
                                            )
                                            : AssetImage(
                                              "assets/default_profile.png",
                                            ))
                                        as ImageProvider,
                            backgroundColor: Colors.grey[200],
                          );
                        },
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          backgroundColor: Colors.green,
                          child: IconButton(
                            icon: Icon(Icons.camera_alt, color: Colors.white),
                            onPressed: _pickImage,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
                _buildTextField(fullNameController, "Nama Lengkap"),
                _buildTextField(phoneNumberController, "Nomor Telepon"),
                _buildTextField(addressController, "Alamat"),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _updateProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  ),
                  child: Text(
                    "Simpan Perubahan",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

Widget _buildTextField(TextEditingController controller, String label) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 10.0),
    child: TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.green[700]),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: Colors.green),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: Colors.green, width: 2),
        ),
      ),
    ),
  );
}
