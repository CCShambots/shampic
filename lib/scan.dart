import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';


class Scan extends StatefulWidget {
  const Scan({super.key});

  @override
  ScanState createState() =>
      ScanState();
}

class ScanState
    extends State<Scan> {
  late MobileScannerController controller = MobileScannerController();
  Barcode? barcode;
  BarcodeCapture? capture;

  bool showModal = false;
  bool modalOpen = false;

  String modalText = "";

  Future<void> onDetect(BarcodeCapture barcode) async {
    capture = barcode;
    setState(() => this.barcode = barcode.barcodes.first);


    if(!modalOpen) {

      if(await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate();
      }

      String codeData = barcode.barcodes.first.displayValue!;

      SharedPreferences prefs = await SharedPreferences.getInstance();

      if(codeData.contains("pho:")) {
        String saveVal = codeData.substring(4);

        List<String> splitVals = saveVal.split(";");

        String year = splitVals[0];
        String teams = splitVals[1];

        prefs.setStringList("teams", teams.split(","));
        prefs.setString("year", year);

        setState(() {
          showModal = true;
          modalText = "Loaded your team assignments!";
        });
      } else if(codeData.contains("api:")) {
        String saveVal = codeData.substring(4);

        prefs.setString("api", saveVal);

        setState(() {
          showModal = true;
          modalText = "Loaded the remote API location!";
        });
      }
    }

  }

  MobileScannerArguments? arguments;

  void openModal(BuildContext context) {
    showDialog(context: context, builder: (BuildContext context) =>
        AlertDialog(
            content: Text(modalText),
            actions: <TextButton>[
              TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      modalOpen = false;
                      showModal = false;
                    });
                  },
                  child: const Text('Close')
              )
            ]
        )).then((val) {
          setState(() {
            modalOpen = false;
            showModal = false;
          });
        });
  }

  @override
  Widget build(BuildContext context) {

    if(showModal && !modalOpen) {

      setState(() {
        modalOpen = true;
      });

      Future.delayed(Duration.zero, () {
        openModal(context);
      });

    }

    final scanWindow = Rect.fromCenter(
      center: MediaQuery.of(context).size.center(Offset.zero),
      width: 200,
      height: 200,
    );
    return Scaffold(
      backgroundColor: Colors.black,
      body: Builder(
        builder: (context) {
          return Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(
                fit: BoxFit.contain,
                scanWindow: scanWindow,
                controller: controller,
                onScannerStarted: (arguments) {
                  setState(() {
                    this.arguments = arguments;
                  });
                },
                onDetect: onDetect,
              ),
              if (barcode != null &&
                  barcode?.corners != null &&
                  arguments != null)
                CustomPaint(
                  painter: BarcodeOverlay(
                    barcode: barcode!,
                    arguments: arguments!,
                    boxFit: BoxFit.contain,
                    capture: capture!,
                  ),
                ),
              CustomPaint(
                painter: ScannerOverlay(scanWindow),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  alignment: Alignment.bottomCenter,
                  height: 100,
                  color: Colors.black.withOpacity(0.4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Center(
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width - 120,
                          height: 50,
                          child: FittedBox(
                            child: Text(
                              'Scan a Code',
                              overflow: TextOverflow.fade,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium!
                                  .copyWith(color: Colors.white),
                              )
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ScannerOverlay extends CustomPainter {
  ScannerOverlay(this.scanWindow);

  final Rect scanWindow;

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()..addRect(Rect.largest);
    final cutoutPath = Path()..addRect(scanWindow);

    final backgroundPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.dstOut;

    final backgroundWithCutout = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cutoutPath,
    );
    canvas.drawPath(backgroundWithCutout, backgroundPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class BarcodeOverlay extends CustomPainter {
  BarcodeOverlay({
    required this.barcode,
    required this.arguments,
    required this.boxFit,
    required this.capture,
  });

  final BarcodeCapture capture;
  final Barcode barcode;
  final MobileScannerArguments arguments;
  final BoxFit boxFit;

  @override
  void paint(Canvas canvas, Size size) {
    if (barcode.corners == null) return;
    final adjustedSize = applyBoxFit(boxFit, arguments.size, size);

    double verticalPadding = size.height - adjustedSize.destination.height;
    double horizontalPadding = size.width - adjustedSize.destination.width;
    if (verticalPadding > 0) {
      verticalPadding = verticalPadding / 2;
    } else {
      verticalPadding = 0;
    }

    if (horizontalPadding > 0) {
      horizontalPadding = horizontalPadding / 2;
    } else {
      horizontalPadding = 0;
    }

    final ratioWidth =
        (Platform.isIOS ? capture.width! : arguments.size.width) /
            adjustedSize.destination.width;
    final ratioHeight =
        (Platform.isIOS ? capture.height! : arguments.size.height) /
            adjustedSize.destination.height;

    final List<Offset> adjustedOffset = [];
    for (final offset in barcode.corners!) {
      adjustedOffset.add(
        Offset(
          offset.dx / ratioWidth + horizontalPadding,
          offset.dy / ratioHeight + verticalPadding,
        ),
      );
    }
    final cutoutPath = Path()..addPolygon(adjustedOffset, true);

    final backgroundPaint = Paint()
      ..color = Colors.red.withOpacity(0.3)
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.dstOut;

    canvas.drawPath(cutoutPath, backgroundPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
