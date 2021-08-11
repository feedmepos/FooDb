library foodb_repository;

import 'dart:async';
import 'dart:math';
import 'package:foodb/adapter/methods/all_docs.dart';
import 'package:foodb/adapter/methods/bulk_docs.dart';
import 'package:foodb/adapter/methods/delete.dart';
import 'package:foodb/adapter/methods/find.dart';
import 'package:foodb/adapter/methods/put.dart';
import 'package:foodb/common/doc.dart';
import 'package:foodb/foodb.dart';

abstract class FoodbRepository<T> {
  Foodb db;

  List<String> uniqueKey = [];
  List<String> indexKey = [];

  abstract T Function(Map<String, dynamic> json) fromJsonT;
  abstract Map<String, dynamic> Function(T instance) toJsonT;
  abstract String type;

  FoodbRepository({
    required this.db,
  });

  var _chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  Random _rnd = Random();

  String getRandomString(int length) => String.fromCharCodes(Iterable.generate(
      length, (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length))));

  String getIdPrefix() {
    return "${this.type}_";
  }

  String getIdSuffix() {
    return '';
  }

  String generateNewId({String? id}) {
    return "${this.getIdPrefix()}${id ?? new DateTime.now().toIso8601String()}${this.getIdSuffix()}";
  }

  String getTypeKey({String? type}) {
    return 'type_${type ?? this.type}';
  }

  Future<void> createIndex(field) async {
    List<String> fields = [this.getTypeKey()];
    if (field != this.getTypeKey()) {
      fields = [...fields, field];
    }
    var ddoc = fields.join("_");
    await db.adapter.createIndex(indexFields: fields, ddoc: ddoc);
  }

  Future<void> performIndex() async {
    for (String key in indexKey) {
      await createIndex(key);
    }
    for (String key in uniqueKey) {
      await createIndex(key);
    }
  }

  Future<void> verifyUnique(T model) async {
    for (String key in uniqueKey) {
      // TODO after find complete
      // throw error is already exist
    }
  }

  Map<String, dynamic> getDefaultAttributes() {
    return {this.getTypeKey(): true};
  }

  String getRepoEvent() {
    return "repo/${this.type}";
  }

  Future<List<Doc<T>>> all() async {
    GetAllDocs<T> getAllDocs = await db.adapter.allDocs<T>(
        GetAllDocsRequest(
            includeDocs: true,
            startKeyDocId: "${getIdPrefix()}",
            endKeyDocId: "${getIdPrefix()}\uffff"),
        (value) => fromJsonT(value));
    List<Row<T>?> rows = getAllDocs.rows;
    return rows.map<Doc<T>>((e) => e!.doc!).toList();
  }

  Future<List<Doc<T>>> readBetween(DateTime from, DateTime to) async {
    GetAllDocs<T> getAllDocs = await db.adapter.allDocs<T>(
        GetAllDocsRequest(
            includeDocs: true,
            startKeyDocId: "${getIdPrefix()}${from.toIso8601String()}",
            endKeyDocId: "${getIdPrefix}\uffff${to.toIso8601String()}"),
        (value) => fromJsonT(value as Map<String, dynamic>));
    List<Row<T>?> rows = getAllDocs.rows;
    return rows.map<Doc<T>>((e) => e!.doc!).toList();
  }

  Future<Doc<T>?> create(T model, {String? id}) async {
    await this.verifyUnique(model);
    String newId = generateNewId(id: id);
    // Doc<T> newDoc =
    //     new Doc(id: "$type-${jsonEncode(toJsonT(model))}", model: model);
    Doc<Map<String, dynamic>> newDoc =
        new Doc(id: newId, model: toJsonT(model));
    newDoc.model.addAll(getDefaultAttributes());
    PutResponse putResponse = await db.adapter.put(doc: newDoc);

    return putResponse.ok == true ? await read(newId) : null;
  }

  Future<Doc<T>?> update(Doc<T> doc) async {
    await this.verifyUnique(doc.model);
    Doc<Map<String, dynamic>> newDoc =
        Doc(model: toJsonT(doc.model), id: doc.id, rev: doc.rev);
    newDoc.model.addAll(getDefaultAttributes());
    PutResponse putResponse = await db.adapter.put(doc: newDoc);

    return putResponse.ok == true ? await read(newDoc.id) : null;
  }

  Future<DeleteResponse> delete(Doc<T> model) async {
    return await db.adapter.delete(id: model.id, rev: model.rev!);
  }

  Future<Doc<T>?> read(String id) async {
    return await db.adapter.get<T>(
      id: id,
      fromJsonT: (value) => fromJsonT(value),
    );
  }

  //TODO
  Future<List<Doc<T>>?> find() async {
    var resp =
        await db.adapter.find<T>(FindRequest(selector: {'no': 1}), fromJsonT);
    // return resp.docs;
  }

  Future<BulkDocResponse> bulkDocs(List<Doc<T>> docs) async {
    List<Doc<Map<String, dynamic>>> mappedDocs = [];
    for (Doc<T> doc in docs) {
      var json = toJsonT(doc.model);
      json.addAll(getDefaultAttributes());
      // TODO: test bulk doc has default attribute
      Doc<Map<String, dynamic>> newDoc = new Doc(
          id: doc.id,
          deleted: doc.deleted,
          rev: doc.rev,
          revisions: doc.revisions,
          model: json);
      mappedDocs.add(newDoc);
    }
    return await db.adapter.bulkDocs(body: mappedDocs);
  }
}
