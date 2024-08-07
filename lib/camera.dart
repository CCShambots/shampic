import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shampic/Session.dart';
import 'package:shared_preferences/shared_preferences.dart';


// A screen that allows users to take a picture using a given camera.
class Camera extends StatefulWidget {
  const Camera({
    super.key,
    required this.camera,
    required this.number,
  });

  final CameraDescription camera;
  final String number;

  @override
  CameraState createState() => CameraState();
}

class CameraState extends State<Camera> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    // To display the current output from the Camera,
    // create a CameraController.
    _controller = CameraController(
      // Get a specific camera from the list of available cameras.
      widget.camera,
      // Define the resolution to use.
      ResolutionPreset.medium,
    );

    // Next, initialize the controller. This returns a Future.
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    // Dispose of the controller when the widget is disposed.
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Team ${widget.number}')),
      // You must wait until the controller is initialized before displaying the
      // camera preview. Use a FutureBuilder to display a loading spinner until the
      // controller has finished initializing.
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            // If the Future is complete, display the preview.
            return CameraPreview(_controller);
          } else {
            // Otherwise, display a loading indicator.
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            FloatingActionButton(
              onPressed: () async {
                try {
                  final image = await ImagePicker().pickImage(source: ImageSource.gallery);
                  if(image == null) return;
                  final imageTemp = io.File(image.path);

                  final filePath = imageTemp.absolute.path;

                  // Create output file path
                  // eg:- "Volume/VM/abcd_out.jpeg"
                  final lastIndex = filePath.lastIndexOf(new RegExp(r'.jp'));
                  final splitted = filePath.substring(0, (lastIndex));
                  final outPath = "${splitted}_out${filePath.substring(lastIndex)}";

                  var result = await FlutterImageCompress.compressAndGetFile(
                    imageTemp.absolute.path, outPath,
                    quality: 25,
                  );

                  // print(file.lengthSync());
                  // print(result.lengthSync());

                  // return result;

                  // setState(() => this.image = imageTemp);
                  if(context.mounted) {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => DisplayPictureScreen(
                          // Pass the automatically generated path to
                          // the DisplayPictureScreen widget.
                          imagePath: result?.path??"",
                          number: widget.number,
                        ),
                      ),
                    );
                  }

                } on PlatformException catch(e) {
                  print('Failed to pick image: $e');
                }
              },
              child: const Icon(Icons.upload),
            ),
            FloatingActionButton(
              onPressed: () async {
                // Take the Picture in a try / catch block. If anything goes wrong,
                // catch the error.
                try {
                // Ensure that the camera is initialized.
                await _initializeControllerFuture;

                // Attempt to take a picture and get the file `image`
                // where it was saved.
                final image = await _controller.takePicture();

                if (!mounted) return;

                // If the picture was taken, display it on a new screen.
                await Navigator.of(context).push(
                MaterialPageRoute(
                builder: (context) => DisplayPictureScreen(
                  // Pass the automatically generated path to
                  // the DisplayPictureScreen widget.
                  imagePath: image.path,
                  number: widget.number,
                  ),
                  ),
                  );
                } catch (e) {
                  // If an error occurs, log the error to the console.
                  print(e);
                }
              },
              child: const Icon(Icons.camera_alt),
            )
          ],
      ),
    )
    );
  }
}

class DisplayPictureScreen extends StatefulWidget {
  final String imagePath;
  final String number;

  const DisplayPictureScreen({
    super.key,
    required this.imagePath,
    required this.number
  });

  @override
  DisplayPictureScreenState createState() => DisplayPictureScreenState();


}

// A widget that displays the picture taken by the user.
class DisplayPictureScreenState extends State<DisplayPictureScreen> {
  List<String> teams = [];

  String apiBase = "";

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    setState(() {
      teams = prefs.getStringList("teams")!;
      apiBase = prefs.getString("api")!;
    });
  }


  Future<void> removeTeam(String teamToPop) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    List<String> newTeams = teams.where((element) => element != teamToPop).toList();

    prefs.setStringList("teams", newTeams);

    setState(() {
      teams = newTeams;
    });
  }


@override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Photo of Team ${widget.number}')),
      // The image is stored as a file on the device. Use the `Image.file`
      // constructor with the given path to display the image.
      body: Image.file(io.File(widget.imagePath)),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
              FloatingActionButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                heroTag: "btn1",
                child: const Icon(Icons.undo),
              ),
              FloatingActionButton(
                onPressed: () async {
                  SharedPreferences prefs = await SharedPreferences.getInstance();

                  String year = prefs.getString("year")!;

                  Uint8List bytes =  io.File(widget.imagePath).readAsBytesSync();

                  http.Response getResponse = await Session.get("$apiBase/bytes/");

                  List<dynamic> existingKeysDynamic = jsonDecode(getResponse.body);

                  List<String> existingKeys = existingKeysDynamic.map((e) => e as String).toList();

                  bool alreadyExists = existingKeys.contains("${widget.number}-img-$year");

                  String target = "$apiBase/bytes/${widget.number}-img-$year";

                  http.Response response = await (alreadyExists ? Session.patch(target, bytes) : Session.post(target, bytes));

                  if(response.statusCode == 200) {
                    removeTeam(widget.number);
                    if(mounted) {
                      Navigator.of(context).pop();
                      Future.delayed(Duration.zero, () => Navigator.of(context).pop());
                    }
                  }
                },
                heroTag: "btn2",
                child: const Icon(Icons.save),
              )
          ],
        ),
      )
    );
  }
}