// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'changes.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChangeResultRev _$ChangeResultRevFromJson(Map<String, dynamic> json) {
  return ChangeResultRev(
    rev: json['rev'] as String,
  );
}

Map<String, dynamic> _$ChangeResultRevToJson(ChangeResultRev instance) =>
    <String, dynamic>{
      'rev': instance.rev,
    };

ChangeResponse _$ChangeResponseFromJson(Map<String, dynamic> json) {
  return ChangeResponse(
    lastSeq: json['last_seq'] as String?,
    pending: json['pending'] as int?,
    results: (json['results'] as List<dynamic>)
        .map((e) => ChangeResult.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

Map<String, dynamic> _$ChangeResponseToJson(ChangeResponse instance) =>
    <String, dynamic>{
      'last_seq': instance.lastSeq,
      'pending': instance.pending,
      'results': instance.results,
    };

ChangeRequest _$ChangeRequestFromJson(Map<String, dynamic> json) {
  return ChangeRequest(
    docIds:
        (json['doc_ids'] as List<dynamic>?)?.map((e) => e as String).toList(),
    conflicts: json['conflicts'] as bool,
    descending: json['descending'] as bool,
    feed: json['feed'] as String,
    filter: json['filter'] as String?,
    heartbeat: json['heartbeat'] as int,
    includeDocs: json['includeDocs'] as bool,
    attachments: json['attachments'] as bool,
    attEncodingInfo: json['attEncodingInfo'] as bool,
    lastEventId: json['lastEventId'] as int?,
    limit: json['limit'] as int?,
    since: json['since'] as String,
    style: json['style'] as String,
    timeout: json['timeout'] as int,
    view: json['view'] as String?,
    seqInterval: json['seqInterval'] as int?,
  );
}

Map<String, dynamic> _$ChangeRequestToJson(ChangeRequest instance) =>
    <String, dynamic>{
      'doc_ids': instance.docIds,
      'conflicts': instance.conflicts,
      'descending': instance.descending,
      'feed': instance.feed,
      'filter': instance.filter,
      'heartbeat': instance.heartbeat,
      'includeDocs': instance.includeDocs,
      'attachments': instance.attachments,
      'attEncodingInfo': instance.attEncodingInfo,
      'lastEventId': instance.lastEventId,
      'limit': instance.limit,
      'since': instance.since,
      'style': instance.style,
      'timeout': instance.timeout,
      'view': instance.view,
      'seqInterval': instance.seqInterval,
    };
