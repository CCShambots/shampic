
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shampic/camera.dart';
import 'package:shampic/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Photo extends StatefulWidget {
  const Photo({Key? key}) : super(key: key);

  @override
  PhotoState createState() =>
      PhotoState();
}

class PhotoState extends State<Photo> {
  List<String> teams = [];

  @override
  void initState() {
    super.initState();

    loadTeams();
  }

  Future<void> loadTeams() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    if(mounted) {
      setState(() {
        teams = prefs.getStringList("teams") ?? [];
      });
    }
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
                    Navigator.of(context).push(MaterialPageRoute(builder: (context) => Camera(number: e, camera: CameraContainer.cameras.first,)))
                        .then((value) {
                      loadTeams();
                    });
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
      )
    );
  }


}