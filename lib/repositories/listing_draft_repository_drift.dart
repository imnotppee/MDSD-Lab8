import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../models/listing_draft.dart';
import 'listing_draft_repository.dart';

class ListingDraftRepositoryDrift implements ListingDraftRepository {
  final AppDatabase _db;

  ListingDraftRepositoryDrift(this._db);

  @override
  Future<void> saveDraft(ListingDraft draft, String imagePath) async {
    await _db.into(_db.listingDrafts).insert(
      ListingDraftsCompanion.insert(
        title: draft.title,
        category: draft.category,
        description: draft.description,
        imagePath: imagePath,
      ),
    );
  }

  @override
  Future<List<ListingDraftRow>> getAllDrafts() async {
    return await (_db.select(_db.listingDrafts)
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)]))
        .get();
  }

  @override
  Future<void> deleteDraft(int id) async {
    await (_db.delete(_db.listingDrafts)
          ..where((tbl) => tbl.id.equals(id)))
        .go();
  }
}

