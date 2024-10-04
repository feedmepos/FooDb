library foodb_objectbox_adapter;

import 'dart:convert';
import 'dart:developer';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:foodb/key_value_adapter.dart';
import 'package:foodb_objectbox_adapter/object_box_entity.dart';
import 'package:foodb_objectbox_adapter/objectbox.g.dart';

const int int64MaxValue = 9223372036854775807;

class _IsolateData {
  final RootIsolateToken token;
  final SendPort sendPort;

  _IsolateData({
    required this.token,
    required this.sendPort,
  });
}

dynamic encodeKey(AbstractKey? key, {bool isEnd = false}) {
  dynamic result = key?.key;
  if (key is AbstractViewKey) {
    final viewName = key.viewName;
    var stringKey = key.key;
    if (key is ViewKeyMetaKey) {
      stringKey = key.key?.encode() ?? (isEnd ? '\uffff' : '');
    }
    result = '$viewName!$stringKey';
  }
  if (result is String) {
    result = stripReservedCharacter(result);
  }
  return result;
}

AbstractKey decodeKey(AbstractKey type, dynamic objectBoxKey) {
  if (objectBoxKey is String) {
    objectBoxKey = revertStripReservedCharacter(objectBoxKey);
  }

  if (type is AbstractViewKey) {
    objectBoxKey as String;
    int index = objectBoxKey.indexOf('!');
    objectBoxKey = objectBoxKey.substring(index + 1);
  }

  if (type is ViewKeyMetaKey) {
    return type.copyWithKey(newKey: ViewKeyMeta.decode(objectBoxKey));
  }
  return type.copyWithKey(newKey: objectBoxKey);
}


class ObjectBoxMessage {
  final String command;
  final dynamic data;
  final SendPort replyPort;

  ObjectBoxMessage(this.command, this.data, this.replyPort);
}

abstract class ObjectBoxKey<T1 extends ObjectBoxEntity, T2> {
  QueryProperty<T1, T2> get property;
  Condition<T1> equals(T2 key);
  Condition<T1> oneOf(List<dynamic> keys);
  Condition<T1> greaterOrEqual(T2 key);
  Condition<T1> lessOrEqual(T2 key);
  Condition<T1> greaterThan(T2 key);
  Condition<T1> lessThan(T2 key);
}

class ObjectBoxStringKey<T extends ObjectBoxEntity>
    implements ObjectBoxKey<T, String> {
  QueryStringProperty<T> queryKey;
  get property => queryKey;
  @override
  ObjectBoxStringKey({required this.queryKey});

  Condition<T> equals(String key) {
    return queryKey.equals(key);
  }

  Condition<T> oneOf(List<dynamic> keys) {
    return queryKey.oneOf(keys.cast<String>());
  }

  Condition<T> greaterThan(String key) {
    return queryKey.greaterThan(key);
  }

  Condition<T> lessThan(String key) {
    return queryKey.lessThan(key);
  }

  Condition<T> greaterOrEqual(String key) {
    return queryKey.greaterOrEqual(key);
  }

  Condition<T> lessOrEqual(String key) {
    return queryKey.lessOrEqual(key);
  }
}

class ObjectBoxIntKey<T extends ObjectBoxEntity>
    implements ObjectBoxKey<T, int> {
  QueryIntegerProperty<T> queryKey;
  get property => queryKey;
  @override
  ObjectBoxIntKey({required this.queryKey});

  Condition<T> equals(int key) {
    return queryKey.equals(key);
  }

  Condition<T> oneOf(List<dynamic> keys) {
    return queryKey.oneOf(keys.cast<int>());
  }

  Condition<T> greaterThan(int key) {
    return queryKey.greaterThan(key);
  }

  Condition<T> lessThan(int key) {
    return queryKey.lessThan(key);
  }

  Condition<T> greaterOrEqual(int key) {
    return queryKey.greaterOrEqual(key);
  }

  Condition<T> lessOrEqual(int key) {
    return queryKey.lessOrEqual(key);
  }
}

class ObjectBoxType<T1 extends ObjectBoxEntity, T2> {
  ObjectBoxKey<T1, T2> keyQuery;
  T1 Function() factory;
  Future<bool> Function(Box<T1>, T2)? _removeAll;
  ObjectBoxType({
    required this.keyQuery,
    required this.factory,
    Future<bool> Function(Box<T1>, T2)? removeAll,
  }) : _removeAll = removeAll;

  Box<T1> box(Store store) {
    return store.box<T1>();
  }

  int count(store) {
    return box(store).count();
  }

  init(store) async {}

