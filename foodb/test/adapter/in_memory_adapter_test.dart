import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/adapter/in_memory_adapter.dart';
import 'package:foodb/common/doc.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  getMemoryAdapter() {
    return new MemoryAdapter(dbName: 'test');
  }

  test('put', () async {
    final MemoryAdapter memoryDb = getMemoryAdapter();
    await memoryDb.put(doc: Doc(id: 'foo', model: {'bar': 'foo'}));
    await memoryDb.put(doc: Doc(id: 'foo', model: {'a': 'b'}));
    await memoryDb.put(doc: Doc(id: 'foo1', model: {'a': 'b'}));
    await memoryDb.put(
        doc: new Doc(id: 'foo2', model: {'bar': 'foo'}),
        newEdits: false,
        newRev: '2-dadadada');
    var doc = await memoryDb.get<Map<String, dynamic>>(
        id: 'foo', fromJsonT: (v) => v);
    expect(doc?.model['a'] != null && memoryDb.docCount == 3, true);
  });

  test('delete', () async {
    final MemoryAdapter memoryDb = getMemoryAdapter();
    await memoryDb.put(doc: new Doc(id: 'foo', model: {'bar': 'foo'}));
    await memoryDb.put(
        doc: new Doc(id: 'foo', model: {'a': 'b'}),
        newEdits: false,
        newRev: '3-abc');
    await memoryDb.delete(id: 'foo', rev: '3-abc');
    var result = await memoryDb.get<Map<String, dynamic>>(
        id: 'foo', fromJsonT: (v) => v);
    expect(result?.rev != '3-abc' && memoryDb.docCount == 1, true);
  });

  test('bulk docs()', () async {
    final MemoryAdapter memoryDb = getMemoryAdapter();
    await memoryDb.bulkDocs(body: [
      Doc(
          id: 'test2',
          rev: '1-zu21xehvdaine5smjxy9htiegd4rptkm5',
          model: {
            'name': 'test test',
            'no': 1111,
          },
          revisions: Revisions(start: 1, ids: [
            'zu21xehvdaine5smjxy9htiegd4rptkm5',
            'zu21xehvdaine5smjxy9htiegd4rptkm5'
          ])),
      Doc(
          id: 'test7',
          rev: '0-sasddsdsdfdfdsfdffdd',
          model: {
            'name': 'test test asdfgh',
            'no': 2212,
          },
          revisions: Revisions(start: 0, ids: ['sasddsdsdfdfdsfdffdd'])),
      Doc(
          id: 'test5',
          rev: '0-sasddsdsdfdfdsfdffdd',
          model: {
            'name': 'test test 5',
            'no': 222,
          },
          revisions: Revisions(start: 0, ids: ['sasddsdsdfdfdsfdffdd']))
    ]);

    expect(memoryDb.docCount, 3);
  });

  // test('all docs', () async {
  //   final MemoryAdapter memoryDb = getMemoryAdapter();
  //   await memoryDb.put(doc: new Doc(id: 'foo', model: {'bar': 'foo'}));
  //   await memoryDb.put(doc: new Doc(id: 'foo1', model: {'a': 'b'}));
  //   await memoryDb.put(doc: new Doc(id: 'foo2', model: {'c': 'd'}));
  //   await memoryDb.allDocs(GetAllDocsRequest(), (json) => json);
  //   expect(memoryDb.docCount, 3);
  // });
}