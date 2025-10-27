import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:appcbm/api/cbm_api.dart';
import 'package:appcbm/api/cbm_models.dart';
import 'qr_scanner_page.dart';

class UrgentFormPage extends StatefulWidget {
  final String token;
  final Map<String, dynamic> me;

  const UrgentFormPage({super.key, required this.token, required this.me});

  @override
  State<UrgentFormPage> createState() => _UrgentFormPageState();
}

class _UrgentFormPageState extends State<UrgentFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _salaController = TextEditingController();
  final _equipamentoController = TextEditingController();
  final _numSerieController = TextEditingController();
  final _obsController = TextEditingController();

  bool _isLoading = true;
  XFile? _imageFile;
  final _api = CbmApi();
  Equipment? _equipment;
  String? _assetId;

  @override
  void initState() {
    super.initState();
    // ✅ Aguarda a tela carregar antes de abrir a câmera
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _lerQrCode();
    });
  }

  Future<void> _lerQrCode() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerPage()),
    );

    if (!mounted || code == null || code.trim().isEmpty) {
      Navigator.pop(context); // se cancelar o scanner, volta
      return;
    }

    _assetId = code.trim();
    await _carregarDados(_assetId!);
  }

  Future<void> _carregarDados(String code) async {
    final equip = await _api.getEquipmentByCode(
      code: code,
      token: widget.token,
    );

    if (equip != null) {
      _preencherComEquip(equip);
      _equipment = equip;
    } else {
      _equipamentoController.text = 'Equipamento não localizado';
      _numSerieController.text = code;
      _salaController.text = '';
    }
    setState(() => _isLoading = false);
  }

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

  Future<void> _enviarChamado() async {
    if (!_formKey.currentState!.validate()) return;

    final meId = widget.me['id']?.toString() ?? '';
    final equipId = _equipment?.id?.toString();

    if (equipId == null || equipId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro: Equipamento não identificado.')),
      );
      return;
    }

    final fields = {
      'name': 'Chamado Urgente via App',
      'description': _obsController.text.trim(),
      'suggested_date': DateTime.now().toIso8601String(),
      'urgency_level': 'HIGH',
      'creator_FK': meId,
      'equipments_FK': [equipId],
      'responsibles_FK': [meId],
      'is_urgent': true,
    };

    try {
      await _api.createTask(
        fields,
        imageFile: _imageFile != null ? File(_imageFile!.path) : null,
        token: widget.token,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chamado urgente criado com sucesso!'),
          backgroundColor: Colors.green,
        ),
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
  void dispose() {
    _salaController.dispose();
    _equipamentoController.dispose();
    _numSerieController.dispose();
    _obsController.dispose();
    super.dispose();
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 16),
                        _buildTextField(
                          label: 'Sala',
                          controller: _salaController,
                          readOnly: true,
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          label: 'Descreva o problema',
                          controller: _obsController,
                          hint: 'Explique o problema encontrado',
                          maxLines: 3,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Por favor, descreva o problema.'
                              : null,
                        ),
                        const SizedBox(height: 16),
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
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
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
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: _enviarChamado,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'FINALIZAR CHAMADO',
                            style: TextStyle(fontSize: 16),
                          ),
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
          ),
        ),
      ],
    );
  }
}
