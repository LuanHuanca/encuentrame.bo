import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';

import '../../../../app/router.dart';
import '../../../../shared/api/rest_client.dart';

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
      // ✅ 1) si no hay sesión, te manda a login y no llama API
      final session = await Amplify.Auth.fetchAuthSession();
      if (!session.isSignedIn) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, AppRoutes.login);
        return;
      }

      // ✅ 2) ahora sí: ya hay token, llama API
      final health = await api.get('/health');      // opcional
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