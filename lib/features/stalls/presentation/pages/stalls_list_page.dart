import 'package:flutter/material.dart';

class StallsListPage extends StatelessWidget {
  const StallsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vendor • Mi Puesto')),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('✅ Rol VENDOR guardado en DynamoDB.'),
            SizedBox(height: 12),
            Text('Siguiente: Abrir puesto con Foto + Audio → Bedrock + Rekognition.'),
          ],
        ),
      ),
    );
  }
}