import 'package:equatable/equatable.dart';

class VisitType extends Equatable {
  final int id;
  final String name;

  const VisitType({required this.id, required this.name});

  factory VisitType.fromJson(Map<String, dynamic> json) => VisitType(
        id: (json['id'] as num).toInt(),
        name: (json['name'] ?? '').toString(),
      );

  @override
  List<Object?> get props => [id, name];
}
