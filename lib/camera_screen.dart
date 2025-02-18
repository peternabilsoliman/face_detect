import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'home_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _cameraController;
  late FaceDetector _faceDetector;
  bool _isDetecting = false;
  bool _isCameraInitialized = false;
  bool _faceDetected = false;
  int _selectedCameraIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: true,
        enableClassification: true,
      ),
    );
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    final selectedCamera = cameras[_selectedCameraIndex];
    _cameraController = CameraController(
      selectedCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _cameraController.initialize();
    if (!mounted) return;

    setState(() => _isCameraInitialized = true);
    _startFaceDetection();
  }

  void _startFaceDetection() {
    _cameraController.startImageStream((CameraImage image) async {
      if (_isDetecting) return;
      _isDetecting = true;

      try {
        final inputImage = _convertCameraImageToInputImage(image);
        final faces = await _faceDetector.processImage(inputImage);

        if (faces.isNotEmpty && !_faceDetected) {
          _faceDetected = true;
          await _cameraController.stopImageStream();
          await _navigateToHomeScreen();
        }
      } catch (e) {
        print("❌ خطأ أثناء تحليل الوجه: $e");
      }

      _isDetecting = false;
    });
  }

  InputImage _convertCameraImageToInputImage(CameraImage image) {
    final WriteBuffer buffer = WriteBuffer();
    for (var plane in image.planes) {
      buffer.putUint8List(plane.bytes);
    }
    final Uint8List bytes = buffer.done().buffer.asUint8List();

    final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());
    final InputImageRotation imageRotation = _getImageRotation();

    // تحديث الكود ليكون متوافقًا مع التحديثات الجديدة
    final inputImageData = InputImageMetadata(
      size: imageSize,
      rotation: imageRotation,
      format: InputImageFormat.yuv_420_888,
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: inputImageData);
  }

  InputImageRotation _getImageRotation() {
    return _selectedCameraIndex == 1
        ? InputImageRotation.rotation270deg
        : InputImageRotation.rotation90deg;
  }

  Future<void> _navigateToHomeScreen() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  void _switchCamera() async {
    final cameras = await availableCameras();
    _selectedCameraIndex = (_selectedCameraIndex + 1) % cameras.length;
    await _cameraController.dispose();
    setState(() => _isCameraInitialized = false);
    _initializeCamera();
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        alignment: Alignment.center,
        children: [
          _isCameraInitialized
              ? ClipOval(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: CameraPreview(_cameraController),
                  ),
                )
              : const Center(child: CircularProgressIndicator()),
          Positioned(
            bottom: 20,
            child: ElevatedButton(
              onPressed: _switchCamera,
              child: const Icon(Icons.switch_camera),
            ),
          ),
        ],
      ),
    );
  }
}
