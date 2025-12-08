import 'dart:io';
import 'dart:typed_data';

import 'package:hex_editor/lru_cache.dart';

class Editor {
  static const int _capacity = 512;
  static const int _blockSize = 1024;

  Editor(this.filePath);

  final String filePath;
  late final LRUCache<int, Uint8List> cache = LRUCache(_capacity, (k) {
    return _read(k * _blockSize, _blockSize);
  });
  RandomAccessFile? file;

  void open() {
    if (file != null) throw EditorOpenedException();
    File f = File(filePath);
    file = f.openSync();
  }

  int length() {
    if (file == null) throw EditorUnopenException();
    return file!.lengthSync();
  }

  Uint8List _read(int start, int count) {
    if (file == null) throw EditorUnopenException();
    file!.setPositionSync(start);
    return file!.readSync(count);
  }

  /// @param start 对于要读取的第一个字节,其的偏移量
  /// @param count 要读取的字节数
  Uint8List read(int start, int count) {
    int startBlock = start ~/ _blockSize;
    int endBlock = (start + count - 1) ~/ _blockSize + 1;
    List<Uint8List> blocks = [];
    for (int i = startBlock; i < endBlock; i++) {
      Uint8List? block = cache[i];
      if (block == null) {
        throw OutOfMemoryError();
      }
      blocks.add(block);
    }
    int startInBlocks = start - startBlock * _blockSize;
    int endInBlocks = startInBlocks + count;
    return Uint8List.fromList(
      blocks.expand((element) => element).toList(),
    ).sublist(startInBlocks, endInBlocks);
  }
}

class EditorUnopenException implements Exception {}

class EditorOpenedException implements Exception {}
