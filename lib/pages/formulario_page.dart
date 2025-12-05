import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:appcbm/api/cbm_api.dart';
import 'package:appcbm/api/cbm_models.dart';

class FormularioPage extends StatefulWidget {
  final String token;
  final Map<String, dynamic> me;
  final String assetId;
  final Equipment? equipment;

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
      _numSerieController.text = widget.assetId;
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

  @override
  void dispose() {
    _salaController.dispose();
    _equipamentoController.dispose();
    _numSerieController.dispose();
    _obsController.dispose();
    super.dispose();
  }

  Future<void> _enviarChamado() async {
    if (!_formKey.currentState!.validate()) return;

    final meId = widget.me['id']?.toString() ?? '';
    final equipId = widget.equipment?.id?.toString();

    if (equipId == null || equipId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro: Equipamento não identificado.')),
      );
      return;
    }

    final fields = {
      'name': 'Chamado via App',
      'description': _obsController.text.trim(),
      'suggested_date': DateTime.now()
          .add(const Duration(days: 3))
          .toIso8601String(),
      'urgency_level': 'MEDIUM',
      'creator_FK': meId,
      'equipments_FK': [equipId],
      'responsibles_FK': [meId],
    };

    try {
      await _api.createTask(
        fields,
        imageFile: _imageFile != null ? File(_imageFile!.path) : null,
        token: widget.token,
      );

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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ===== CABEÇALHO (BALÃO E ROBÔ NO LADO DIREITO) =====
                        SizedBox(
                          height: 140,
                          child: LayoutBuilder(
                            builder: (context, c) {
                              final w = c.maxWidth;
                              final bubbleW = w.clamp(260, 360) * 0.58;
                              final robotW = 82.0;

                              return Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  // Balão espelhado (lado direito e acima do robô)
                                  Positioned(
                                    top: -50,
                                    right: robotW - 8,
                                    child: SizedBox(
                                      width: bubbleW,
                                      child: Transform(
                                        alignment: Alignment.center,
                                        transform: Matrix4.rotationY(
                                          3.1416,
                                        ), // espelha
                                        child: Image.asset(
                                          'assets/balaoHome.png',
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Texto dentro do balão
                                  Positioned(
                                    top: 28,
                                    right: robotW + 30,
                                    left: 30,
                                    child: const Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        'Confirme os Dados',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Robô mais abaixo (lado direito)
                                  Positioned(
                                    top: 46,
                                    right: -20,
                                    child: SizedBox(
                                      width: robotW,
                                      child: Image.asset(
                                        'assets/roboForms.png',
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ==================== CAMPOS ====================
                        _buildTextField(
                          label: 'Sala',
                          controller: _salaController,
                          readOnly: true,
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          label: 'Equipamento',
                          controller: _equipamentoController,
                          readOnly: true,
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          label: 'Num - Série',
                          controller: _numSerieController,
                          readOnly: true,
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          label: 'Observações',
                          controller: _obsController,
                          hint: 'Descreva o problema',
                          maxLines: 3,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Por favor, descreva o problema.'
                              : null,
                        ),
                        const SizedBox(height: 16),

                        // ==================== FOTO ANEXADA ====================
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

                        // ==================== BOTÕES ====================
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
                            backgroundColor: const Color(0xFF333333),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
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