  removeAll(Store store, T2 key) {
    return _removeAll?.call(box(store), key) ?? box(store).removeAll();
  }

  put(Store store, T2 key, String val) {
    final exist = get(store, key);
    var obj = factory();
    if (exist != null) obj = exist;
    obj.key = key;
    obj.value = val;
    return box(store).put(obj);
  }

  putMany(Store store, Map<dynamic, String> entries) {
    final toPut = getMany(store, entries.keys.toList()).entries.map((e) {
      final key = e.key;
      final value = e.value;
      var obj = value ?? factory();
      obj.key = key;
      obj.value = entries[key]!;
      return obj;
    }).toList();
    return box(store).putMany(toPut);
  }

  remove(Store store, key) {
    return box(store).query(keyQuery.equals(key)).build().remove();
  }

  T1? get(Store store, key) {
    var list = box(store).query(keyQuery.equals(key)).build().find();
    if (list.length > 0) return list[0];
    return null;
  }

  Map<dynamic, T1?> getMany(Store store, List<dynamic> keys) {
    var map = Map<dynamic, T1>.fromIterable(
        box(store).query(keyQuery.oneOf(keys)).build().find(),
        key: (v) => v.key,
        value: (v) => v);
    var result = keys.asMap().map((k, e) {
      return MapEntry(e, map[e]);
    });
    return result;
  }

  List<T1> readBetween(Store store,
      {T2? startkey,
        T2? endkey,
        required bool descending,
        required bool inclusiveStart,
        required bool inclusiveEnd,
        int? offset,
        int? limit}) {
    List<Condition<T1>> conditions = [];
    if (startkey != null) {
      if (inclusiveStart) {
        conditions.add(descending
            ? keyQuery.lessOrEqual(startkey)
            : keyQuery.greaterOrEqual(startkey));
      } else {
        conditions.add(descending
            ? keyQuery.lessThan(startkey)
            : keyQuery.greaterThan(startkey));
      }
    }
    if (endkey != null) {
      if (inclusiveEnd) {
        conditions.add(descending
            ? keyQuery.greaterOrEqual(endkey)
            : keyQuery.lessThan(endkey));
      } else {
        conditions.add(descending
            ? keyQuery.greaterThan(endkey)
            : keyQuery.lessThan(endkey));
      }
    }

    Condition<T1>? finalContidion;
    if (conditions.isNotEmpty) {
      finalContidion =
          conditions.reduce((value, element) => value.and(element));
    }

    final query = (box(store).query(finalContidion)
      ..order(keyQuery.property, flags: descending ? Order.descending : 0))
        .build();

    if (offset != null) query.offset = offset;
    if (limit != null) query.limit = limit;
    return query.find();
  }

  ObjectBoxEntity? last(Store store, key) {
    Query query = (box(store).query()
      ..order(keyQuery.property, flags: Order.descending))
        .build();
    query.limit = 1;
    var docs = query.find();
    if (docs.length > 0) {
      return docs[0];
    }
    return null;
  }
}

final utilsBox = ObjectBoxType<UtilsEntity, String>(
    keyQuery: ObjectBoxStringKey(queryKey: UtilsEntity_.key),
    factory: () => UtilsEntity());
final sequenceBox = ObjectBoxType<SequenceEntity, int>(
    keyQuery: ObjectBoxIntKey(queryKey: SequenceEntity_.key),
    factory: () => SequenceEntity());
final docBox = ObjectBoxType<DocEntity, String>(
    keyQuery: ObjectBoxStringKey(queryKey: DocEntity_.key),
    factory: () => DocEntity());
final localDocBox = ObjectBoxType<LocalDocEntity, String>(
    keyQuery: ObjectBoxStringKey(queryKey: LocalDocEntity_.key),
    factory: () => LocalDocEntity());
final viewMetaBox = ObjectBoxType<ViewMetaEntity, String>(
    keyQuery: ObjectBoxStringKey(queryKey: ViewMetaEntity_.key),
    factory: () => ViewMetaEntity());
final viewDocMetaBox = ObjectBoxType<ViewDocMetaEntity, String>(
    keyQuery: ObjectBoxStringKey(queryKey: ViewDocMetaEntity_.key),
    factory: () => ViewDocMetaEntity(),
    removeAll: (box, key) async {
      box.query(ViewDocMetaEntity_.key.startsWith(key)).build().remove();
      return true;
    });
final viewKeyMetaBox = ObjectBoxType<ViewKeyMetaEntity, String>(
    keyQuery: ObjectBoxStringKey(queryKey: ViewKeyMetaEntity_.key),
    factory: () => ViewKeyMetaEntity(),
    removeAll: (box, key) async {
      box.query(ViewKeyMetaEntity_.key.startsWith(key)).build().remove();
      return true;
    });
