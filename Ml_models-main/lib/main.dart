import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tflite/flutter_tflite.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:local_auth/local_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  final frontCamera = cameras.firstWhere(
    (camera) => camera.lensDirection == CameraLensDirection.back,
    orElse: () => cameras.first,
  );

  runApp(MyApp(camera: frontCamera));
}

class MyApp extends StatelessWidget {
  final CameraDescription camera;

  const MyApp({Key? key, required this.camera}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ML Models',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.black,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: AuthenticationScreen(camera: camera),
    );
  }
}

class AuthenticationScreen extends StatefulWidget {
  final CameraDescription camera;

  const AuthenticationScreen({Key? key, required this.camera})
      : super(key: key);

  @override
  _AuthenticationScreenState createState() => _AuthenticationScreenState();
}

class _AuthenticationScreenState extends State<AuthenticationScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    _authenticate();
  }

  Future<void> _authenticate() async {
    try {
      setState(() {
        _isAuthenticating = true;
      });
      bool authenticated = await auth.authenticate(
        localizedReason: 'Please authenticate to access the app',
        options: const AuthenticationOptions(
          useErrorDialogs: true,
          stickyAuth: true,
        ),
      );
      setState(() {
        _isAuthenticating = false;
      });
      if (authenticated) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => MyHomePage(camera: widget.camera)),
        );
      }
    } on PlatformException catch (e) {
      setState(() {
        _isAuthenticating = false;
      });
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _isAuthenticating
            ? const CircularProgressIndicator()
            : const Text(''),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final CameraDescription camera;

  const MyHomePage({Key? key, required this.camera}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;

  static late List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    _widgetOptions = <Widget>[
      ModelsPage(camera: widget.camera),
      SettingsPage(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Theme(
              data: Theme.of(context).copyWith(
                iconTheme: IconThemeData(
                  size: 30, // Size of the icon
                  color: Colors.white, // Color of the icon
                ),
              ),
              child: Icon(Icons.article),
            ),
            label: 'Models',
          ),
          BottomNavigationBarItem(
            icon: Theme(
              data: Theme.of(context).copyWith(
                iconTheme: IconThemeData(
                  size: 30, // Size of the icon
                  color: Colors.white, // Color of the icon
                ),
              ),
              child: Icon(Icons.settings),
            ),
            label: 'Settings',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.white, // Color of the selected item
        unselectedItemColor: Colors.grey, // Color of the unselected item
        type: BottomNavigationBarType.fixed, // Type of the navigation bar
      ),
    );
  }
}

class ModelsPage extends StatelessWidget {
  final CameraDescription camera;

  const ModelsPage({Key? key, required this.camera}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Models'),
      ),
      body: GridView.count(
        crossAxisCount: 3,
        crossAxisSpacing: 5,
        mainAxisSpacing: 20,
        children: [
          ModelItem(
            label: 'Emotion Detection',
            image: AssetImage('assets/emotion.png'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EmotionDetectionPage(camera: camera),
                ),
              );
            },
          ),
          ModelItem(
            label: 'Object Detection',
            image: AssetImage('assets/object.png'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ObjectDetectionPage(camera: camera),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class ModelItem extends StatelessWidget {
  final String label;
  final ImageProvider image;
  final VoidCallback onTap;

  const ModelItem({
    required this.label,
    required this.image,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Image(
            image: image,
            width: 80,
            height: 80,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.black
                : Colors.white,
          ),
        ),
      ],
    );
  }
}

class EmotionDetectionPage extends StatefulWidget {
  final CameraDescription camera;

  const EmotionDetectionPage({Key? key, required this.camera})
      : super(key: key);

  @override
  _EmotionDetectionPageState createState() => _EmotionDetectionPageState();
}

class _EmotionDetectionPageState extends State<EmotionDetectionPage> {
  CameraController? _cameraController;
  bool _isDetecting = false;
  String _label = '';
  double _confidence = 0.0;
  bool _isFrontCamera = false;

  @override
  void initState() {
    super.initState();
    _tfLiteInit();
    _initializeCamera();
  }

  Future<void> _tfLiteInit() async {
    String? res = await Tflite.loadModel(
      model: "assets/emotion.tflite",
      labels: "assets/emotion.txt",
      numThreads: 1,
      isAsset: true,
      useGpuDelegate: false,
    );
  }

