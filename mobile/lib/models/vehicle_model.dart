class VehicleModel {
  final int id;
  final String plate;
  final String type; // 'moto' o 'automovil'
  final String brandModel;
  final String createdAt;

  VehicleModel({
    required this.id,
    required this.plate,
    required this.type,
    required this.brandModel,
    required this.createdAt,
  });

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      id: json['id'] as int? ?? 0,
      plate: json['plate'] as String? ?? '',
      type: json['type'] as String? ?? 'automovil',
      brandModel: json['brand_model'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'plate': plate,
      'type': type,
      'brand_model': brandModel,
      'created_at': createdAt,
    };
  }

  bool get isMoto => type.toLowerCase() == 'moto';
  int get defaultRate => isMoto ? 4000 : 5000;
}
