import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:hex_editor/editor.dart';
import 'package:provider/provider.dart';

const int baseColCount = 32;
const double rowHeight = 30;
const double indexGridWidth = 120;
const double baseDataGridWidth = 800;
const double baseCharGridWidth = 320;
const double paddingBetweenDataChar = 50;

const int blockMaxRowCount = 4;
const double blockHeight = blockMaxRowCount * rowHeight;

const BorderSide borderSide = BorderSide(color: Colors.grey, width: 1);
const BorderSide headerBorderSide = BorderSide(color: Colors.black, width: 1);

class TabState extends ChangeNotifier {
  TabState(this._length);

  int _length;
  int get length => _length;
  set length(int v) {
    _length = v;
    notifyListeners();
  }

  int _factor = 1;
  int get factor => _factor;
  set factor(int v) {
    _factor = v;
    notifyListeners();
  }

  int get colCount => baseColCount * factor;
  int get rowCount => (length + colCount - 1) ~/ colCount;

  double get dataGridWidth => baseDataGridWidth * factor;
  double get dataGridCellWidth => dataGridWidth / colCount;

  double get charGridWidth => baseCharGridWidth * factor;
  double get charGridCellWidth => charGridWidth / colCount;

  int get blockCount => (rowCount + blockMaxRowCount - 1) ~/ blockMaxRowCount;
  int get blockItemCount => colCount * blockMaxRowCount;
}

class HexTab {
  HexTab(
    double headerHeight,
    String path,
    void Function() headerOnclick,
    void Function() closeTab,
  ) : editor = Editor(path) {
    init();
    _overview = TabOverview(path, headerOnclick, closeTab);
    _header = TabHeader(headerHeight);
    _body = TabBody(editor);
  }

  void init() {
    editor.open();
    tabState = TabState(editor.length());
  }

  String get path {
    return editor.filePath;
  }

  late final TabState tabState;

  final Editor editor;

  late final TabOverview _overview;
  late final TabHeader _header;
  late final TabBody _body;

  Widget get overview {
    return ChangeNotifierProvider.value(
      key: ObjectKey(this),
      value: tabState,
      child: _overview,
    );
  }

  Widget get header {
    return ChangeNotifierProvider.value(
      key: ObjectKey(this),
      value: tabState,
      child: _header,
    );
  }

  Widget get body {
    return ChangeNotifierProvider.value(
      key: ObjectKey(this),
      value: tabState,
      child: _body,
    );
  }
}

class TabOverview extends StatelessWidget {
  const TabOverview(this.title, this.onclick, this.closeTab, {super.key});

  final String title;
  final void Function() onclick;
  final void Function() closeTab;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: MaterialButton(
            onPressed: onclick,
            child: Padding(
              padding: const EdgeInsets.only(left: 20, right: 20),
              child: Row(
                children: [
                  SelectableText(title),
                  Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: IconButton(
                      onPressed: closeTab,
                      icon: Icon(Icons.close),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class TabHeader extends StatelessWidget {
  const TabHeader(this.headerHeight, {super.key});

  final double headerHeight;

  @override
  Widget build(BuildContext context) {
    TabState tabBodyState = context.watch<TabState>();

    int factor = tabBodyState.factor;
    int colCount = tabBodyState.colCount;
    double dataGridWidth = tabBodyState.dataGridWidth;
    double dataGridColWidth = tabBodyState.dataGridCellWidth;
    double charGridWidth = tabBodyState.charGridWidth;

    List<Widget> header = [];
    for (int i = 0; i < colCount; i++) {
      String text = i.toRadixString(16).toUpperCase();
      text = text.padLeft(2, "0");
      header.add(
        SizedBox(
          width: dataGridColWidth,
          height: rowHeight,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                top: headerBorderSide,
                right: headerBorderSide,
                bottom: headerBorderSide,
              ),
            ),
            child: Center(child: Text(text)),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        height: rowHeight,
        child: Row(
          children: [
            Expanded(child: Container()),
            SizedBox(
              width: indexGridWidth,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: headerBorderSide,
                    right: headerBorderSide,
                    bottom: headerBorderSide,
                    left: headerBorderSide,
                  ),
                ),
                child: MaterialButton(
                  onPressed: () {
                    tabBodyState.factor = factor == 1 ? 2 : 1;
                  },
                  child: Text("toggle view"),
                ),
              ),
            ),
            SizedBox(
              width: dataGridWidth,
              child: Row(children: header),
            ),
            SizedBox(width: paddingBetweenDataChar, child: Container()),
            SizedBox(width: charGridWidth, child: Container()),
            Expanded(child: Container()),
          ],
        ),
      ),
    );
  }
}

class TabBody extends StatelessWidget {
  const TabBody(this.editor, {super.key});

  final Editor editor;

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);

    return Container(
      color: theme.colorScheme.surface,
      child: DefaultTextStyle(
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontFamily: "Consolas",
        ),
        child: _ScrollView(editor),
      ),
    );
  }
}

