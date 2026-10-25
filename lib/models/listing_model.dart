import 'package:flutter/foundation.dart';
import 'listing_draft.dart';

class ListingModel extends ChangeNotifier {
  final List<ListingDraft> _drafts = [];
  List<ListingDraft> get drafts => List.unmodifiable(_drafts);
  void add(ListingDraft draft) {
    _drafts.add(draft);
    notifyListeners();
  }
}
