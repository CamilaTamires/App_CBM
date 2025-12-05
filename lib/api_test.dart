import 'dart:convert';
import 'package:http/http.dart' as http;

// ===================================================================
// 1. MODELOS DE DADOS
// Classes simples para representar os dados que vêm da API (Users e Equipments).
// ===================================================================

class CustomUser {
  final int id;
  final String username; // Supondo que seu model de usuário tenha um username

  CustomUser({required this.id, required this.username});

  // Factory constructor para criar um CustomUser a partir de um JSON
  factory CustomUser.fromJson(Map<String, dynamic> json) {
    return CustomUser(id: json['id'], username: json['name']);
  }

  @override
  String toString() => 'User(id: $id, username: $username)';
}

class Equipment {
  final int id;
  final String name; // Supondo que seu model de equipamento tenha um nome

  Equipment({required this.id, required this.name});

  // Factory constructor para criar um Equipment a partir de um JSON
  factory Equipment.fromJson(Map<String, dynamic> json) {
    return Equipment(
      id: json['id'],
      name: json['name'], // Ajuste se o nome do campo for outro
    );
  }

  @override
  String toString() => 'Equipment(id: $id, name: $name)';
}

// ===================================================================
// 2. SERVIÇO DA API
// Uma classe que centraliza toda a comunicação com o backend Django.
// ===================================================================

class ApiService {
  //  Use a URL base correta para o seu ambiente.
  final String _baseUrl = 'http://10.109.83.12:8000/api';

  /// Busca a lista de usuários da API.
  Future<List<CustomUser>> getUsers() async {
    final response = await http.get(Uri.parse('$_baseUrl/custom-user/'));

    if (response.statusCode == 200) {
      List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => CustomUser.fromJson(json)).toList();
    } else {
      throw Exception('Falha ao carregar usuários');
    }
  }

  /// Busca a lista de equipamentos da API.
  Future<List<Equipment>> getEquipments() async {
    final response = await http.get(Uri.parse('$_baseUrl/equipment/'));

    if (response.statusCode == 200) {
      List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => Equipment.fromJson(json)).toList();
    } else {
      throw Exception('Falha ao carregar equipamentos');
    }
  }

  /// Cria uma nova tarefa enviando os dados para a API.
  Future<void> createTask(Map<String, dynamic> taskData) async {
    final url = Uri.parse('$_baseUrl/task/');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(taskData),
      );

      if (response.statusCode == 201) {
        // 201 Created
        print('✅ SUCESSO: Tarefa criada com sucesso!');
        print('Resposta da API: ${response.body}');
      } else {
        print('❌ ERRO: Falha ao criar tarefa.');
        print('Status Code: ${response.statusCode}');
        print('Detalhes do Erro: ${response.body}');
      }
    } catch (e) {
      print('❌ ERRO DE CONEXÃO: Não foi possível se conectar à API.');
      print('Detalhes: $e');
    }
  }
}

// ===================================================================
// 3. FUNÇÃO PRINCIPAL (PONTO DE ENTRADA)
// Orquestra a execução: busca dados, simula a seleção e cria a tarefa.
// ===================================================================

// Para executar apenas este arquivo, você pode chamá-lo de uma função main
// em seu app ou usar "dart run lib/api_test.dart" no terminal.
void main() async {
  print("🚀 Iniciando teste de criação de tarefa...");

  final apiService = ApiService();

  try {
    // --- Passo 1: Buscar os dados necessários (usuários e equipamentos) ---
    print("\nBuscando usuários e equipamentos da API...");
    final users = await apiService.getUsers();
    final equipments = await apiService.getEquipments();

    if (users.isEmpty || equipments.isEmpty) {
      print(
        "\n⚠️ Atenção: Não foi possível encontrar usuários ou equipamentos na API. Verifique se há dados cadastrados no seu Django.",
      );
      return;
    }

    print("Dados encontrados:");
    print(users);
    print(equipments);

    // --- Passo 2: Simular a seleção de dados pelo usuário ---
    print("\nSimulando seleção de dados para a nova tarefa...");

    final creator = users.first; // O primeiro usuário da lista será o criador
    final responsibles = users
        .take(2)
        .toList(); // Os dois primeiros serão os responsáveis
    final selectedEquipments = equipments
        .take(1)
        .toList(); // O primeiro equipamento será selecionado

    // Extrai apenas os IDs, que é o que a API espera
    final creatorId = creator.id;
    final responsibleIds = responsibles.map((user) => user.id).toList();
    final equipmentIds = selectedEquipments.map((equip) => equip.id).toList();

    // --- Passo 3: Montar o corpo da requisição (payload) ---
    final Map<String, dynamic> newTaskData = {
      'name': 'Tarefa criada via Flutter',
      'description':
          'Esta é uma tarefa de teste gerada automaticamente pelo script Dart.',
      'suggested_date': DateTime.now()
          .add(const Duration(days: 5))
          .toIso8601String(),
      'urgency_level': 'MEDIUM',
      'creator_FK': creatorId,
      'equipments_FK': equipmentIds,
      'responsibles_FK': responsibleIds,
    };

    print("\nMontando o seguinte payload para enviar:");
    print(jsonEncode(newTaskData));

    // --- Passo 4: Chamar a API para criar a tarefa ---
    print("\nEnviando requisição POST para /api/task/...");
    await apiService.createTask(newTaskData);
  } catch (e) {
    print("\n❌ ERRO GERAL NO PROCESSO: $e");
  } finally {
    print("\n🏁 Teste finalizado.");
  }
}