final allDocViewDocMetaBox = ObjectBoxType<AllDocViewDocMetaEntity, String>(
    keyQuery: ObjectBoxStringKey(queryKey: AllDocViewDocMetaEntity_.key),
    factory: () => AllDocViewDocMetaEntity(),
    removeAll: (box, key) async {
      box.query(AllDocViewDocMetaEntity_.key.startsWith(key)).build().remove();
      return true;
    });
final allDocViewKeyMetaBox = ObjectBoxType<AllDocViewKeyMetaEntity, String>(
    keyQuery: ObjectBoxStringKey(queryKey: AllDocViewKeyMetaEntity_.key),
    factory: () => AllDocViewKeyMetaEntity(),
    removeAll: (box, key) async {
      box.query(AllDocViewKeyMetaEntity_.key.startsWith(key)).build().remove();
      return true;
    });

List<ObjectBoxType> allBoxes() => [
  utilsBox,
  sequenceBox,
  docBox,
  localDocBox,
  viewMetaBox,
  viewDocMetaBox,
  viewKeyMetaBox,
  allDocViewDocMetaBox,
  allDocViewKeyMetaBox
];

class ObjectBoxAdapter implements KeyValueAdapter {
  static Store? store;
  late SendPort _sendPort;
  late ReceivePort _receivePort;
  late final Isolate _isolate;
  String type = 'object-box';

  String Function({required String designDocId, required String viewId})
  getViewTableName = KeyValueAdapter.defaultGetViewTableName;
  String get allDocViewName =>
      KeyValueAdapter.getAllDocViewTableName(getViewTableName);

  ObjectBoxAdapter(Store _store) {
    _store.close();
    _init();
  }

  void _init() async {
    _receivePort = ReceivePort();
    _isolate = await Isolate.spawn(_isolateEntry, _IsolateData(token: RootIsolateToken.instance!, sendPort: _receivePort.sendPort));
    _sendPort = await _receivePort.first as SendPort;
  }

  static void _isolateEntry(_IsolateData idata) async {
    BackgroundIsolateBinaryMessenger.ensureInitialized(idata.token);
    var isolate = Service.getIsolateID(Isolate.current);
    print("ISOLATE Running in isolate " + isolate.toString());
    final port = ReceivePort();
    idata.sendPort.send(port.sendPort);

    store?.close();
    store = await openStore();

    port.listen((message) async {
      final msg = message as ObjectBoxMessage;
      dynamic result;
      switch (msg.command) {
        case 'put':
          result = await _put(store!, msg.data);
          break;
        case 'putMany':
          result = await _putMany(store!, msg.data);
          break;
        case 'get':
          result = await _get(store!, msg.data);
          break;
        case 'getMany':
          result = await _getMany(store!, msg.data);
          break;
        case 'read':
          result = await _read(store!, msg.data);
          break;
        case 'last':
          result = await _last(store!, msg.data);
          break;
        case 'delete':
          result = await _delete(store!, msg.data);
          break;
        case 'clearTable':
          result = await _clearTable(store!, msg.data);
          break;
        case 'tableSize':
          result = await _tableSize(store!, msg.data);
          break;
        case 'init':
          result = await _initDb(store!);
          break;
        case 'destroy':
          result = await _destroy(store!);
          break;
      // Add other cases for different commands as needed...
      }
      msg.replyPort.send(result);
    });
  }


  static ObjectBoxType _getBoxFromKey(AbstractKey key) {
    if (key is SequenceKey) {
      return sequenceBox;
    } else if (key is DocKey) {
      return docBox;
    } else if (key is LocalDocKey) {
      return localDocBox;
    } else if (key is ViewMetaKey) {
      return viewMetaBox;
    } else if (key is ViewDocMetaKey) {
      if (key.viewName == KeyValueAdapter.getAllDocViewTableName(KeyValueAdapter.defaultGetViewTableName))
        return allDocViewDocMetaBox;
      else
        return viewDocMetaBox;
    } else if (key is ViewKeyMetaKey) {
      if (key.viewName == KeyValueAdapter.getAllDocViewTableName(KeyValueAdapter.defaultGetViewTableName))
        return allDocViewKeyMetaBox;
      else
        return viewKeyMetaBox;
    } else if (key is UtilsKey) {
      return utilsBox;
    } else {
      throw Exception('invalid key');
    }
  }


  static Future<bool> _putMany(Store store, Map<String, dynamic> data) async {
    final box = data['box'];
    final Map<dynamic, String> entries = data['entries'];
    box.putMany(store, entries);
    return true;
  }

