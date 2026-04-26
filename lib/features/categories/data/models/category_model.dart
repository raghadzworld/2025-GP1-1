import 'sound_setting_model.dart';

class CategoryModel {
  final String id;
  final String name;
  final bool isEnabled;
  final List<SoundSettingModel> sounds;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.isEnabled,
    required this.sounds,
  });

  CategoryModel copyWith({
    String? id,
    String? name,
    bool? isEnabled,
    List<SoundSettingModel>? sounds,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      isEnabled: isEnabled ?? this.isEnabled,
      sounds: sounds ?? this.sounds,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'isEnabled': isEnabled,
        'sounds': sounds.map((s) => s.toMap()).toList(),
      };

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] as String,
      name: map['name'] as String,
      isEnabled: map['isEnabled'] as bool? ?? false,
      sounds: (map['sounds'] as List<dynamic>? ?? [])
          .map((s) => SoundSettingModel.fromMap(
                Map<String, dynamic>.from(s as Map),
              ))
          .toList(),
    );
  }
}
