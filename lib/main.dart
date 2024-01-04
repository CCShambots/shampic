import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shampic/Session.dart';
import 'package:shampic/home.dart';
import 'package:shampic/scan.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

class ConnectionStatus {
  static bool connected = false;
  static bool openBrowserForCookieGen = false;

  static const connectionInterval = Duration(seconds: 5);

  static checkConnection() async{

    SharedPreferences prefs = await SharedPreferences.getInstance();

    String apiBase = prefs.getString("api") ?? "";

    //Set the default API location
    if(apiBase == "") {
      apiBase = 'https://scout.voth.name:3000/protected';

      prefs.setString("api", apiBase);
    }

    var url = Uri.parse(apiBase);

    try {
      var client = HttpClient();
      var request = await client.getUrl(url);
      request.followRedirects = false;

      int responseCode =
      !Session.cookieExists ?
      (await request.close().timeout(const Duration(seconds: 5))).statusCode :
      (await Session.get(apiBase)).statusCode;

      switch(responseCode) {
        case 200:
          //All good, ready to use
          ConnectionStatus.connected = true;
          openBrowserForCookieGen = false;
          break;
        default:
          //Have no cookie, redirect user to page to generate
          if(!openBrowserForCookieGen) {
            await launchUrl(url);
          }
          openBrowserForCookieGen = true;
          break;
      }

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

  Session.updateCookie();

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

  bool showCookieModal = false;
  bool cookieModalOpen = false;

  String code = "";

  String email = "";
  var emailController = TextEditingController();

  String apiBase = "";

  String version = "";

  @override
  void initState() {
    super.initState();

    loadVersion();
    loadPrefs();

    Future.delayed(const Duration(seconds: 2), () {
      handleConnectionCheckResult();
    });

    Timer.periodic(ConnectionStatus.connectionInterval, (timer) {
      handleConnectionCheckResult();
    });
  }

  void handleConnectionCheckResult() {
    setState(() {
      connection = ConnectionStatus.connected;
      showCookieModal = ConnectionStatus.openBrowserForCookieGen;
    });
  }

  void loadVersion() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();

    setState(() {
      version = packageInfo.version;
    });
  }

  void loadPrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String email = prefs.getString("email") ?? "";
    String apiBase = prefs.getString("api") ?? "";

    emailController.text = email;

    setState(() {
      this.email = email;
      this.apiBase = apiBase;
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

  void updateEmail(String newEmail) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    prefs.setString("email", newEmail);

    setState(() {
      email = newEmail;
    });
  }

  void openModal(BuildContext context) {
    showDialog(context: context, builder: (BuildContext context) =>
        AlertDialog(
            content:  Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Input Login info"),
                TextField(
                  decoration: const InputDecoration(
                    border: UnderlineInputBorder(),
                    labelText: 'Enter Email Address'
                  ),
                  controller: emailController,
                  onChanged: (value) {
                    updateEmail(value);
                  },
                ),
                TextField(
                  decoration: const InputDecoration(
                      border: UnderlineInputBorder(),
                      labelText: 'Enter One-Time Code'
                  ),
                  onChanged: (value) {
                    setState(() {
                      code = value;
                    });
                  },
                )
              ],
            ),
            actions: <TextButton>[
              TextButton(
                  onPressed: () async {
                    setState(() {
                      cookieModalOpen = false;
                      showCookieModal = false;
                    });


                    Uri url = Uri.parse("${apiBase.replaceAll("/protected", "")}/auth/$code/$email");

                    http.Response resp = await http.get(url);
                    SharedPreferences prefs = await SharedPreferences.getInstance();
                    prefs.setString("jwt", resp.body);

                    if(mounted) {
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Submit')
              )
            ]
        )).then((val) {
      setState(() {
        cookieModalOpen = false;
        showCookieModal = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if(showCookieModal && !cookieModalOpen) {
      setState(() {
        cookieModalOpen = true;
      });

      Future.delayed(Duration.zero, () {
        openModal(context);
      });
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text("ShamPic v$version"),
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
