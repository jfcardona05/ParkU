import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../models/vehicle_model.dart';
import '../models/transaction_model.dart';

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
  @override
  String toString() => message;
}

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );
  final http.Client _client;
  final String _baseUrl;
  String? _token;
  UserModel? _currentUser;
  ApiService({http.Client? client, String? apiBaseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = apiBaseUrl ?? baseUrl;
  String? get token => _token;
  UserModel? get currentUser => _currentUser;
  void setToken(String? token) => _token = token;
  void setCurrentUser(UserModel? user) => _currentUser = user;

  Future<Map<String, dynamic>> _request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final request = http.Request(method, Uri.parse('$_baseUrl$path'));
    request.headers['Content-Type'] = 'application/json';
    if (_token != null) request.headers['Authorization'] = 'Bearer $_token';
    if (body != null) request.body = jsonEncode(body);
    try {
      final response = await http.Response.fromStream(
        await _client.send(request).timeout(const Duration(seconds: 15)),
      ).timeout(const Duration(seconds: 15));
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (response.statusCode >= 400) {
        if (response.statusCode == 401) {
          _token = null;
          _currentUser = null;
        }
        throw ApiException(data['message'] as String? ?? 'Solicitud rechazada');
      }
      return data;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        'No se pudo conectar con ParkU. Revisa la conexión e intenta nuevamente.',
      );
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    _token = null;
    _currentUser = null;
    try {
      final data = await _request('POST', '/api/auth/login', {
        'email': email,
        'password': password,
      });
      _token = data['token'] as String;
      _currentUser = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      return {'success': true, 'user': _currentUser};
    } on ApiException catch (e) {
      return {'success': false, 'message': e.message};
    }
  }

  Future<void> logout() async {
    try {
      if (_token != null) await _request('POST', '/api/auth/logout');
    } on ApiException {
      /* A local logout is possible even if the server is offline. */
    } finally {
      _token = null;
      _currentUser = null;
    }
  }

  Future<List<VehicleModel>> getVehicles() async {
    final data = await _request('GET', '/api/vehicles');
    return (data['vehicles'] as List)
        .map((e) => VehicleModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> addVehicle({
    required String plate,
    required String type,
    String? brandModel,
  }) async {
    if (plate.trim().isEmpty || type.trim().isEmpty) {
      return {
        'success': false,
        'message': 'La placa y el tipo son obligatorios.',
      };
    }
    try {
      final data = await _request('POST', '/api/vehicles', {
        'plate': plate.trim().toUpperCase(),
        'type': type,
        'brand_model': brandModel?.trim() ?? '',
      });
      return {
        'success': true,
        'vehicle': VehicleModel.fromJson(
          data['vehicle'] as Map<String, dynamic>,
        ),
        'message': data['message'],
      };
    } on ApiException catch (e) {
      return {'success': false, 'message': e.message};
    }
  }

  Future<bool> deleteVehicle(int id) async {
    await _request('DELETE', '/api/vehicles/$id');
    return true;
  }

  Future<int> getBalance() async {
    final data = await _request('GET', '/api/wallet/balance');
    final balance = data['balance'] as int;
    _currentUser = _currentUser?.copyWith(balance: balance);
    return balance;
  }

  Future<List<TransactionModel>> getHistory() async {
    final data = await _request('GET', '/api/wallet/history');
    return (data['transactions'] as List)
        .map((e) => TransactionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<UserModel>> getUsers() async {
    final data = await _request('GET', '/api/admin/users');
    return (data['users'] as List)
        .map((e) => UserModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> recharge({
    required int amount,
    required String pointName,
    int? userId,
  }) async {
    if (amount <= 0) {
      return {'success': false, 'message': 'El importe debe ser mayor a cero.'};
    }
    if (userId == null) {
      return {
        'success': false,
        'message': 'Selecciona un usuario destinatario.',
      };
    }
    try {
      return await _request('POST', '/api/wallet/recharge', {
        'amount': amount,
        'point_name': pointName,
        'user_id': userId,
      });
    } on ApiException catch (e) {
      return {'success': false, 'message': e.message};
    }
  }
}
