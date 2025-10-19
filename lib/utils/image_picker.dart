import 'dart:io';
import 'package:image_picker/image_picker.dart';

class ImageUtils {
  static Future<File?> pickImageFromGallery() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    return picked != null ? File(picked.path) : null;
  }
}
