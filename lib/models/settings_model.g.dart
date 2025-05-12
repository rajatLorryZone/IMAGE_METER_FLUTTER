// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AppSettingsAdapter extends TypeAdapter<AppSettings> {
  @override
  final int typeId = 1;

  @override
  AppSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppSettings(
      defaultArrowColor: fields[0] as Color,
      defaultTextColor: fields[1] as Color,
      defaultFontSize: fields[2] as double,
      defaultArrowWidth: fields[3] as double,
      defaultDashedLine: fields[4] as bool,
      defaultShowArrowStyle: fields[5] as bool,
      defaultUnit: fields[6] as String,
      defaultBackgroundColor: fields[7] as Color,
    );
  }

  @override
  void write(BinaryWriter writer, AppSettings obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.defaultArrowColor)
      ..writeByte(1)
      ..write(obj.defaultTextColor)
      ..writeByte(2)
      ..write(obj.defaultFontSize)
      ..writeByte(3)
      ..write(obj.defaultArrowWidth)
      ..writeByte(4)
      ..write(obj.defaultDashedLine)
      ..writeByte(5)
      ..write(obj.defaultShowArrowStyle)
      ..writeByte(6)
      ..write(obj.defaultUnit)
      ..writeByte(7)
      ..write(obj.defaultBackgroundColor);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
