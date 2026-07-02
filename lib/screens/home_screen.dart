import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SeaTrack Dashboard'),
        backgroundColor: Colors.orange,
      ),
      body: Consumer<AppStateProvider>(
        builder: (context, provider, child) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStatusIndicator(
                  'Notification Access',
                  provider.isNotificationAccessGranted,
                  provider.requestNotificationAccess,
                ),
                const SizedBox(height: 16),
                _buildStatusIndicator(
                  'Battery Optimization Bypass',
                  provider.isBatteryOptimizationIgnored,
                  provider.requestBatteryOptimizationBypass,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Log Monitor',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[400]!),
                    ),
                    padding: const EdgeInsets.all(8.0),
                    child: ListView.builder(
                      itemCount: provider.logs.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Text(
                            provider.logs[index],
                            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusIndicator(String title, bool isGranted, VoidCallback onRequest) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                Icon(
                  isGranted ? Icons.check_circle : Icons.error,
                  color: isGranted ? Colors.green : Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!isGranted)
              ElevatedButton(
                onPressed: onRequest,
                child: const Text('Enable Permission'),
              ),
            if (isGranted)
              const Text('Active', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
