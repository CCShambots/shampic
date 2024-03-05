
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shampic/Session.dart';
import 'package:shampic/camera.dart';
import 'package:shampic/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:http/http.dart' as http;


class Photo extends StatefulWidget {
  const Photo({super.key});

  @override
  PhotoState createState() =>
      PhotoState();
}

class PhotoState extends State<Photo> {
  List<String> teams = [];

  bool teamHasImage = false;
  String apiBase = "";
  String year = "";

  @override
  void initState() {
    super.initState();

    loadTeams();
    loadData();
  }

  Future<void> loadTeams() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    if(mounted) {
      setState(() {
        teams = prefs.getStringList("teams") ?? [];
      });
    }
  }

  Future<void> loadData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    setState(() {
      apiBase = prefs.getString("api")!;
      year = prefs.getString("year")!;
    });
  }

  void openPhotoWindow(String number, BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => Camera(number: number, camera: CameraContainer.cameras.first,)))
        .then((value) {
      loadTeams();
    });
  }

  var teamNumController = TextEditingController();

  void openSearchModal(BuildContext context) {
    showDialog(context: context, builder: (BuildContext context) =>
        AlertDialog(
          content:  StatefulBuilder(  // You need this, notice the parameters below:
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Search for Team"),
                  TextField(
                    decoration: const InputDecoration(
                        border: UnderlineInputBorder(),
                        labelText: 'Enter Team Number'
                    ),
                    controller: teamNumController,
                    onChanged: (value) async {

                      http.Response getResponse = await Session.get("$apiBase/bytes/");

                      List<dynamic> existingKeysDynamic = jsonDecode(getResponse.body);

                      List<String> existingKeys = existingKeysDynamic.map((e) => e as String).toList();

                      bool alreadyExists = existingKeys.contains("$value-img-$year");

                      //Only update the state if the input field hasn't changed since we started the pull
                      if(value == teamNumController.text) {
                        setState(() {
                          teamHasImage = alreadyExists;
                        });
                      }
                    },
                    maxLength: 4,
                    keyboardType: TextInputType.number,
                  ),
                  teamHasImage ?
                  const Text("Team Has a Photo!",
                      style: TextStyle(color: Colors.green)) :
                  const Text("Team Doesn't Have a Photo Yet!",
                      style: TextStyle(color: Colors.red))
                ]);
          }),
            actions: <TextButton>[
            TextButton(onPressed: () {
                openPhotoWindow(teamNumController.text, context);
              }, child: const Text("Take Photo of Team"),)
            ]
        )
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        primary: false,
        slivers: [
          SliverPadding(
              padding: const EdgeInsets.all(10),
            sliver: SliverGrid.count(
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              crossAxisCount: 2,

              children:
              teams.map((e) =>
                InkWell(
                  onTap: () {
                    openPhotoWindow(e, context);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.all(Radius.circular(12)),
                      color: Theme.of(context).colorScheme.inversePrimary
                    ),
                    child: Center(
                          child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 48)),
                    )
                  ),
                )
              ).toList()
              ,
            ),
          )]
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          openSearchModal(context);
        },
        child: const Icon(Icons.search),
      ),
    );
  }


}