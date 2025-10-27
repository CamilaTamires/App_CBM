import 'package:flutter/material.dart';
import 'package:appcbm/api/cbm_api.dart';

class OpenTasksPage extends StatefulWidget {
  final String token;
  final int userId;

  const OpenTasksPage({super.key, required this.token, required this.userId});

  @override
  State<OpenTasksPage> createState() => _OpenTasksPageState();
}

class _OpenTasksPageState extends State<OpenTasksPage> {
  final _api = CbmApi();
  late Future<List<Map<String, dynamic>>> _tasksFuture;

  @override
  void initState() {
    super.initState();
    _tasksFuture = _api.getOpenTasks(
      token: widget.token,
      userId: widget.userId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chamados em Aberto'),
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _tasksFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Erro: ${snap.error}'));
          }
          final tasks = snap.data ?? [];
          if (tasks.isEmpty) {
            return const Center(child: Text('Nenhum chamado aberto.'));
          }

          return ListView.separated(
            itemCount: tasks.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, i) {
              final t = tasks[i];
              return ListTile(
                leading: const Icon(Icons.build_circle, color: Colors.blueGrey),
                title: Text(t['name'] ?? 'Sem título'),
                subtitle: Text(t['description'] ?? ''),
                trailing: Text(
                  t['urgency_level'] ?? '',
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
