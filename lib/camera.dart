import 'dart:async';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
      appBar: AppBar(title: Text('Take a picture of Team ${widget.number}')),
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
      floatingActionButton: FloatingActionButton(
        // Provide an onPressed callback.
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
      ),
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

  @override
  void initState() {
    super.initState();
    loadTeams();
  }

  Future<void> loadTeams() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    setState(() {
      teams = prefs.getStringList("teams")!;
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
                  Uint8List bytes =  io.File(widget.imagePath).readAsBytesSync();

                  http.Response status = await http.get(Uri.parse("http://192.168.22.41:8080/status"));

                  print(status.statusCode);
                  
                  Uri target = Uri.parse("http://192.168.22.41:8080/bytes/submit/key/${widget.number}-img");

                  http.Response response = await http.put(target, body: bytes);

                  if(response.statusCode == 200) {
                    removeTeam(widget.number);
                    if(mounted) {
                      Navigator.of(context).pop();
                    }
                  }

                  print(target.path);
                  print(response.body);
                  print(response.statusCode);
                  print(bytes);

                  print(widget.imagePath);
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