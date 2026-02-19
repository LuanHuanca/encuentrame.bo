/// Modelo de puesto (stall). Alineado con tabla DynamoDB stalls.
class StallModel {
  StallModel({
    required this.pk,
    this.name = '',
    this.description,
    this.gsi1pk,
    this.gsi1sk,
  });

  final String pk;
  final String name;
  final String? description;
  final String? gsi1pk;
  final String? gsi1sk;

  factory StallModel.fromJson(Map<String, dynamic> json) {
    return StallModel(
      pk: json['pk'] as String,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      gsi1pk: json['gsi1pk'] as String?,
      gsi1sk: json['gsi1sk'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'pk': pk,
    'name': name,
    if (description != null) 'description': description,
    if (gsi1pk != null) 'gsi1pk': gsi1pk,
    if (gsi1sk != null) 'gsi1sk': gsi1sk,
  };
}
