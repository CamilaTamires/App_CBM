import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'cbm_models.dart';

// ===============================================================
// SERVIÇO DE CONEXÃO COM O BACKEND DJANGO (Djoser + DRF)
// ===============================================================
class CbmApi {
  // Para Web usamos 127.0.0.1; para Android emulator usamos 10.0.2.2
  static final String _host = kIsWeb
      ? 'http://127.0.0.1:8000/'
      : 'http://10.0.2.2:8000/';
  static String get _api => '$_host/api';

  String? _token; // auth_token do Djoser
  String? get token => _token;

  Map<String, String> _headers({bool auth = false, String? token}) {
    final h = <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    };
    final t = token ?? _token;
    if (auth && t != null && t.isNotEmpty) h['Authorization'] = 'Token $t';
    return h;
  }

  // ------------------- Auth (Djoser) -------------------
  Future<void> login({required String email, required String password}) async {
    final url = Uri.parse('$_api/auth/token/login/');
    final res = await http.post(
      url,
      headers: _headers(),
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      _token = data['auth_token'] as String?;
      if (_token == null || _token!.isEmpty) {
        throw Exception('Resposta sem auth_token.');
      }
    } else {
      throw Exception('Falha no login (${res.statusCode}).');
    }
  }

  Future<void> logout() async {
    if (_token == null) return;
    final url = Uri.parse('$_api/auth/token/logout/');
    await http.post(url, headers: _headers(auth: true));
    _token = null;
  }

  bool get isLoggedIn => _token != null;

  // ------------------- User/me -------------------
  Future<Map<String, dynamic>> getMe({required String token}) async {
    final uri = Uri.parse('$_api/auth/users/me/');
    final res = await http.get(
      uri,
      headers: _headers(auth: true, token: token),
    );
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    }
    throw Exception('Erro ${res.statusCode} ao buscar /me: ${res.body}');
  }

  // ------------------- Recursos -------------------
  Future<List<CustomUser>> getUsers({String? token}) async {
    final uri = Uri.parse('$_api/custom-user/');
    final res = await http.get(
      uri,
      headers: _headers(auth: true, token: token),
    );
    if (res.statusCode == 200) {
      final list = jsonDecode(utf8.decode(res.bodyBytes)) as List;
      return list.map((e) => CustomUser.fromJson(e)).toList();
    }
    throw Exception(
      'Erro ${res.statusCode}: não foi possível buscar usuários.',
    );
  }

  Future<List<Equipment>> getEquipments({String? token}) async {
    final uri = Uri.parse('$_api/equipment/');
    final res = await http.get(
      uri,
      headers: _headers(auth: true, token: token),
    );
    if (res.statusCode == 200) {
      final list = jsonDecode(utf8.decode(res.bodyBytes)) as List;
      return list.map((e) => Equipment.fromJson(e)).toList();
    }
    throw Exception(
      'Erro ${res.statusCode}: não foi possível buscar equipamentos.',
    );
  }

  // ------------------- Recurso (detalhe) -------------------
  Future<Equipment?> getEquipmentById({
    required int id,
    required String token,
  }) async {
    final uri = Uri.parse('$_api/equipment/$id/');
    final res = await http.get(
      uri,
      headers: _headers(auth: true, token: token),
    );
    if (res.statusCode == 200) {
      final map =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      return Equipment.fromJson(map);
    }
    if (res.statusCode == 404) return null;
    throw Exception(
      'Erro ${res.statusCode} ao buscar equipamento $id: ${res.body}',
    );
  }

  Future<Equipment?> getEquipmentByCode({
    required String code,
    required String token,
  }) async {
    final id = _extractIdFromQr(code);
    if (id != null) {
      final byId = await getEquipmentById(id: id, token: token);
      if (byId != null) return byId;
    }

    var uri = Uri.parse('$_api/equipment/?search=$code');
    var res = await http.get(uri, headers: _headers(auth: true, token: token));
    if (res.statusCode == 200) {
      final list = jsonDecode(utf8.decode(res.bodyBytes));
      if (list is List && list.isNotEmpty) {
        return Equipment.fromJson(list.first);
      }
    }

    uri = Uri.parse('$_api/equipment/?code=$code');
    res = await http.get(uri, headers: _headers(auth: true, token: token));
    if (res.statusCode == 200) {
      final list = jsonDecode(utf8.decode(res.bodyBytes));
      if (list is List && list.isNotEmpty) {
        return Equipment.fromJson(list.first);
      }
    }
    return null;
  }

  // ------------------- CREATE TASK (com imagem opcional) -------------------
  Future<void> createTask(
    Map<String, dynamic> fields, {
    File? imageFile,
    required String token,
  }) async {
    final uri = Uri.parse('$_api/task/');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(_headers(auth: true, token: token));

    // Adiciona campos, incluindo listas
    fields.forEach((key, value) {
      if (value is List) {
        for (var item in value) {
          request.fields['$key'] = item.toString();
        }
      } else {
        request.fields[key] = value.toString();
      }
    });

    if (imageFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath('photo', imageFile.path),
      );
    }

    final res = await request.send();
    final body = await res.stream.bytesToString();

    if (res.statusCode != 201) {
      throw Exception('Erro ao criar tarefa (${res.statusCode}): $body');
    }
  }

  // ------------------- GET OPEN TASKS -------------------
  Future<List<Map<String, dynamic>>> getOpenTasks({
    required String token,
    required int userId,
  }) async {
    // Ajuste aqui o filtro conforme o backend (por ex: status=open, done, etc)
    final uri = Uri.parse('$_api/task/?creator_FK=$userId');
    final res = await http.get(
      uri,
      headers: _headers(auth: true, token: token),
    );

    if (res.statusCode == 200) {
      final list = jsonDecode(utf8.decode(res.bodyBytes));
      if (list is List) {
        return List<Map<String, dynamic>>.from(list);
      }
    }
    throw Exception('Erro ao buscar chamados abertos (${res.statusCode})');
  }

  // ------------------- Helpers -------------------
  int? _extractIdFromQr(String raw) {
    final s = raw.trim();
    if (RegExp(r'^\d+$').hasMatch(s)) return int.tryParse(s);

    final urlId = RegExp(r'/equipment/(\d+)/?$').firstMatch(s);
    if (urlId != null) return int.tryParse(urlId.group(1)!);

    try {
      final dynamic parsed = jsonDecode(s);
      if (parsed is Map && parsed['id'] != null) {
        return int.tryParse(parsed['id'].toString());
      }
    } catch (_) {}
    return null;
  }
}
