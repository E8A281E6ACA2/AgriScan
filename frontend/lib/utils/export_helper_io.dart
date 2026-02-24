import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

Future<String> saveBytesAsFile(String filename, Uint8List bytes, {String contentType = 'text/csv'}) async {
	final dir = await getTemporaryDirectory();
	final file = File('${dir.path}/$filename');
	await file.writeAsBytes(bytes, flush: true);
	return file.path;
}