  void _initializeCamera() async {
    final cameras = await availableCameras();
    final camera = _isFrontCamera
        ? cameras.firstWhere((camera) => camera.lensDirection == CameraLensDirection.front)
        : cameras.firstWhere((camera) => camera.lensDirection == CameraLensDirection.back);

    _cameraController = CameraController(
      camera,
      ResolutionPreset.medium,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _cameraController!.initialize();
    _cameraController!.startImageStream((CameraImage image) {
      if (!_isDetecting) {
        _isDetecting = true;
        _runModelOnFrame(image).then((recognitions) {
          if (recognitions == null) {
            debugPrint("Recognitions is Null");
            return;
          }
          debugPrint(recognitions.toString());
          setState(() {
            _confidence = (recognitions[0]['confidence'] * 100);
            _label = recognitions[0]['label'].toString();
          });
          _isDetecting = false;
        });
      }
    });

    if (mounted) {
      setState(() {});
    }
  }

  Future<List<dynamic>?> _runModelOnFrame(CameraImage image) async {
    return await Tflite.runModelOnFrame(
      bytesList: image.planes.map((plane) {
        return plane.bytes;
      }).toList(),
      imageHeight: image.height,
      imageWidth: image.width,
      imageMean: 0.0,
      imageStd: 255.0,
      rotation: -90, // Adjust rotation if needed based on camera orientation
      numResults: 2,
      threshold: 0.2,
      asynch: true,
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    Tflite.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Emotion Detection"),
      ),
      body: Center(
        child: Column(
          children: [
            _cameraController == null || !_cameraController!.value.isInitialized
                ? Center(child: CircularProgressIndicator())
                : CameraPreview(_cameraController!),
            SizedBox(height: 12),
            Text(
              _label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isFrontCamera = !_isFrontCamera;
                });
                _initializeCamera(); // Re-initialize the camera
              },
              child: Text(_isFrontCamera ? 'Switch to Back Camera' : 'Switch to Front Camera'),
            ),
          ],
        ),
      ),
    );
  }

}

class SettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      body: _SettingState(),
    );
  }
}

class _SettingState extends StatelessWidget {
  int versionTapCount = 0;
  TextEditingController versionController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: <Widget>[
        ListTile(
          leading: Icon(Icons.account_circle),
          title: Text('Profile'),
          onTap: () {
            _showProfile(context);
          },
        ),
        ListTile(
          leading: Icon(Icons.info),
          title: Text('Model Info'),
          onTap: () {
            _modelInfo(context);
          },
        ),
        ListTile(
          leading: Icon(Icons.phone_android),
          title: Text('Version'),
          onTap: () {
            versionTapCount++;
            if (versionTapCount == 3) {
              _showVersionInfo(context);
              versionTapCount = 0;
            }
          },
        ),
        ListTile(
          leading: Icon(Icons.feedback),
          title: Text('Feedback'),
          onTap: () {
            _feedback(context);
          },
        ),
      ],
    );
  }

  void _showVersionInfo(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Center(
          child: Text(
            'Version: v1',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _feedback(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => FeedbackScreen()),
    );
  }
}

void _modelInfo(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => ModelInfoScreen()),
  );
}

class ModelInfoScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Model Info'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildModelInfoItem('Name', 'ML Models'),
          _buildModelInfoItem('Version', '1'),
          _buildModelInfoItem('Country', 'India'),
          _buildModelInfoItem('Application Type', 'Mobile Application'),
          _buildModelInfoItem('Release Date', 'June 2024'),
          _buildModelInfoItem('Features', 'Live Detection Models'),
          _buildModelInfoItem('Technology', 'Flutter'),
          _buildModelInfoItem('Supported Platforms', 'Android , IOS'),
          _buildModelInfoItem('Language', 'Dart'),
          _buildModelInfoItem(
              'Developer', 'SOHAM SONI', context, 'SAMARTH SONI', context),
        ],
      ),
    );
  }

  Widget _buildModelInfoItem(String title, String value,
      [BuildContext? context,
      String? secondaryValue,
      BuildContext? secondaryContext]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title + ':',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: value == 'SOHAM SONI' && context != null
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => SocialMediaScreen(
                                    title: 'Soham Soni',
                                    image: 'assets/s.jpg',
                                    socialMediaLinks: {
                                      'GitHub': 'https://github.com/Soham2212004',
                                      'LinkedIn':
                                          'https://www.linkedin.com/in/soham-soni-2342b4239',
                                      'Credly':
                                          'https://www.credly.com/users/soni-soham',
                                      'Instagram':
                                          'https://www.instagram.com/_soham_soni_',
                                      'Cloud':
                                          'https://www.cloudskillsboost.google/public_profiles/6ebb4fad-af6b-4520-8d47-8a16a23a0df4'
                                    },
                                  )),
                        );
                      }
                    : null,
                child: Text(
                  value,
                  style: value == 'SOHAM SONI'
                      ? TextStyle(color: Colors.blue)
                      : TextStyle(),
                ),
              ),
              if (secondaryValue != null) ...[
                Text(' / '),
                GestureDetector(
                  onTap: secondaryValue == 'SAMARTH SONI' &&
                          secondaryContext != null
                      ? () {
                          Navigator.push(
                            secondaryContext,
                            MaterialPageRoute(
                                builder: (context) => SocialMediaScreen(
                                      title: 'Samarth Soni',
                                      image: 'assets/samarth.jpg',
                                      socialMediaLinks: {
                                        'GitHub':
                                            'https://github.com/samarthsoni1411',
                                        'LinkedIn':
                                            'https://www.linkedin.com/in/samarth-soni-838485241',
                                      },
                                    )),
                          );
                        }
                      : null,
                  child: Text(
                    secondaryValue,
                    style: secondaryValue == 'SAMARTH SONI'
                        ? TextStyle(color: Colors.blue)
                        : TextStyle(),
                  ),
                ),
              ]
            ],
          ),
        ],
      ),
    );
  }
}

class SocialMediaScreen extends StatefulWidget {
  final String title;
  final String image;
  final Map<String, String> socialMediaLinks;

  SocialMediaScreen(
      {required this.title,
      required this.image,
      required this.socialMediaLinks});

  @override
  _SocialMediaScreenState createState() => _SocialMediaScreenState();
}

class _SocialMediaScreenState extends State<SocialMediaScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _showFront = true;
  bool _socialMediaUp = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleSide() {
    setState(() {
      _showFront = !_showFront;
      if (_showFront) {
        _controller.reverse();
      } else {
        _controller.forward();
      }
    });
  }

  void _toggleSocialMediaDirection() {
    setState(() {
      _socialMediaUp = !_socialMediaUp;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: _toggleSide,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform(
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001) // Perspective
                      ..rotateY(_animation.value * 3.14159), // Y-axis rotation
                    alignment: Alignment.center,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                            100), // Circular border radius
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            spreadRadius: 2,
                            blurRadius: 10,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                            100), // Circular border radius for clip
                        child: Image.asset(widget.image),
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 20),
            Text(
              widget.title,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: widget.socialMediaLinks.entries.map((entry) {
                return AnimatedContainer(
                  duration: Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                  transform: _socialMediaUp
                      ? Matrix4.translationValues(0, -10, 0)
                      : Matrix4.translationValues(0, 10, 0),
                  child: _buildSocialMediaIcon(entry.key, entry.value),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialMediaIcon(String name, String url) {
    String assetPath;
    switch (name) {
      case 'GitHub':
        assetPath = 'assets/github.png';
        break;
      case 'LinkedIn':
        assetPath = 'assets/linkedin.png';
        break;
      case 'Credly':
        assetPath = 'assets/credly.png';
        break;
      case 'Instagram':
        assetPath = 'assets/instagram.png';
        break;
      case 'Cloud':
        assetPath = 'assets/cloud.png';
        break;
      default:
        assetPath = '';
    }

    return GestureDetector(
      onTap: () {
        _launchURL(url);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Image.asset(
          assetPath,
          width: 50,
          height: 50,
        ),
      ),
    );
  }

  void _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    try {
      if (await canLaunch(uri.toString())) {
        await launch(uri.toString(), forceSafariVC: false, forceWebView: false);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      print('Error launching URL: $e');
      print('URL: $url');
      print('Uri: $uri');
    }
  }
}

class FeedbackScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Feedback'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRatingSection(),
          SizedBox(height: 16.0),
          _buildFeedbackTextBox(),
        ],
      ),
    );
  }

  Widget _buildRatingSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        children: [
          Text(
            'Rating:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(width: 16.0),
          _buildStarRating(),
        ],
      ),
    );
  }

  Widget _buildStarRating() {
    // You can use a package like flutter_rating_bar for star ratings
    return RatingBar.builder(
      initialRating: 0,
      minRating: 1,
      direction: Axis.horizontal,
      allowHalfRating: false,
      itemCount: 5,
      itemSize: 32.0,
      itemBuilder: (context, _) => Icon(
        Icons.star,
        color: Colors.amber,
      ),
      onRatingUpdate: (rating) {
        // Handle rating update here
      },
    );
  }

  Widget _buildFeedbackTextBox() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              maxLines: 5,
              maxLength: 150,
              decoration: InputDecoration(
                hintText: 'Write your feedback',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value!.isEmpty) {
                  return 'Please enter your feedback';
                }
                return null;
              },
              onSaved: (value) {
                // Save feedback here
              },
            ),
            SizedBox(
                height: 16.0), // Add space between TextFormField and button
            Center(
              // Center the button horizontally
              child: ElevatedButton(
                onPressed: () {
                  // Implement save functionality here
                },
                child: Text('Send'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showProfile(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text('Profile'),
        content: Text('Name: Soham\nEmail: sonisoham91@gmail.com'),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('Close'),
          ),
        ],
      );
    },
  );
}

