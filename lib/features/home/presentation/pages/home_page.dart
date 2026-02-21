import 'package:flutter/material.dart';
import '../../../../shared/api/rest_client.dart';
import '../../../../app/router.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final api = RestClient();

  bool loading = true;
  String log = '';

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      loading = true;
      log = '';
    });

    try {
      final health = await api.get('/health');
      final me = await api.get('/users/me');

      final role = (me['role'] as String?) ?? '';
      setState(() {
        log = 'health: $health\n\nme: $me\n\nrole: "$role"';
      });

      if (!mounted) return;

      if (role.isEmpty) {
        Navigator.pushReplacementNamed(context, AppRoutes.roleSelection);
        return;
      }

      if (role == 'VENDOR') {
        Navigator.pushReplacementNamed(context, AppRoutes.stalls);
        return;
      }

      // BUYER placeholder
      setState(() {
        log += '\n\nBUYER: aún no implementado';
      });
    } catch (e) {
      setState(() {
        log = 'ERROR:\n$e';
      });
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bootstrap API')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(child: Text(log)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _run,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}