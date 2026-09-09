import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:io';

void main() async {
  final apiKey = 'AIzaSyAZrZ9A-CBC4-QRXg4Fw6XR9Xpa-8rvMBk';
  print('Testing Gemini API with key: ' + apiKey);
  
  try {
    final model = GenerativeModel(
      model: 'gemini-3.5-flash',
      apiKey: apiKey,
    );
    
    final response = await model.generateContent([Content.text('مرحبا، أجب بكلمة واحدة: ممتاز')]);
    print('Response: ' + (response.text ?? 'empty'));
    exit(0);
  } catch (e) {
    print('Error caught: ' + e.toString());
    exit(1);
  }
}
