// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BookModelAdapter extends TypeAdapter<BookModel> {
  @override
  final int typeId = 0;

  @override
  BookModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BookModel(
      id: fields[0] as String,
      title: fields[1] as String,
      authors: fields[2] as String,
      categories: (fields[3] as List).cast<String>(),
      about: fields[4] as String,
      downloadCount: fields[5] as int,
      coverUrl: fields[6] as String,
      epubUrl: fields[7] as String,
      textUrl: fields[8] as String,
      htmlUrl: fields[9] as String,
      languages: (fields[10] as List).cast<String>(),
      copyright: fields[11] as bool,
      isFavorite: fields[12] as bool,
      scrollOffset: fields[13] as double,
      epubChapterIndex: fields[14] as int,
      lastReadAt: fields[15] as DateTime?,
      readingFinished: fields[16] as bool,
      rssUrl: fields[17] as String?,
      currentAudioChapter: fields[18] as int,
      currentAudioPosition: fields[19] as double,
      chapterListenedSeconds: (fields[20] as Map?)?.cast<String, double>(),
      totalAudioSeconds: fields[21] as double,
      lastListenedAt: fields[22] as DateTime?,
      listeningFinished: fields[23] as bool,
      maxScrollExtent: fields[24] as double,
    );
  }

  @override
  void write(BinaryWriter writer, BookModel obj) {
    writer
      ..writeByte(25)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.authors)
      ..writeByte(3)
      ..write(obj.categories)
      ..writeByte(4)
      ..write(obj.about)
      ..writeByte(5)
      ..write(obj.downloadCount)
      ..writeByte(6)
      ..write(obj.coverUrl)
      ..writeByte(7)
      ..write(obj.epubUrl)
      ..writeByte(8)
      ..write(obj.textUrl)
      ..writeByte(9)
      ..write(obj.htmlUrl)
      ..writeByte(10)
      ..write(obj.languages)
      ..writeByte(11)
      ..write(obj.copyright)
      ..writeByte(12)
      ..write(obj.isFavorite)
      ..writeByte(13)
      ..write(obj.scrollOffset)
      ..writeByte(14)
      ..write(obj.epubChapterIndex)
      ..writeByte(15)
      ..write(obj.lastReadAt)
      ..writeByte(16)
      ..write(obj.readingFinished)
      ..writeByte(17)
      ..write(obj.rssUrl)
      ..writeByte(18)
      ..write(obj.currentAudioChapter)
      ..writeByte(19)
      ..write(obj.currentAudioPosition)
      ..writeByte(20)
      ..write(obj.chapterListenedSeconds)
      ..writeByte(21)
      ..write(obj.totalAudioSeconds)
      ..writeByte(22)
      ..write(obj.lastListenedAt)
      ..writeByte(23)
      ..write(obj.listeningFinished)
      ..writeByte(24)
      ..write(obj.maxScrollExtent);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
