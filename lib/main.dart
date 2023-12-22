import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shampic/home.dart';
import 'package:shampic/scan.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';


class ConnectionStatus {
  static bool connected = false;

  static const connectionInterval = Duration(seconds: 5);


  static checkConnection() async{

    SharedPreferences prefs = await SharedPreferences.getInstance();

    String apiBase = prefs.getString("api") ?? "";

    //Set the default API location
    if(apiBase == "") {
      apiBase = 'http://167.71.240.213:8080';

      prefs.setString("api", apiBase);
    }

    var url = Uri.parse("$apiBase/status");

    try {
      var response = await http.get(url).timeout(const Duration(seconds: 5), onTimeout: () {
        return http.Response('Disconnected Error', 408);
      });

      bool success = response.statusCode == 200;

      ConnectionStatus.connected = success;

    } catch(e) {
      ConnectionStatus.connected = false;
    }
  }

}

class CameraContainer {
  static late List<CameraDescription> cameras;
}

Future<void> main() async{

  WidgetsFlutterBinding.ensureInitialized();

  CameraContainer.cameras = await availableCameras();
  runApp(const MyApp());

  //Regularly check the api connection

  Timer.periodic(ConnectionStatus.connectionInterval, (timer) {ConnectionStatus.checkConnection();});
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    return MaterialApp(
      title: 'ShamPic',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        scaffoldBackgroundColor: Theme.of(context).colorScheme.background,
      ),
      darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
          brightness: Brightness.dark
      ),

      home: const BottomNavigation(),
    );
  }
}

class BottomNavigation extends StatefulWidget {
  const BottomNavigation({super.key});


  @override
  State<BottomNavigation> createState() => _BottomNavigationState();
}

class _BottomNavigationState extends State<BottomNavigation> {

  int selectedIndex = 1;
  final pageViewController = PageController(initialPage: 2);

  bool connection = false;

  String version = "";

  @override
  void initState() {
    super.initState();

    loadVersion();

    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        connection = ConnectionStatus.connected;
      });
    });

    Timer.periodic(ConnectionStatus.connectionInterval, (timer) {
      setState(() {
        connection = ConnectionStatus.connected;
      });
    });
  }

  void loadVersion() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();

    setState(() {
      version = packageInfo.version;
    });
  }

  static const List<Widget> widgetOptions = <Widget>[
    Scan(),
    Photo()
  ];

  void onItemTapped(int index) {
    pageViewController.animateToPage(index, duration: Duration(milliseconds: 100), curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    pageViewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text("ShamPic - v$version"),
        actions: [
          IconButton(
            icon: Icon(
              connection ? Icons.cloud_done : Icons.cloud_off,
              color: connection ? Colors.green : Colors.red,
            ),
            tooltip: connection ? "API Connected" : "API Disconnected",
            onPressed: null,
          )
        ],
      ),
      body: PageView(
        controller: pageViewController,
        children: widgetOptions,
        onPageChanged: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
              icon: Icon(Icons.qr_code),
              label: "QR Code"
          ),
          BottomNavigationBarItem(
              icon: Icon(Icons.camera_alt),
              label: "Home"
          ),
        ],
        currentIndex: selectedIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(context).colorScheme.onBackground,
        unselectedLabelStyle: TextStyle(color: Theme.of(context).colorScheme.onBackground),
        onTap: onItemTapped,
      ),
    );
  }
}
