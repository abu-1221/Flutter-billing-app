// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sale_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SaleModelAdapter extends TypeAdapter<SaleModel> {
  @override
  final int typeId = 3;

  @override
  SaleModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SaleModel(
      saleId: fields[0] as String,
      productId: fields[1] as String,
      barcode: fields[2] as String,
      transactionId: fields[3] as String,
      soldAt: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, SaleModel obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.saleId)
      ..writeByte(1)
      ..write(obj.productId)
      ..writeByte(2)
      ..write(obj.barcode)
      ..writeByte(3)
      ..write(obj.transactionId)
      ..writeByte(4)
      ..write(obj.soldAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SaleModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