  static Future<dynamic> _get(Store store, Map<String, dynamic> data) async {
    final key = data['key'];
    final box = data['box'];
    final val = box.get(store, encodeKey(key));
    if (val == null) return null;
    return MapEntry(key, val.doc);
  }


  static Future<Map<dynamic, dynamic>> _getMany(Store store, Map<String, dynamic> data) async {
    final List<dynamic> keys = data['keys'];
    final box = data['box'];
    final val = box.getMany(store, keys);
    return val;
  }


  static Future<dynamic> _put(Store store, Map<String, dynamic> data) async {
    final key = data['key'];
    final box = data['box'];
    final value = data['value'];
    return box.put(store, encodeKey(key), jsonEncode(value));
  }


  static Future<dynamic> _read(Store store, Map<String, dynamic> data) async {
    final AbstractKey keyType = data['keyType'];
    final int? limit = data['limit'];
    final int? skip = data['skip'];
    final AbstractKey? startkey = data['startkey'];
    final AbstractKey? endkey = data['endkey'];
    final bool desc = data['desc'];
    final bool inclusiveEnd = data['inclusiveEnd'];
    final bool inclusiveStart = data['inclusiveStart'];

    final ObjectBoxType<ObjectBoxEntity<dynamic>, dynamic> box = data['box'];

    final totalRows = box.count(store);
    final offset = 0;
    final record = box.readBetween(store,
        startkey: encodeKey(startkey),
        endkey: encodeKey(endkey, isEnd: true),
        descending: desc,
        inclusiveEnd: inclusiveEnd,
        inclusiveStart: inclusiveStart,
        offset: skip,
        limit: limit);

    return ReadResult(
        totalRows: totalRows,
        offset: offset,
        records: record.asMap().map((key, value) => MapEntry(decodeKey(keyType, value.key), value.doc))
    );
  }


  static Future<dynamic> _last(Store store, Map<String, dynamic> data) async {
    final key = data['key'];
    final box = data['box'];
    final val = box.last(store, encodeKey(key));
    if (val == null) return null;
    return MapEntry(key, val.doc);
  }

  static Future<bool> _delete(Store store, Map<String, dynamic> data) async {
    final key = data['key'];
    final box = data['box'];
    final deleteResult = await box.remove(store, encodeKey(key));
    return deleteResult == 1 ? true : false;
  }

  static Future<bool> _clearTable(Store store, Map<String, dynamic> data) async {
    final key = data['key'];
    final boxType = _getBoxFromKey(key);
    var encodedKey = encodeKey(key);
    if (key is ViewKeyMetaKey) {
      encodedKey = '${key.viewName}!';
    }
    await boxType.removeAll(store, encodedKey);
    return true;
  }

  static Future<bool> _destroy(Store store) async {
    await Future.wait(allBoxes().map((box) async {
      return box.box(store).removeAll();
    }));
    return true;
  }


  static Future<bool> _initDb(Store store) async {
    await Future.wait(allBoxes().map((box) async {
      return box.init(store);
    }));
    return true;
  }


  static Future<int> _tableSize(Store store, Map<String, dynamic> data) async {
    final key = data['key'];
    final boxType = _getBoxFromKey(key);
    return boxType.count(store);
  }


  @override
  Future<bool> delete(AbstractKey<Comparable> key,
      {KeyValueAdapterSession? session}) async {
    final replyPort = ReceivePort();
    final box = _getBoxFromKey(key);
    _sendToIsolate('delete', {'key': key, 'box': box}, replyPort.sendPort);
    return Future<bool>.value(await replyPort.first);
  }

  @override
  Future<bool> put(AbstractKey<Comparable> key, Map<String, dynamic> value,
      {KeyValueAdapterSession? session}) async {
    final replyPort = ReceivePort();
    final box = _getBoxFromKey(key);
    _sendToIsolate('put', {'key': key, 'box': box, 'value': value}, replyPort.sendPort);
    return Future<bool>.value(await replyPort.first == 1);
  }

  @override
  Future<bool> destroy({KeyValueAdapterSession? session}) async {
    final replyPort = ReceivePort();
    _sendToIsolate('destroy', {}, replyPort.sendPort);
    return Future<bool>.value(await replyPort.first);
  }

  @override
  Future<bool> clearTable(AbstractKey<Comparable> key,
      {KeyValueAdapterSession? session}) async {
    final replyPort = ReceivePort();
    _sendToIsolate('clearTable', {'key': key}, replyPort.sendPort);
    return Future<bool>.value(await replyPort.first);
  }
  @override
  Future<bool> deleteMany(List<AbstractKey<Comparable>> keys, {KeyValueAdapterSession? session}) async {
    for (final key in keys) {
      await delete(key);
    }
    return true;
  }

