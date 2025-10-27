import 'package:flutter/material.dart';
import 'package:appcbm/api/cbm_api.dart';
import 'formulario_page.dart';
import 'qr_scanner_page.dart';
import 'urgent_form_page.dart';
import 'open_tasks_page.dart'; // <<< nova página de chamados abertos

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _api = CbmApi();

  late final String _token;
  Future<Map<String, dynamic>>? _meFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _token = (args?['token'] as String?) ?? '';

    if (_token.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
      });
      return;
    }

    _meFuture ??= _api.getMe(token: _token);
  }

  Future<void> _abrirChamadoFluxo() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerPage()),
    );

    if (!mounted) return;
    if (code == null || code.trim().isEmpty) return;

    final equip = await _api.getEquipmentByCode(
      code: code.trim(),
      token: _token,
    );

    final me = await _meFuture;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FormularioPage(
          token: _token,
          me: me!,
          assetId: code.trim(),
          equipment: equip,
        ),
      ),
    );
  }

  Future<void> _abrirChamadoUrgente() async {
    final me = await _meFuture;
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UrgentFormPage(token: _token, me: me!),
      ),
    );
  }

  Future<void> _abrirChamadosAbertos() async {
    final me = await _meFuture;
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OpenTasksPage(token: _token, userId: me!['id']),
      ),
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
          height: size.height * 0.6,
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
                    Icons.exit_to_app,
                    color: Colors.black54,
                    size: 30,
                  ),
                  onPressed: () =>
                      Navigator.of(context).pushReplacementNamed('/login'),
                ),
              ),
              Positioned(
                bottom: 80,
                left: -58,
                child: Image.asset(
                  'assets/roboHome.png',
                  width: 199,
                  filterQuality: FilterQuality.low,
                ),
              ),
              Positioned(
                top: 25,
                left: 0,
                right: 0,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.asset(
                      'assets/balaoHome.png',
                      width: 250,
                      filterQuality: FilterQuality.low,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 15),
                      child: FutureBuilder<Map<String, dynamic>>(
                        future: _meFuture,
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Text(
                              'Carregando...',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            );
                          }
                          if (snap.hasError || !snap.hasData) {
                            return const Text(
                              'Bem-vindo',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            );
                          }

                          final me = snap.data!;
                          final displayName =
                              (me['name'] ??
                                      me['username'] ??
                                      me['email'] ??
                                      'Usuário')
                                  .toString();

                          return Text(
                            'Bem vindo $displayName',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 50,
                left: 0,
                right: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _abrirChamadoFluxo,
                      icon: const Icon(Icons.camera_alt, color: Colors.white),
                      label: const Text('Abrir Chamado'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF333333),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    ElevatedButton.icon(
                      onPressed: _abrirChamadoUrgente,
                      icon: const Icon(Icons.warning, color: Colors.white),
                      label: const Text('Chamado Urgente'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    ElevatedButton.icon(
                      onPressed: _abrirChamadosAbertos,
                      icon: const Icon(Icons.list, color: Colors.white),
                      label: const Text('Chamados Abertos'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
