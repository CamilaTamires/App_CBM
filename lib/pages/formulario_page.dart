import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:appcbm/api/cbm_api.dart';
import 'package:appcbm/api/cbm_models.dart';

class FormularioPage extends StatefulWidget {
  final String token;
  final Map<String, dynamic> me; // /auth/users/me/
  final String assetId; // código do QR lido
  final Equipment? equipment; // se a Home já encontrou, vem pronto

  const FormularioPage({
    super.key,
    required this.token,
    required this.me,
    required this.assetId,
    this.equipment,
  });

  @override
  State<FormularioPage> createState() => _FormularioPageState();
}

class _FormularioPageState extends State<FormularioPage> {
  final _formKey = GlobalKey<FormState>();

  // Campos exibidos
  final _salaController = TextEditingController();
  final _equipamentoController = TextEditingController();
  final _numSerieController = TextEditingController();
  final _obsController = TextEditingController();

  bool _isLoading = true;
  XFile? _imageFile;

  final _api = CbmApi();

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  /// Carrega os dados do equipamento:
  /// - Se já veio pelo argumento [widget.equipment], só preenche.
  /// - Senão, busca pelo código lido no QR (getEquipmentByCode).
  Future<void> _carregarDados() async {
    if (widget.equipment != null) {
      _preencherComEquip(widget.equipment!);
      setState(() => _isLoading = false);
      return;
    }

    final equip = await _api.getEquipmentByCode(
      code: widget.assetId,
      token: widget.token,
    );

    if (equip != null) {
      _preencherComEquip(equip);
    } else {
      _equipamentoController.text = 'Equipamento não localizado';
      _numSerieController.text = widget.assetId; // mostra o que veio do QR
      _salaController.text = '';
    }
    setState(() => _isLoading = false);
  }

  /// PREENCHE CAMPOS A PARTIR DO EQUIPAMENTO
  /// - Sala <= environment_FK.name
  /// - Num - Série <= code (se existir) senão id
  void _preencherComEquip(Equipment e) {
    _equipamentoController.text = e.name;
    _numSerieController.text = e.code ?? e.id.toString();
    _salaController.text = e.environment?.name ?? '';
  }

  Future<void> _tirarFoto() async {
    final picker = ImagePicker();
    final foto = await picker.pickImage(source: ImageSource.camera);
    if (foto != null) setState(() => _imageFile = foto);
  }

  @override
  void dispose() {
    _salaController.dispose();
    _equipamentoController.dispose();
    _numSerieController.dispose();
    _obsController.dispose();
    super.dispose();
  }

  /// Envia o chamado ao backend (payload mínimo).
  /// Ajuste para incluir equipments_FK quando necessário.
  Future<void> _enviarChamado() async {
    if (!_formKey.currentState!.validate()) return;

    final meId = (widget.me['id'] ?? 0) as int;

    final payload = {
      'name': 'Chamado via app',
      'description': _obsController.text.trim(),
      'suggested_date': DateTime.now()
          .add(const Duration(days: 3))
          .toIso8601String(),
      'urgency_level': 'MEDIUM',
      'creator_FK': meId,
      // 👉 Se o backend exigir o equipamento, descomente e passe o id certo:
      // 'equipments_FK': [ widget.equipment?.id ?? <id do equipamento buscado> ],
    };

    try {
      await _api.createTask(payload, token: widget.token);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chamado criado com sucesso!')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao criar chamado: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2E2E2E),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : SingleChildScrollView(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.85,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          top: 40,
                          right: -62,
                          child: Image.asset(
                            'assets/roboForms.png',
                            width: 150,
                            filterQuality: FilterQuality.low,
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Align(
                              alignment: const Alignment(0.4, 0),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Image.asset(
                                    'assets/balaoForms.png',
                                    width: 250,
                                    height: 200,
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.low,
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.only(bottom: 35),
                                    child: Text(
                                      'Confirme os Dados',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Sala (vem de environment_FK.name)
                            _buildTextField(
                              label: 'Sala',
                              controller: _salaController,
                              readOnly: true,
                            ),
                            const SizedBox(height: 12),

                            // Nome do equipamento
                            _buildTextField(
                              label: 'Equipamento',
                              controller: _equipamentoController,
                              readOnly: true,
                            ),
                            const SizedBox(height: 12),

                            // Num - Série (mostrando code se houver; senão id)
                            _buildTextField(
                              label: 'Num - Série',
                              controller: _numSerieController,
                              readOnly: true,
                            ),
                            const SizedBox(height: 12),

                            // Observação obrigatória
                            _buildTextField(
                              label: 'Obs.',
                              controller: _obsController,
                              hint: 'Descreva o problema',
                              maxLines: 3,
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Por favor, descreva o problema.'
                                  : null,
                            ),
                            const SizedBox(height: 16),

                            // Pré-visualização da foto (se houver)
                            if (_imageFile != null) ...[
                              const Text(
                                'Foto Anexada:',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(_imageFile!.path),
                                  height: 200,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Botão para tirar foto
                            OutlinedButton.icon(
                              onPressed: _tirarFoto,
                              icon: const Icon(
                                Icons.camera_alt,
                                color: Color(0xFF333333),
                              ),
                              label: const Text(
                                'ANEXAR FOTO',
                                style: TextStyle(color: Color(0xFF333333)),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Color(0xFF333333),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Confirmar chamado
                            ElevatedButton(
                              onPressed: _enviarChamado,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF333333),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'CONFIRMAR CHAMADO',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
    int maxLines = 1,
    bool readOnly = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.black54,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          readOnly: readOnly,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: readOnly ? const Color(0xFFF0F0F0) : Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.grey),
            ),
          ),
        ),
      ],
    );
  }
}
