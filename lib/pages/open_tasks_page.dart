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
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF2E2E2E),
      body: Center(
        child: Container(
          width: size.width * 0.85,
          height: size.height * 0.75,
          decoration: BoxDecoration(
            color: const Color(0xFFE0E0E0),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: 5,
                right: 5,
                child: IconButton(
                  icon: const Icon(
                    Icons.close,
                    size: 30,
                    color: Colors.black54,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),

              Positioned(
                bottom: 155,
                right: -5,
                child: Image.asset(
                  'assets/roboForms.png',
                  width: 150,
                  filterQuality: FilterQuality.low,
                ),
              ),

              Positioned(
                top: 40,
                left: 0,
                right: 0,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.asset(
                      'assets/balaoForms.png',
                      width: 200,
                      filterQuality: FilterQuality.low,
                    ),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        "Seus Chamados Abertos",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Positioned.fill(
                top: 260,
                child: Center(
                  child: SizedBox(
                    width: size.width * 0.70,
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: _tasksFuture,
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snap.hasError) {
                          return Center(
                            child: Text(
                              "Erro: ${snap.error}",
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 16,
                              ),
                            ),
                          );
                        }

                        final tasks = snap.data ?? [];

                        if (tasks.isEmpty) {
                          return const Center(
                            child: Text(
                              "Nenhum chamado aberto.",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.only(bottom: 40, right: 50),
                          itemCount: tasks.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 18),
                          itemBuilder: (context, i) {
                            final t = tasks[i];

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t['name'] ?? "Sem título",
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueGrey,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    t['description'] ?? "",
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Align(
                                    alignment: Alignment.bottomRight,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        t['urgency_level'] ?? "",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
