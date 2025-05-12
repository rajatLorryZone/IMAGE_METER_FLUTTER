// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'arrow_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ArrowModelAdapter extends TypeAdapter<ArrowModel> {
  @override
  final int typeId = 0;

  @override
  ArrowModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ArrowModel(
      start: fields[0] as Offset,
      end: fields[1] as Offset,
      label: fields[2] as String?,
      unit: fields[3] as String,
      arrowColor: fields[4] as Color,
      textColor: fields[5] as Color,
      fontSize: fields[6] as double,
      arrowWidth: fields[7] as double,
      isDashed: fields[9] as bool,
      showArrowStyle: fields[10] as bool,
    )
      ..middlePoint = fields[8] as Offset
      ..isSelected = fields[11] == null ? false : fields[11] as bool;
  }

  @override
  void write(BinaryWriter writer, ArrowModel obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.start)
      ..writeByte(1)
      ..write(obj.end)
      ..writeByte(2)
      ..write(obj.label)
      ..writeByte(3)
      ..write(obj.unit)
      ..writeByte(4)
      ..write(obj.arrowColor)
      ..writeByte(5)
      ..write(obj.textColor)
      ..writeByte(6)
      ..write(obj.fontSize)
      ..writeByte(7)
      ..write(obj.arrowWidth)
      ..writeByte(8)
      ..write(obj.middlePoint)
      ..writeByte(9)
      ..write(obj.isDashed)
      ..writeByte(10)
      ..write(obj.showArrowStyle)
      ..writeByte(11)
      ..write(obj.isSelected);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ArrowModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
