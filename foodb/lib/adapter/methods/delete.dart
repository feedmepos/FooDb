import 'package:json_annotation/json_annotation.dart';

part 'delete.g.dart';

@JsonSerializable()
class DeleteResponse {
  bool? ok;
  String? id;
  String? rev;
  String? error;
  String? reason;

  DeleteResponse({this.ok, this.id, this.rev, this.error, this.reason});

  factory DeleteResponse.fromJson(Map<String, dynamic> json) =>
      _$DeleteResponseFromJson(json);
  Map<String, dynamic> toJson() => _$DeleteResponseToJson(this);
}