class _ScrollView extends StatelessWidget {
  _ScrollView(this.editor);

  final Editor editor;

  final ScrollController scrollController = ScrollController();
  final ScrollController dataGridScrollController = ScrollController();
  final ScrollController charGridScrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    scrollController.addListener(() {
      dataGridScrollController.jumpTo(scrollController.offset);
      charGridScrollController.jumpTo(scrollController.offset);
    });

    TabState tabBodyState = context.watch<TabState>();

    int length = tabBodyState.length;

    int colCount = tabBodyState.colCount;
    double dataGridWidth = tabBodyState.dataGridWidth;
    double dataGridColWidth = tabBodyState.dataGridCellWidth;
    double charGridWidth = tabBodyState.charGridWidth;
    double charGridColWidth = tabBodyState.charGridCellWidth;

    int rowCount = tabBodyState.rowCount;

    int blockCount = tabBodyState.blockCount;
    int blockItemCount = tabBodyState.blockItemCount;

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: Scrollbar(
        controller: scrollController,
        child: Listener(
          onPointerSignal: (e) {
            if (e is PointerScrollEvent) {
              double newValue = scrollController.offset + e.scrollDelta.dy;
              if (newValue < 0) {
                newValue = 0;
              }
              if (newValue > scrollController.position.maxScrollExtent) {
                newValue = scrollController.position.maxScrollExtent;
              }
              scrollController.jumpTo(newValue);
            }
          },
          child: Row(
            children: [
              Expanded(child: Container(color: Colors.transparent)),
              SizedBox(
                width: indexGridWidth,
                child: GridView.builder(
                  controller: scrollController,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 1,
                    childAspectRatio: indexGridWidth / rowHeight,
                  ),
                  itemCount: rowCount,
                  itemBuilder: (BuildContext context, int index) {
                    String numOfBytes = (index * colCount)
                        .toRadixString(16)
                        .toUpperCase();
                    return Container(
                      decoration: BoxDecoration(
                        border: Border(
                          right: borderSide,
                          bottom: borderSide,
                          left: borderSide,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(child: Text("0x$numOfBytes")),
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(
                width: dataGridWidth,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  controller: dataGridScrollController,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 1,
                    childAspectRatio: dataGridWidth / blockHeight,
                  ),
                  itemCount: blockCount,
                  itemBuilder: (context, index) {
                    int start = index * blockItemCount;
                    int count = min(blockItemCount, length - start);
                    return _Block(
                      count,
                      colCount,
                      blockMaxRowCount,
                      dataGridColWidth,
                      rowHeight,
                      Border(right: borderSide, bottom: borderSide),
                      (value) {
                        String hex = value.toRadixString(16).toLowerCase();
                        hex = hex.padLeft(2, "0");
                        return hex;
                      },
                      editor.read(start, count),
                    );
                  },
                ),
              ),
              SizedBox(
                width: paddingBetweenDataChar,
                child: Container(color: Colors.transparent),
              ),
              SizedBox(
                width: charGridWidth,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  controller: charGridScrollController,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 1,
                    childAspectRatio: charGridWidth / blockHeight,
                  ),
                    itemCount: blockCount,
                  itemBuilder: (context, index) {
                    int start = index * blockItemCount;
                    int count = min(blockItemCount, length - start);
                    return _Block(
                      count,
                      colCount,
                      blockMaxRowCount,
                      charGridColWidth,
                      rowHeight,
                      Border(),
                      (value) => String.fromCharCode(value),
                      editor.read(start, count),
                    );
                  },
                ),
              ),
              Expanded(child: Container(color: Colors.transparent)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block(
      this.itemCount,
      this.colCount,
      this.rowCount,
      this.colWidth,
      this.rowHeight,
      this.itemBorder,
      this.itemBuilder,
      this.data,
      );

  final int itemCount;
  final int colCount;
  final int rowCount;
  final double colWidth;
  final double rowHeight;
  final Border itemBorder;

  final String Function(int) itemBuilder;
  final Uint8List data;

  @override
  Widget build(BuildContext context) {
    DefaultTextStyle textStyle = DefaultTextStyle.of(context);

    List<List<String>> rows = [];
    List<String> cols = [];
    for (int i = 0; i < itemCount; i++) {
      String item;
      item = itemBuilder(data[i]);
      cols.add(item);
      if (cols.length == colCount || i == itemCount - 1) {
        rows.add(cols);
        cols = [];
      }
    }

    return CustomPaint(
      painter: _BlockPainter(
        colWidth,
        rowHeight,
        itemBorder,
        rows,
        textStyle.style,
      ),
    );
  }
}

class _BlockPainter extends CustomPainter {
  _BlockPainter(
    this.colWidth,
    this.rowHeight,
    this.itemBorder,
    this.texts,
    this.textStyle,
  );

  final double colWidth;
  final double rowHeight;
  final Border itemBorder;

  final List<List<String>> texts;
  final TextStyle textStyle;

  @override
  void paint(Canvas canvas, Size size) {
    var offset = Offset(0, 0);
    for (List<String> row in texts) {
      for (String item in row) {
        paintCell(canvas, size, item, offset);

        offset = offset.translate(colWidth, 0);
      }
      offset = offset.translate(-colWidth * row.length, rowHeight);
    }
  }

  void paintCell(Canvas canvas, Size size, String item, Offset offset) {
    TextPainter textPaint = TextPainter(
      text: TextSpan(text: item, style: textStyle),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    textPaint.layout(minWidth: colWidth, maxWidth: colWidth);
    textPaint.paint(
      canvas,
      offset.translate(0, (rowHeight - textPaint.height) / 2),
    );

    Paint paint;
    Rect rect;

    paint = Paint()..color = itemBorder.top.color;
    rect = Rect.fromLTWH(offset.dx, offset.dy, colWidth, itemBorder.top.width);
    canvas.drawRect(rect, paint);

    paint = Paint()..color = itemBorder.right.color;
    rect = Rect.fromLTWH(
      offset.dx + colWidth - itemBorder.right.width,
      offset.dy,
      itemBorder.right.width,
      rowHeight,
    );
    canvas.drawRect(rect, paint);

    paint = Paint()..color = itemBorder.bottom.color;
    rect = Rect.fromLTWH(
      offset.dx,
      offset.dy + rowHeight - itemBorder.bottom.width,
      colWidth,
      itemBorder.bottom.width,
    );
    canvas.drawRect(rect, paint);

    paint = Paint()..color = itemBorder.left.color;
    rect = Rect.fromLTWH(offset.dx, offset.dy, colWidth, itemBorder.left.width);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return this != oldDelegate;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is _BlockPainter && runtimeType == other.runtimeType &&
              colWidth == other.colWidth && rowHeight == other.rowHeight &&
              itemBorder == other.itemBorder && texts == other.texts &&
              textStyle == other.textStyle;

  @override
  int get hashCode =>
      Object.hash(colWidth, rowHeight, itemBorder, texts, textStyle);
}