  @override
  Future<MapEntry<T2, Map<String, dynamic>>?> get<T2 extends AbstractKey<Comparable>>(T2 key, {KeyValueAdapterSession? session}) async {
    final replyPort = ReceivePort();
    final box = _getBoxFromKey(key);
    _sendToIsolate('get', {'key': key, 'box': box}, replyPort.sendPort);
    var ret = await replyPort.first;
    if (ret is MapEntry<dynamic, dynamic>) {
      ret = MapEntry<T2, Map<String, dynamic>>(ret.key as T2, ret.value);
    }
    return Future.value(ret);
  }

  @override
  Future<Map<T2, Map<String, dynamic>?>> getMany<T2 extends AbstractKey<Comparable>>(List<T2> keys, {KeyValueAdapterSession? session}) async {
    if (keys.isEmpty) {
      return Map<T2, Map<String, dynamic>?>();
    }
    final replyPort = ReceivePort();
    final box = _getBoxFromKey(keys[0]);
    final s_keys = keys.map((k) => encodeKey(k)).toList();

    _sendToIsolate('getMany', {'keys': s_keys, 'box': box}, replyPort.sendPort);
    Map<dynamic, dynamic> ret = await replyPort.first;
    Map<T2, Map<String, dynamic>> result = await ret.map((key, value) {
      if (key is String) {
        var decoded = decodeKey(keys[0], key);
        return MapEntry(decoded as T2, value.doc);
      } else {
        throw Exception('Non-string key found: $key');
      }
    });
    return Future.value(result);
  }

  @override
  Future<bool> initDb() async {
    final replyPort = ReceivePort();
    _sendToIsolate('init', {}, replyPort.sendPort);
    return Future<bool>.value(await replyPort.first);
  }

  @override
  Future<MapEntry<T2, Map<String, dynamic>>?> last<T2 extends AbstractKey<Comparable>>(T2 key, {KeyValueAdapterSession? session}) async {
    final replyPort = ReceivePort();
    final box = _getBoxFromKey(key);
    _sendToIsolate('last', {'key': key, 'box': box}, replyPort.sendPort);
    var ret = await replyPort.first;
    if (ret is MapEntry<dynamic, dynamic>) {
      ret = MapEntry<T2, Map<String, dynamic>>(ret.key as T2, ret.value);
    }
    return Future.value(ret);
  }

  @override
  Future<bool> putMany(Map<AbstractKey<Comparable>, Map<String, dynamic>> entries, {KeyValueAdapterSession? session}) async {
    final replyPort = ReceivePort();
    _sendToIsolate('putMany', {
      'entries': entries.map((key, value) => MapEntry(encodeKey(key), jsonEncode(value))),
      'box': _getBoxFromKey(entries.keys.first),
    }, replyPort.sendPort);
    var ret = await replyPort.first;
    return Future.value(ret);
  }

  @override
  Future<ReadResult<T2>> read<T2 extends AbstractKey<Comparable>>(T2 keyType, {T2? startkey, T2? endkey, KeyValueAdapterSession? session,
    required bool desc, required bool inclusiveStart, required bool inclusiveEnd, int? skip, int? limit}) async {
    final boxType = _getBoxFromKey(keyType);
    final replyPort = ReceivePort();
    _sendToIsolate('read', {
      'keyType': keyType,
      'box': boxType,
      'startkey': startkey,
      'endkey': endkey,
      'session': session,
      'desc': desc,
      'inclusiveStart': inclusiveStart,
      'inclusiveEnd': inclusiveEnd,
      'skip': skip,
      'limit': limit,
    }, replyPort.sendPort);
    return Future.value(await replyPort.first);
  }

  @override
  Future<void> runInSession(Future<void> Function(KeyValueAdapterSession p1) function) async {
    // TODO: implement runInSession
    throw UnimplementedError("runInSession");
  }

  @override
  Future<int> tableSize(AbstractKey<Comparable> key, {KeyValueAdapterSession? session}) async {
    final replyPort = ReceivePort();
    _sendToIsolate('tableSize', {'key': key}, replyPort.sendPort);
    return Future.value(await replyPort.first);
  }

  // Implement other methods like get, clearTable, destroy, etc.

  void _sendToIsolate(String command, dynamic data, SendPort replyPort) {
    final message = ObjectBoxMessage(command, data, replyPort);
    _sendPort.send(message);
  }

// Other methods as defined in your existing ObjectBoxAdapter...
}