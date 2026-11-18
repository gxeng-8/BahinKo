import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

Future<String?> recognizeReceiptText(String path) async {
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final inputImage = InputImage.fromFilePath(path);
    final result = await recognizer.processImage(inputImage);
    return result.text;
  } finally {
    await recognizer.close();
  }
}
