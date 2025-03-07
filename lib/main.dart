import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HDR merger',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomePage(title: 'Home page'),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ImagePicker _picker = ImagePicker();

  // Function to pick image from gallery
  Future<void> _pickImage() async {
    List<XFile>? pickedFiles = await _picker.pickMultiImage();

    if (pickedFiles.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => EditPage(title: 'Edit page', images: pickedFiles),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextButton(
              onPressed: _pickImage,
              child: const Text(
                'Import images',
                style: TextStyle(fontSize: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EditPage extends StatefulWidget {
  EditPage({super.key, required this.title, required this.images});

  final String title;
  final List<XFile> images;
  int selectedIndex = 0;
  Map<int, double> opacityMap = {};

  @override
  State<EditPage> createState() => _EditPageState();
}

class _EditPageState extends State<EditPage> {
  final GlobalKey _globalKey = GlobalKey();

  void _imageSelected(int index) {
    setState(() {
      widget.selectedIndex = index;
    });
  }

  Widget _createBottomImage(widget, index) {
    if (index == widget.selectedIndex) {
      return GestureDetector(
        onTap: () => _imageSelected(index),
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue, width: 3),
            ),
            child: Image.file(
              File(widget.images[index].path),
              width: 94,
              height: 94,
              fit: BoxFit.cover,
            ),
          ),
        ),
      );
    } else {
      return GestureDetector(
        onTap: () => _imageSelected(index),
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: Image.file(
            File(widget.images[index].path),
            width: 100,
            height: 100,
            fit: BoxFit.cover,
          ),
        ),
      );
    }
  }

  Widget _createImageCarrousel() {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: widget.images.length,
        itemBuilder: (context, index) => _createBottomImage(widget, index),
      ),
    );
  }

  Future<Uint8List?> _createFinalImage() async {
    final List<String> imagePaths =
        widget.images.map((xFile) => xFile.path).toList();
    final List<double> opacities = widget.opacityMap.values.toList();

    try {
      // Find the RenderRepaintBoundary using the global key.
      RenderRepaintBoundary? boundary =
          _globalKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return null;

      // Capture the image with the current device pixel ratio.
      ui.Image image = await boundary.toImage(
        pixelRatio: MediaQuery.of(context).devicePixelRatio,
      );
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      return byteData?.buffer.asUint8List();
    } catch (e) {
      print('Error capturing image: $e');
    }
  }

  Future<void> _saveCompositeImage(Uint8List imageBytes) async {
    await Gal.putImageBytes(
      imageBytes,
      album: "hdr_merger",
      name: "merged_${DateTime.now()}",
    );
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing while loading
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text("Exporting image...", style: TextStyle(fontSize: 16)),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Success"),
          content: const Text("Image exported successfully!"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  void _exportImage() async {
    try {
      _showLoadingDialog();
      // Wait for UI update before running heavy processing
      await Future.delayed(Duration(milliseconds: 100));

      print('Exporting image...');
      // Create the composite image.
      Uint8List? compositeBytes = await _createFinalImage();
      if (compositeBytes == null) throw Error();

      // Save the composite image.
      await _saveCompositeImage(compositeBytes);
      print('Image saved!');

      // Close the loading modal
      Navigator.of(context).pop();

      // Show success message
      _showSuccessDialog();

      // Optionally, display a message or update the UI.
    } catch (e) {
      print('Error: $e');
      Navigator.of(context).pop(); // Close the modal if an error occurs
    }
  }

  Widget _createImageControlSection() {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: EdgeInsets.all(12.0),
            child: GestureDetector(
              onTap: _exportImage,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blueAccent,
                  borderRadius: BorderRadius.circular(6.0),
                ),
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(left: 10.0, right: 10.0),
                      child: Text(
                        "Export image",
                        style: TextStyle(color: Colors.white, fontSize: 18.0),
                      ),
                    ),
                    Icon(Icons.save_alt, color: Colors.white, size: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _createLateralOpacityScrollbar() {
    return RotatedBox(
      quarterTurns: -1,
      child: Slider(
        value: _getOpacityValue(widget.selectedIndex),
        min: 0.00,
        max: 1.00,
        activeColor: Colors.blueAccent, // Bar color
        thumbColor: Colors.indigo, // Dot color
        onChanged: (value) {
          setState(() {
            widget.opacityMap[widget.selectedIndex] = value;
          });
        },
      ),
    );
  }

  double _getOpacityValue(int index) {
    double? opacityValue = widget.opacityMap[index];
    if (opacityValue != null) {
      return opacityValue;
    } else {
      return 0.5;
    }
  }

  Widget _createGeneralImage() {
    return Padding(
      padding: EdgeInsets.only(left: 10.0),
      child: RepaintBoundary(
        key: _globalKey,
        child: Stack(
          children:
              widget.images.asMap().entries.map((entry) {
                int index = entry.key;
                XFile imageFile = entry.value;
                return Opacity(
                  opacity: _getOpacityValue(index),
                  child: Image.file(File(imageFile.path)),
                );
              }).toList(),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Initialize opacityMap with a default opacity value for each image.
    for (int i = 0; i < widget.images.length; i++) {
      widget.opacityMap[i] = 0.5;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Expanded(child: _createGeneralImage()),
                _createLateralOpacityScrollbar(),
              ],
            ),
          ),
          _createImageControlSection(),
          _createImageCarrousel(),
        ],
      ),
    );
  }
}
