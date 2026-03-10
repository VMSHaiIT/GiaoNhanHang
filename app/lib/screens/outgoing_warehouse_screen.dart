import 'package:flutter/material.dart';
import '../api_client.dart';
import '../ui/design_system.dart';

class OutgoingWarehouseScreen extends StatelessWidget {
  final ApiClient api;

  const OutgoingWarehouseScreen({super.key, required this.api});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.warehouse,
              size: 80,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(height: AppTheme.spacingL),
            const Text(
              'Kho hàng đi',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            const Text(
              'Màn hình đang được phát triển',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
