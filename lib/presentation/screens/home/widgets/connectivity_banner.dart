import 'package:flutter/material.dart';

class ConnectivityBanner extends StatelessWidget {
  const ConnectivityBanner({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.red.shade700,
      child: const Row(
        children: [
          Icon(Icons.signal_wifi_off, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'No internet connection. SOS will use SMS/Call fallback.',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