class ObjectDetectionPage extends StatefulWidget {
  final CameraDescription camera;

  ObjectDetectionPage({required this.camera});

  @override
  _ObjectDetectionPageState createState() => _ObjectDetectionPageState();
}

class _ObjectDetectionPageState extends State<ObjectDetectionPage> {
  String _model = "Tiny YOLOv2";
  CameraController? _cameraController;
  bool _isDetecting = false;
  List<dynamic>? _recognitions;
  double? _imageWidth;
  double? _imageHeight;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    loadModel();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  _initializeCamera() async {
    _cameraController = CameraController(
      widget.camera,
      ResolutionPreset
          .low, // Try using a lower resolution for better performance
      imageFormatGroup: ImageFormatGroup.yuv420, // Explicitly set image format
    );

    await _cameraController!.initialize();
    _cameraController!.startImageStream((CameraImage image) {
      if (!_isDetecting) {
        _isDetecting = true;
        _runModelOnFrame(image);
      }
    });

    if (mounted) {
      setState(() {});
    }
  }

  loadModel() async {
    Tflite.close();
    try {
      String? res;
      if (_model == "Tiny YOLOv2") {
        res = await Tflite.loadModel(
          model: "assets/yolov2_tiny.tflite",
          labels: "assets/yolov2_tiny.txt",
        );
      }
      print(res);
    } on PlatformException {
      print("Failed to load the model");
    }
  }

  _runModelOnFrame(CameraImage image) async {
    var recognitions = await Tflite.detectObjectOnFrame(
      bytesList: image.planes.map((plane) {
        return plane.bytes;
      }).toList(),
      model: _model == "Tiny YOLOv2" ? "YOLO" : "SSDMobileNet",
      imageHeight: image.height,
      imageWidth: image.width,
      imageMean: 127.5,
      imageStd: 127.5,
      threshold: 0.3, // Adjust threshold as needed
      numResultsPerClass: 1,
      asynch: true,
    );

    setState(() {
      _recognitions = recognitions;
      _imageHeight = image.height.toDouble();
      _imageWidth = image.width.toDouble();
    });

    _isDetecting = false;
  }

  List<Widget> renderBoxes(Size screen) {
    if (_recognitions == null) return [];
    if (_imageWidth == null || _imageHeight == null) return [];

    double factorX = screen.width;
    double factorY = screen.width / _imageWidth! * _imageHeight!;

    Color blue = Colors.red;

    return _recognitions!.map<Widget>((re) {
      return Positioned(
        left: re["rect"]["x"] * factorX,
        top: re["rect"]["y"] * factorY,
        width: re["rect"]["w"] * factorX,
        height: re["rect"]["h"] * factorY,
        child: Container(
          decoration: BoxDecoration(
              border: Border.all(
            color: blue,
            width: 3,
          )),
          child: Text(
            "${re["detectedClass"]} ${(re["confidenceInClass"] * 100).toStringAsFixed(0)}%",
            style: TextStyle(
              background: Paint()..color = blue,
              color: Colors.white,
              fontSize: 15,
            ),
          ),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: Text("Object Detection"),
      ),
      body: _cameraController == null || !_cameraController!.value.isInitialized
          ? Center(child: CircularProgressIndicator())
          : Stack(
              children: <Widget>[
                CameraPreview(_cameraController!),
                ...renderBoxes(size),
              ],
            ),
    );
  }
}
