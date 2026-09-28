// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';
Future<void> saveBytes(Uint8List bytes,String name,String mime) async {
 final url=html.Url.createObjectUrlFromBlob(html.Blob([bytes],mime));
 final anchor=html.AnchorElement(href:url)..download=name;
 html.document.body!.append(anchor);anchor.click();anchor.remove();
 Future.delayed(const Duration(seconds:30),()=>html.Url.revokeObjectUrl(url));
}
