import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
Future<void> saveBytes(Uint8List bytes,String name,String mime) async {
 await FilePicker.platform.saveFile(fileName:name,bytes:bytes);
}
