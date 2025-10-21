import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'cbm_models.dart';

// ===============================================================
// SERVIÇO DE CONEXÃO COM O BACKEND DJANGO (Djoser + DRF)
// ===============================================================
class CbmApi {
  // Para Web usamos 127.0.0.1; para Android emulator usamos 10.0.2.2
  static final String _host = kIsWeb
      ? 'http://127.0.0.1:8000'
      : 'http://10.0.2.2:8000';
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
    } else if (res.statusCode == 400 || res.statusCode == 401) {
      final body = _safeJson(res.body);
      final msg =
          body['detail'] ??
          (body['non_field_errors'] is List &&
                  body['non_field_errors'].isNotEmpty
              ? body['non_field_errors'][0]
              : 'Credenciais inválidas');
      throw Exception(msg);
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

  // ------------------- Recursos (listas) -------------------
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
  /// Busca um equipamento pelo ID no endpoint de detalhe: /api/equipment/<id>/
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

  /// Busca equipamento a partir do conteúdo do QR.
  /// 1) Tenta extrair um ID (número, URL com /equipment/<id>/, ou JSON {"id":...})
  ///    e chamar /api/equipment/<id>/.
  /// 2) Se não achar por ID, tenta /api/equipment/?search=<code>.
  /// 3) Se ainda não, tenta /api/equipment/?code=<code>.
  Future<Equipment?> getEquipmentByCode({
    required String code,
    required String token,
  }) async {
    // 1) tentar extrair ID do QR
    final id = _extractIdFromQr(code);
    if (id != null) {
      final byId = await getEquipmentById(id: id, token: token);
      if (byId != null) return byId;
      // se não achou por id, continua para tentativas por lista
    }

    // 2) tentar lista com ?search=
    var uri = Uri.parse('$_api/equipment/?search=$code');
    var res = await http.get(uri, headers: _headers(auth: true, token: token));
    if (res.statusCode == 200) {
      final list = jsonDecode(utf8.decode(res.bodyBytes));
      if (list is List && list.isNotEmpty) {
        return Equipment.fromJson(list.first);
      }
    }

    // 3) tentar lista com ?code=
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

  Future<void> createTask(
    Map<String, dynamic> taskData, {
    required String token,
  }) async {
    final uri = Uri.parse('$_api/task/');
    final res = await http.post(
      uri,
      headers: _headers(auth: true, token: token),
      body: jsonEncode(taskData),
    );

    if (res.statusCode != 201) {
      throw Exception('Erro ao criar tarefa (${res.statusCode}): ${res.body}');
    }
  }

  // ------------------- Helpers -------------------
  /// Tenta extrair um inteiro do conteúdo do QR:
  /// - "3"
  /// - "http://.../api/equipment/3/"  -> pega 3
  /// - '{"id":3,"name":"..."}'        -> pega 3
  int? _extractIdFromQr(String raw) {
    final s = raw.trim();

    // a) só dígitos
    final onlyDigits = RegExp(r'^\d+$');
    if (onlyDigits.hasMatch(s)) {
      return int.tryParse(s);
    }

    // b) URL com /equipment/<id>/
    final urlId = RegExp(r'/equipment/(\d+)/?$').firstMatch(s);
    if (urlId != null) {
      return int.tryParse(urlId.group(1)!);
    }

    // c) JSON com {"id": <num>}
    try {
      final dynamic parsed = jsonDecode(s);
      if (parsed is Map && parsed['id'] != null) {
        return int.tryParse(parsed['id'].toString());
      }
    } catch (_) {
      // não é JSON válido, segue o fluxo
    }

    return null;
  }

  Map<String, dynamic> _safeJson(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }
}
