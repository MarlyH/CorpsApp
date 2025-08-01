import 'dart:convert';
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(color: Colors.white70)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            backgroundColor: Colors.black,
            title: const Text(
              "Scan Result",
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              message,
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    isScanned = false;
                    controller?.resumeCamera();
                  });
                },
                child: const Text(
                  "Scan Again",
                  style: TextStyle(color: Colors.blue),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text(
                  "Done",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

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

      // Decode the JSON response
      final bookingData = Map<String, dynamic>.from(
        await json.decode(response.body),
      );
      _showBookingDetails(bookingData);
    } catch (e) {
      _showMessage("Error: $e");
    }
  }

  void _showBookingDetails(Map<String, dynamic> bookingData) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            backgroundColor: Colors.black,
            title: const Text(
              "Booking Details",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Container(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow(
                    "Attendee",
                    bookingData['attendeeName'] ?? 'N/A',
                  ),
                  _buildDetailRow(
                    "Session",
                    bookingData['sessionType'] ?? 'N/A',
                  ),
                  _buildDetailRow("Date", bookingData['date'] ?? 'N/A'),
                  _buildDetailRow(
                    "Time",
                    "${bookingData['startTime'] ?? 'N/A'} - ${bookingData['endTime'] ?? 'N/A'}",
                  ),
                  _buildDetailRow(
                    "Seat",
                    bookingData['seatNumber']?.toString() ?? 'N/A',
                  ),
                  _buildDetailRow("Status", bookingData['status'] ?? 'N/A'),
                  if (bookingData['isChild'] == true) ...[
                    const Divider(color: Colors.white24, height: 24),
                    _buildDetailRow(
                      "Can Leave Alone",
                      bookingData['canBeLeftAlone'] == true ? 'Yes' : 'No',
                    ),
                    if (bookingData['emergencyContact'] != null) ...[
                      _buildDetailRow(
                        "Emergency Contact",
                        bookingData['emergencyContact']['name'] ?? 'N/A',
                      ),
                      _buildDetailRow(
                        "Contact Phone",
                        bookingData['emergencyContact']['phone'] ?? 'N/A',
                      ),
                    ],
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    isScanned = false;
                    controller?.resumeCamera();
                  });
                },
                child: const Text(
                  "Scan Again",
                  style: TextStyle(color: Colors.blue),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text(
                  "Done",
                  style: TextStyle(color: Colors.white),
                ),
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
        title: const Text(
          'Scan QR Code',
          style: TextStyle(color: Colors.white),
        ),
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
              child:
                  isScanned
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
