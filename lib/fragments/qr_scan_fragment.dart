import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

import '../services/auth_http_client.dart';


class QrScanFragment extends StatefulWidget {
  const QrScanFragment({super.key});

  @override
  State<QrScanFragment> createState() => _QrScanFragmentState();
}

class _QrScanFragmentState extends State<QrScanFragment> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool isScanned = false;

  @override
  void reassemble() {
    super.reassemble();
    if (controller != null) {
      controller!.pauseCamera();
      controller!.resumeCamera();
    }
  }

  void _onQRViewCreated(QRViewController ctrl) {
    controller = ctrl;
    controller!.scannedDataStream.listen((scanData) {
      if (!isScanned) {
        setState(() => isScanned = true);
        controller!.pauseCamera();

        // TODO: Handle the QR scan result here
        _handleScannedCode(scanData.code);
      }
    });
  }

  void _handleScannedCode(String? code) async {
    if (code == null || code.isEmpty) return;

    try {
      final response = await AuthHttpClient.post(
        '/api/booking/scan',
        body: {'qrCodeData': code},
      );

      _showMessage("Success: Booking status updated.");
    } catch (e) {
      _showMessage("Error: $e");
    }
  }

  void _showMessage(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text("Scan Result", style: TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                isScanned = false;
                controller?.resumeCamera();
              });
            },
            child: const Text("Scan Again", style: TextStyle(color: Colors.blue)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text("Done", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }


  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Scan QR Code', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: QRView(
              key: qrKey,
              onQRViewCreated: _onQRViewCreated,
              overlay: QrScannerOverlayShape(
                borderColor: Colors.white,
                borderRadius: 12,
                borderLength: 30,
                borderWidth: 8,
                cutOutSize: MediaQuery.of(context).size.width * 0.8,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: isScanned
                  ? const Text(
                      "QR Code scanned.",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    )
                  : const Text(
                      "Align the QR code inside the box.",
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
