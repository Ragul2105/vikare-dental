import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart';

/// Thin, UI-agnostic wrapper around Google ML Kit Digital Ink Recognition.
///
/// Handles the on-device language-model lifecycle (download once, then works
/// offline) and turns captured [Ink] strokes into text. Kept free of any
/// Flutter widget imports so it can be unit-tested with `mocktail`.
class DigitalInkService {
  DigitalInkService({this.languageCode = 'en'})
    : _recognizer = DigitalInkRecognizer(languageCode: languageCode);

  /// BCP-47 language tag of the model, e.g. `en`.
  final String languageCode;

  final DigitalInkRecognizerModelManager _modelManager =
      DigitalInkRecognizerModelManager();
  final DigitalInkRecognizer _recognizer;

  /// Whether the language model is already downloaded and usable offline.
  Future<bool> isModelReady() => _modelManager.isModelDownloaded(languageCode);

  /// Ensures the language model is available, downloading it on first use.
  ///
  /// The download (~20 MB) needs internet once; afterwards recognition works
  /// fully offline. `isWifiRequired: false` allows the download over mobile
  /// data since clinic tablets are not always on Wi-Fi. Returns `true` when the
  /// model is ready to use.
  Future<bool> ensureModelReady() async {
    if (await _modelManager.isModelDownloaded(languageCode)) return true;
    return _modelManager.downloadModel(languageCode, isWifiRequired: false);
  }

  /// Recognizes the handwritten [ink] and returns the best candidate text,
  /// or an empty string when there is nothing to recognize.
  Future<String> recognize(Ink ink) async {
    if (ink.strokes.isEmpty) return '';
    final candidates = await _recognizer.recognize(ink);
    if (candidates.isEmpty) return '';
    return candidates.first.text.trim();
  }

  /// Releases native resources held by the recognizer.
  Future<void> dispose() => _recognizer.close();
}
