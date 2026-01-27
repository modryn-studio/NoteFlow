// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'analytics_event.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TagCorrectionEventAdapter extends TypeAdapter<TagCorrectionEvent> {
  @override
  final int typeId = 2;

  @override
  TagCorrectionEvent read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TagCorrectionEvent()
      ..eventId = fields[0] as String
      ..noteId = fields[1] as String
      ..noteContent = fields[2] as String
      ..originalTags = (fields[3] as List).cast<String>()
      ..finalTags = (fields[4] as List).cast<String>()
      ..addedTags = (fields[5] as List).cast<String>()
      ..removedTags = (fields[6] as List).cast<String>()
      ..timestamp = fields[7] as DateTime
      ..userId = fields[8] as String
      ..synced = fields[9] as bool;
  }

  @override
  void write(BinaryWriter writer, TagCorrectionEvent obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.eventId)
      ..writeByte(1)
      ..write(obj.noteId)
      ..writeByte(2)
      ..write(obj.noteContent)
      ..writeByte(3)
      ..write(obj.originalTags)
      ..writeByte(4)
      ..write(obj.finalTags)
      ..writeByte(5)
      ..write(obj.addedTags)
      ..writeByte(6)
      ..write(obj.removedTags)
      ..writeByte(7)
      ..write(obj.timestamp)
      ..writeByte(8)
      ..write(obj.userId)
      ..writeByte(9)
      ..write(obj.synced);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TagCorrectionEventAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
