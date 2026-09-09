import 'dart:async';
import 'package:get/get.dart';
import '../data/repositories/favorite_contacts_repository.dart';
import '../models/favorite_contact_model.dart';
import '../models/user_model.dart';
import 'auth_service.dart';

/// Service managing local favorite contacts in SQLite.
class FavoriteService {
  final FavoriteContactsRepository _repository;
  final AuthService _authService;
  static FavoriteService? _instance;

  // Reactive set of favorited remote user IDs for zero-latency UI checks
  final RxSet<String> favoriteUserIds = <String>{}.obs;
  final RxList<FavoriteContactModel> favorites = <FavoriteContactModel>[].obs;
  Stream<List<FavoriteContactModel>> get favoritesStream => favorites.stream;
  StreamSubscription<List<FavoriteContactModel>>? _subscription;

  FavoriteService({
    FavoriteContactsRepository? repository,
    AuthService? authService,
  })  : _repository = repository ?? FavoriteContactsRepositoryImpl(),
        _authService = authService ?? AuthService();

  static FavoriteService get instance => _instance ??= FavoriteService();

  static void setInstance(FavoriteService? service) {
    _instance = service;
  }

  String? get _currentUid => _authService.currentUserId;

  /// Initializes live synchronization of favorites for the active user
  void initFavoritesListener({String? userId}) {
    final uid = userId ?? _currentUid;
    if (uid == null || uid.isEmpty) {
      favoriteUserIds.clear();
      favorites.clear();
      return;
    }

    _subscription?.cancel();
    _subscription = _repository.getFavoritesStream(userId: uid).listen((list) {
      favorites.assignAll(list);
      favoriteUserIds.assignAll(list.map((f) => f.remoteUserId).toSet());
    });
  }

  /// Adds a contact to favorites.
  Future<bool> addFavorite(FavoriteContactModel favorite, {String? userId}) async {
    final success = await _repository.addFavorite(favorite, userId: userId ?? _currentUid);
    if (success) {
      favoriteUserIds.add(favorite.remoteUserId);
      if (!favorites.any((f) => f.remoteUserId == favorite.remoteUserId)) {
        favorites.insert(0, favorite);
      }
    }
    return success;
  }

  /// Removes a contact from favorites.
  Future<bool> removeFavorite(String remoteUserId, {String? userId}) async {
    final success = await _repository.removeFavorite(remoteUserId, userId: userId ?? _currentUid);
    if (success) {
      favoriteUserIds.remove(remoteUserId);
      favorites.removeWhere((f) => f.remoteUserId == remoteUserId);
    }
    return success;
  }

  /// Toggles favorite status for a contact.
  Future<bool> toggleFavorite({
    required String remoteUserId,
    required String contactName,
    required String phoneNumber,
    String? userId,
  }) async {
    final uid = userId ?? _currentUid;
    final currentlyFav = isFavoriteSync(remoteUserId);
    if (currentlyFav) {
      return await removeFavorite(remoteUserId, userId: uid);
    } else {
      final model = FavoriteContactModel(
        firebaseUid: uid ?? '',
        remoteUserId: remoteUserId,
        contactName: contactName,
        phoneNumber: phoneNumber,
        createdAt: DateTime.now(),
      );
      return await addFavorite(model, userId: uid);
    }
  }

  /// Toggles favorite status for a [UserModel].
  Future<bool> toggleFavoriteUser(UserModel user, {String? userId}) {
    return toggleFavorite(
      remoteUserId: user.uid,
      contactName: user.name,
      phoneNumber: user.phoneNumber,
      userId: userId,
    );
  }

  /// Asynchronously checks whether a remote user is favorited.
  Future<bool> isFavorite(String remoteUserId, {String? userId}) async {
    if (favoriteUserIds.contains(remoteUserId)) return true;
    final result = await _repository.isFavorite(remoteUserId, userId: userId ?? _currentUid);
    if (result) favoriteUserIds.add(remoteUserId);
    return result;
  }

  /// Synchronous fast check against cached favorite set.
  bool isFavoriteSync(String remoteUserId) {
    return favoriteUserIds.contains(remoteUserId);
  }

  /// Fetches all favorites for the active user.
  Future<List<FavoriteContactModel>> getFavorites({String? userId}) async {
    final list = await _repository.getFavorites(userId: userId ?? _currentUid);
    favorites.assignAll(list);
    favoriteUserIds.assignAll(list.map((f) => f.remoteUserId).toSet());
    return list;
  }

  /// Returns a stream of favorite contacts.
  Stream<List<FavoriteContactModel>> getFavoritesStream({String? userId}) {
    return _repository.getFavoritesStream(userId: userId ?? _currentUid);
  }

  void dispose() {
    _subscription?.cancel();
  }
}
