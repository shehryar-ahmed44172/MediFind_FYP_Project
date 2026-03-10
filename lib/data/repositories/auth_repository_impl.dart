import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/local/local_data_source.dart';
import '../datasources/remote/medifind_api_client.dart';

class AuthRepositoryImpl implements AuthRepository {
  final MediFindApiClient apiClient;
  final LocalDataSource localDataSource;

  AuthRepositoryImpl({
    required this.apiClient,
    required this.localDataSource,
  });

  @override
  Future<AuthResponse> login(String email, String password) async {
    final response = await apiClient.login(email, password);
    await localDataSource.saveAuthToken(response.token);
    apiClient.setAuthToken(response.token);
    return response;
  }

  @override
  Future<AuthResponse> register(
    String fullName,
    String email,
    String phoneNumber,
    String password,
    String role,
  ) async {
    final response = await apiClient.register(
      fullName,
      email,
      phoneNumber,
      password,
      role,
    );
    await localDataSource.saveAuthToken(response.token);
    apiClient.setAuthToken(response.token);
    return response;
  }

  @override
  Future<AuthResponse> refreshToken(String token) async {
    final response = await apiClient.refreshToken(token);
    await localDataSource.saveAuthToken(response.token);
    apiClient.setAuthToken(response.token);
    return response;
  }

  @override
  Future<void> logout() async {
    await localDataSource.clearAuthToken();
    apiClient.clearAuthToken();
  }

  @override
  Future<bool> isUserLoggedIn() async {
    final token = await localDataSource.getAuthToken();
    return token != null && token.isNotEmpty;
  }

  @override
  Future<String?> getAuthToken() async {
    return await localDataSource.getAuthToken();
  }

  @override
  Future<void> saveAuthToken(String token) async {
    await localDataSource.saveAuthToken(token);
    apiClient.setAuthToken(token);
  }

  @override
  Future<void> clearAuthToken() async {
    await localDataSource.clearAuthToken();
    apiClient.clearAuthToken();
  }
}
