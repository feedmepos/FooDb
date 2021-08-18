import 'dart:async';
import 'dart:collection';

import 'package:foodb/adapter/key_value_adapter.dart';

typedef StoreObject = SplayTreeMap<String, dynamic>;
typedef Stores = Map<String, StoreObject?>;

class InMemoryDatabase implements KeyValueDatabase {
  final Stores _stores = Stores();

  @override
  Future<bool> put(String tableName,
      {required String id, required Map<String, dynamic> object}) async {
    if (_stores[tableName] == null) {
      _stores[tableName] = SplayTreeMap();
    }
    _stores[tableName]!.update(id, (value) => object, ifAbsent: () => object);
    return true;
  }

  @override
  Future<bool> delete(String tableName, {required String id}) async {
    return _stores[tableName]?.remove(id) ?? false;
  }

  @override
  Future<Map<String, dynamic>?> get(String tableName,
          {required String id}) async =>
      _stores[tableName]?[id];

  @override
  Future<Map<String, Map<String, dynamic>>> read(String tableName,
      {String? startKey, String? endKey, bool? desc}) async {
    var table = _stores[tableName];
    Map<String, Map<String, dynamic>> result = {};
    if (table != null) {
      // TODO implement desc
      // TODO read between
      table.entries.forEach((element) {
        if ((startKey == null || element.key.compareTo(startKey) > 0) &&
            (endKey == null || element.key.compareTo(endKey) < 0)) {
          result.putIfAbsent(element.key, () => element.value);
        }
      });
    }
    return result;
  }

  @override
  Future<int> tableSize(String tableName) async {
    return _stores[tableName]?.length ?? 0;
  }
}