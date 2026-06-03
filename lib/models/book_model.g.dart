// GENERATED CODE - DO NOT MODIFY BY HAND
part of 'book_model.dart';

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
      epubUrl: fields[7] != null ? fields[7] as String : '',
      textUrl: fields[8] != null ? fields[8] as String : '',
      htmlUrl: fields[9] != null ? fields[9] as String : '',
      languages: fields[10] != null
          ? (fields[10] as List).cast<String>()
          : const ['en'],
      copyright: fields[11] != null ? fields[11] as bool : false,
      isFavorite: fields[12] != null ? fields[12] as bool : false,
      scrollOffset: fields[13] != null ? fields[13] as double : 0.0,
      epubChapterIndex: fields[14] != null ? fields[14] as int : 0,
      lastReadAt: fields[15] != null ? fields[15] as DateTime : null,
      readingFinished: fields[16] != null ? fields[16] as bool : false,
      rssUrl: fields[17] as String?,
      currentAudioChapter: fields[18] != null ? fields[18] as int : 0,
      currentAudioPosition: fields[19] != null ? fields[19] as double : 0.0,
      chapterListenedSeconds: fields[20] != null
          ? (fields[20] as Map).cast<String, double>()
          : {},
      totalAudioSeconds: fields[21] != null ? fields[21] as double : 0.0,
      lastListenedAt: fields[22] != null ? fields[22] as DateTime : null,
      listeningFinished: fields[23] != null ? fields[23] as bool : false,
    );
  }

  @override
  void write(BinaryWriter writer, BookModel obj) {
    writer
      ..writeByte(24)
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
      ..write(obj.listeningFinished);
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
