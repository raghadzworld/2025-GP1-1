class SoundSettingModel {
  final String soundId;
  final String name;
  final bool isEmergency;
  final bool isEnabled;
  final int vibrationPower;   // 1=خفيف, 2=متوسط, 3=قوي
  final int vibrationPattern; // 1=خفيف, 2=متوسط, 3=قوي

  const SoundSettingModel({
    required this.soundId,
    required this.name,
    required this.isEmergency,
    required this.isEnabled,
    required this.vibrationPower,
    required this.vibrationPattern,
  });

  SoundSettingModel copyWith({
    bool? isEnabled,
    int? vibrationPower,
    int? vibrationPattern,
  }) {
    return SoundSettingModel(
      soundId: soundId,
      name: name,
      isEmergency: isEmergency,
      isEnabled: soundId == 'fire_alarm' ? true : (isEnabled ?? this.isEnabled),
      vibrationPower: vibrationPower ?? this.vibrationPower,
      vibrationPattern: vibrationPattern ?? this.vibrationPattern,
    );
  }

  Map<String, dynamic> toMap() => {
        'soundId': soundId,
        'name': name,
        'isEmergency': isEmergency,
        'isEnabled': soundId == 'fire_alarm' ? true : isEnabled,
        'vibrationPower': vibrationPower,
        'vibrationPattern': vibrationPattern,
      };

  factory SoundSettingModel.fromMap(Map<String, dynamic> map) {
    final id = map['soundId'] as String;
    return SoundSettingModel(
      soundId: id,
      name: map['name'] as String,
      isEmergency: map['isEmergency'] as bool? ?? id == 'fire_alarm',
      isEnabled: id == 'fire_alarm' ? true : (map['isEnabled'] as bool? ?? false),
      vibrationPower: map['vibrationPower'] as int? ?? 2,
      vibrationPattern: map['vibrationPattern'] as int? ?? 1,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SoundSettingModel && soundId == other.soundId;

  @override
  int get hashCode => soundId.hashCode;
}
