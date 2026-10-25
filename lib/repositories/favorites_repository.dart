import '../database/app_database.dart';

abstract class FavoritesRepository {
  Future<void> addFavorite(
    int itemId,
    String title,
    double price,
    String imageUrl,
  );
  Future<List<FavoriteItem>> getAllFavorites();
  Future<void> removeFavorite(int itemId);
}

