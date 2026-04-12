import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../../features/auth/data/datasources/auth_local_data_source.dart';
import '../error/exceptions.dart';
import 'api_constants.dart';

class BaseApiService {
  BaseApiService({Dio? dio, AuthLocalDataSource? authLocalDataSource})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: ApiConstants.baseUrl,
                connectTimeout: ApiConstants.connectTimeout,
                receiveTimeout: ApiConstants.receiveTimeout,
                headers: const {'Content-Type': 'application/json'},
              ),
            ),
        _authLocalDataSource = authLocalDataSource {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _authLocalDataSource?.getAccessToken();
          final isNoAuthRoute = options.path.contains('/login') || 
                                options.path.contains('/register') || 
                                options.path.contains('/refresh');
          if (token != null && token.isNotEmpty && !isNoAuthRoute) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
    _dio.interceptors.add(
      PrettyDioLogger(
        requestHeader: true,
        requestBody: true,
        responseBody: true,
        responseHeader: false,
        error: true,
        compact: true,
        maxWidth: 90,
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) {
          if (error.type == DioExceptionType.connectionError ||
              error.type == DioExceptionType.connectionTimeout) {
            handler.reject(
              DioException(
                requestOptions: error.requestOptions,
                error: const NetworkException('Unable to connect to server'),
              ),
            );
            return;
          }
          handler.next(error);
        },
      ),
    );
  }

  final Dio _dio;
  final AuthLocalDataSource? _authLocalDataSource;

  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.get(path, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw _mapException(e);
    }
  }

  Future<Response<dynamic>> post(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.post(path, data: data, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw _mapException(e);
    }
  }

  Future<Response<dynamic>> patch(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.patch(path, data: data, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw _mapException(e);
    }
  }

  Future<Response<dynamic>> put(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.put(path, data: data, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw _mapException(e);
    }
  }

  Future<Response<dynamic>> delete(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.delete(path, data: data, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw _mapException(e);
    }
  }

  Exception _mapException(DioException exception) {
    if (exception.error is NetworkException) {
      return exception.error! as Exception;
    }
    final statusCode = exception.response?.statusCode ?? 500;
    final responseData = exception.response?.data;
    String message;
    if (responseData is Map) {
      message = (responseData['message'] ?? responseData['title'] ?? responseData.toString()).toString();
    } else if (responseData is String && responseData.isNotEmpty) {
      message = responseData;
    } else {
      message = exception.message ?? 'Request failed';
    }
    return ServerException('[$statusCode] $message');
  }
}
