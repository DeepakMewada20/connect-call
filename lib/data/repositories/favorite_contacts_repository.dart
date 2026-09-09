import 'dart:async';
import '../../models/favorite_contact_model.dart';
import '../../services/auth_service.dart';
import '../datasources/favorite_contacts_local_data_source.dart';

abstract class FavoriteContactsRepository {
  Future<bool> addFavorite(FavoriteContactModel favorite, {String? userId});
  Future<bool> removeFavorite(String remoteUserId, {String? userId});
  Future<bool> isFavorite(String remoteUserId, {String? userId});
  Future<List<FavoriteContactModel>> getFavorites({String? userId});
  Stream<List<FavoriteContactModel>> getFavoritesStream({String? userId});
}

class FavoriteContactsRepositoryImpl implements FavoriteContactsRepository {
  final FavoriteContactsLocalDataSource _localDataSource;
  final AuthService _authService;
  final StreamController<List<FavoriteContactModel>> _favoritesStreamController =
      StreamController<List<FavoriteContactModel>>.broadcast();

  FavoriteContactsRepositoryImpl({
    FavoriteContactsLocalDataSource? localDataSource,
    AuthService? authService,
  })  : _localDataSource = localDataSource ?? FavoriteContactsLocalDataSource(),
        _authService = authService ?? AuthService();

  String _resolveUserId(String? userId) {
    final uid = userId ?? _authService.currentUserId;
    if (uid == null || uid.isEmpty) {
      throw StateError('Cannot access favorite contacts: user is not authenticated.');
    }
    return uid;
  }

  Future<void> _notifyFavoritesChanged(String firebaseUid) async {
    if (_favoritesStreamController.hasListener) {
      final updated = await _localDataSource.getFavorites(firebaseUid: firebaseUid);
      _favoritesStreamController.add(updated);
    }
  }

  @override
  Future<bool> addFavorite(FavoriteContactModel favorite, {String? userId}) async {
    try {
      final uid = _resolveUserId(userId);
      final model = favorite.copyWith(firebaseUid: uid);
      await _localDataSource.insertFavorite(model);
      await _notifyFavoritesChanged(uid);
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> removeFavorite(String remoteUserId, {String? userId}) async {
    try {
      final uid = _resolveUserId(userId);
      await _localDataSource.deleteFavorite(
        firebaseUid: uid,
        remoteUserId: remoteUserId,
      );
      await _notifyFavoritesChanged(uid);
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> isFavorite(String remoteUserId, {String? userId}) async {
    try {
      final uid = _resolveUserId(userId);
      return await _localDataSource.isFavorite(
        firebaseUid: uid,
        remoteUserId: remoteUserId,
      );
    } catch (e) {
      return false;
    }
  }

  @override
  Future<List<FavoriteContactModel>> getFavorites({String? userId}) async {
    try {
      final uid = _resolveUserId(userId);
      return await _localDataSource.getFavorites(firebaseUid: uid);
    } catch (e) {
      return [];
    }
  }

  @override
  Stream<List<FavoriteContactModel>> getFavoritesStream({String? userId}) {
    // Return broadcast stream and emit current favorites asynchronously
    Future.microtask(() async {
      try {
        final uid = _resolveUserId(userId);
        final current = await _localDataSource.getFavorites(firebaseUid: uid);
        _favoritesStreamController.add(current);
      } catch (_) {}
    });
    return _favoritesStreamController.stream;
  }
}
