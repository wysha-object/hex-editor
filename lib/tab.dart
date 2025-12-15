import 'dart:io';
import 'dart:math';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:hex_editor/editor.dart';
import 'package:provider/provider.dart';

const int baseColCount = 16;
const double rowHeight = 30;
const double indexGridWidth = 130;
const double baseDataGridWidth = 400;
const double baseCharGridWidth = 160;
const double paddingBetweenDataChar = 50;

const int _blockRowCount = 16;

const double fontWidthHighRatio = 0.6;

int baseCellBytesCount = 1;

BorderSide _gridBorderSide(ThemeData theme) => BorderSide(width: 1, color: theme.colorScheme.surfaceContainerHighest);

/// 由外部管理
class HexTabState extends ChangeNotifier {
  HexTabState();

  late HexTab _current;

  HexTab get current => _current;

  set current(HexTab v) {
    _current = v;
    notifyListeners();
  }
}

/// 由HexTab管理
class _State extends ChangeNotifier {
  _State(this._editor) {
    scrollController.addListener(() {
      indexScrollController.jumpTo(scrollController.offset);
      dataScrollController.jumpTo(scrollController.offset);
      charScrollController.jumpTo(scrollController.offset);
    });

    indexScrollController.addListener(() {
      if (indexScrollController.offset != scrollController.offset) {
        scrollController.jumpTo(indexScrollController.offset);
      }
    });
    dataScrollController.addListener(() {
      if (dataScrollController.offset != scrollController.offset) {
        scrollController.jumpTo(dataScrollController.offset);
      }
    });
    charScrollController.addListener(() {
      if (charScrollController.offset != scrollController.offset) {
        scrollController.jumpTo(charScrollController.offset);
      }
    });
  }

  final ScrollController scrollController = ScrollController();

  final ScrollController indexScrollController = ScrollController();
  final ScrollController dataScrollController = ScrollController();
  final ScrollController charScrollController = ScrollController();

  final TextEditingController fromController = TextEditingController();
  final TextEditingController toController = TextEditingController();

  int get from => int.parse(fromController.text, radix: 16);

  int get to => int.parse(toController.text, radix: 16);

  final TextEditingController jumpController = TextEditingController();

  int get jump => int.parse(jumpController.text, radix: 16);

  void jumpTo(int addr) {
    scrollController.jumpTo((addr / colCount) * rowHeight);
  }

  int get length => _editor.length();

  int _cellBytesCountFactor = 1;

  int get cellBytesCountFactor => _cellBytesCountFactor;

  set cellBytesCountFactor(int v) {
    _cellBytesCountFactor = v;
    notifyListeners();
  }

  ///每个单元格展示的字节数量
  int get cellBytesCount => baseCellBytesCount * cellBytesCountFactor;

  int _colCountFactor = 2;

  int get colCountFactor => _colCountFactor;

  set colCountFactor(int v) {
    _colCountFactor = v;
    notifyListeners();
  }

  int get cellCount => (length + cellBytesCount - 1) ~/ cellBytesCount;

  int get colCount => baseColCount * colCountFactor;

  int get rowBytesCount => cellBytesCount * colCount;

  int get rowCount => (cellCount + colCount - 1) ~/ colCount;

  double get dataGridWidth => baseDataGridWidth * colCountFactor * cellBytesCount;

  double get dataGridCellWidth => dataGridWidth / colCount;

  double get charGridWidth => baseCharGridWidth * colCountFactor * cellBytesCount;

  double get charGridCellWidth => charGridWidth / colCount;

  int get blockCount => (rowCount + _blockRowCount - 1) ~/ _blockRowCount;

  int get blockCellCount => _blockRowCount * colCount;

  int get blockBytesCount => blockCellCount * cellBytesCount;

  double get blockHeight => rowHeight * _blockRowCount;

  final Editor _editor;

  Uint8List read(int start, int count) {
    return _editor.read(start, count);
  }

  /// 含头不含尾
  void overwrite(int from, int to, Uint8List data) {
    int count = to - from;
    if (count > data.length) {
      Uint8List tmp = data;
      data = Uint8List(count);
      data.setRange(0, tmp.length, tmp);
    } else if (count < data.length) {
      data = data.sublist(0, count);
    }

    _editor.write(from, data);
    notifyListeners();
  }
}

class HexTab {
  HexTab(double headerHeight, String path, void Function() headerOnclick, void Function() closeTab) {
    Editor editor = Editor(path);
    editor.open();
    _tabState = _State(editor);

    _overview = TabOverview(this, path, headerOnclick, closeTab);
    _header = TabHeader(headerHeight);
    _body = TabBody();
    _toolbar = TabToolbar();
  }

  String get path {
    return _tabState._editor.filePath;
  }

  late final _State _tabState;

  late final TabOverview _overview;
  late final TabHeader _header;
  late final TabBody _body;
  late final TabToolbar _toolbar;

  Widget get overview {
    return ChangeNotifierProvider.value(value: _tabState, child: _overview);
  }

  Widget get header {
    return ChangeNotifierProvider.value(value: _tabState, child: _header);
  }

  Widget get body {
    return ChangeNotifierProvider.value(value: _tabState, child: _body);
  }

  Widget get toolbar {
    return ChangeNotifierProvider.value(value: _tabState, child: _toolbar);
  }
}

class TabOverview extends StatelessWidget {
  const TabOverview(this._tab, this.title, this.onclick, this.closeTab, {super.key});

  final HexTab _tab;

  final String title;

  final void Function() onclick;
  final void Function() closeTab;

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    HexTabState tabBarState = context.watch<HexTabState>();

    _State state = context.watch<_State>();

    Color color = Colors.transparent;
    if (tabBarState.current == _tab) {
      color = theme.colorScheme.surfaceContainerHighest;
    }

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide.none,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(5))),
                foregroundColor: theme.colorScheme.onSurface,
                backgroundColor: Colors.transparent,
              ),
              onPressed: onclick,
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Container(
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)),
                      child: Padding(
                        padding: const EdgeInsets.all(5),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SelectableText(style: theme.textTheme.titleMedium, title),
                            SelectableText(style: theme.textTheme.bodySmall, "${state.length} Bytes"),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  IconButton(onPressed: closeTab, icon: Icon(Icons.close)),
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
    ThemeData theme = Theme.of(context);
    DefaultTextStyle defaultTextStyle = DefaultTextStyle.of(context);

    _State state = context.watch<_State>();

    int factor = state.colCountFactor;
    int cellBytesCount = state.cellBytesCount;
    int colCount = state.colCount;
    double dataGridWidth = state.dataGridWidth;
    double dataGridColWidth = state.dataGridCellWidth;
    double charGridWidth = state.charGridWidth;

    BorderSide borderSide = _gridBorderSide(theme);

    List<Widget> header = [];
    for (int i = 0; i < colCount; i++) {
      String text = (i * cellBytesCount).toRadixString(16).toUpperCase();
      text = text.padLeft(2, "0");
      header.add(
        SizedBox(
          width: dataGridColWidth,
          height: rowHeight,
          child: Container(
            decoration: BoxDecoration(
              border: Border(top: borderSide, right: borderSide, bottom: borderSide),
            ),
            child: Center(child: Text(text, style: defaultTextStyle.style)),
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
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: borderSide,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  backgroundColor: Colors.transparent,
                  foregroundColor: defaultTextStyle.style.color,
                  textStyle: defaultTextStyle.style,
                ),
                onPressed: () {
                  state.colCountFactor = factor == 2 ? 4 : 2;
                },
                child: Text("toggle view"),
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
  TabBody({super.key});

  final GlobalKey _key = GlobalKey();

  double get pageHeight => _key.currentContext!.size!.height;

  final TextSelectionControls _dataSelectionControls = MaterialTextSelectionControls();
  final TextSelectionControls _charSelectionControls = MaterialTextSelectionControls();

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    _State state = context.watch<_State>();

    ScrollController scrollController = state.scrollController;
    int length = state.length;
    int rowCount = state.rowCount;
    int colCount = state.colCount;

    int cellBytesCount = state.cellBytesCount;
    int rowBytesCount = state.rowBytesCount;

    double dataGridWidth = state.dataGridWidth;
    double dataGridColWidth = state.dataGridCellWidth;
    double charGridWidth = state.charGridWidth;
    double charGridColWidth = state.charGridCellWidth;

    BorderSide borderSide = _gridBorderSide(theme);

    ScrollController indexScrollController = state.indexScrollController;
    ScrollController dataScrollController = state.dataScrollController;
    ScrollController charScrollController = state.charScrollController;

    int blockCount = state.blockCount;
    int blockBytesCount = state.blockBytesCount;
    double blockHeight = state.blockHeight;

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: Scrollbar(
        controller: scrollController,
        child: Listener(
          onPointerSignal: (event) {
            if (event is PointerScrollEvent) {
              double newOffset = scrollController.offset + event.scrollDelta.dy;

              double totalHeight = rowCount * rowHeight;
              double maxOffset = totalHeight < pageHeight ? 0 : totalHeight - (pageHeight * (3 / 4)); //滚到顶部后最多再滚4/1个页面高度
              if (newOffset < 0) {
                newOffset = 0;
              } else if (newOffset > maxOffset) {
                newOffset = maxOffset;
              }
              scrollController.jumpTo(newOffset);
            }
          },
          child: Row(
            key: _key,
            children: [
              SizedBox(
                width: 0,
                child: GridView.builder(
                  controller: scrollController,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 1, mainAxisExtent: rowHeight),
                  itemCount: rowCount,
                  itemBuilder: (context, index) {
                    return Container();
                  },
                ),
              ),
              Expanded(child: Container(color: Colors.transparent)),
              SizedBox(
                width: indexGridWidth,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  controller: indexScrollController,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 1, mainAxisExtent: rowHeight),
                  itemCount: rowCount,
                  itemBuilder: (context, index) {
                    index *= rowBytesCount;
                    return Container(
                      decoration: BoxDecoration(
                        border: Border(right: borderSide, bottom: borderSide, left: borderSide),
                      ),
                      child: Center(child: Text("0x${index.toRadixString(16).padLeft(8, "0")}")),
                    );
                  },
                ),
              ),
              SizedBox(
                width: dataGridWidth,
                child: SelectableRegion(
                  selectionControls: _dataSelectionControls,
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    controller: dataScrollController,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 1, mainAxisExtent: blockHeight),
                    itemCount: blockCount,
                    itemBuilder: (context, index) {
                      index = index * blockBytesCount;
                      Uint8List bytes = state.read(index, min(blockBytesCount, length - index));
                      int cellCount = (bytes.length + cellBytesCount - 1) ~/ cellBytesCount;

                      List<String> cells = [];
                      for (int i = 0; i < cellCount; i++) {
                        int start = i * cellBytesCount;
                        Uint8List cellBytes = bytes.sublist(start, min(start + cellBytesCount, bytes.length));

                        StringBuffer cellBuffer = StringBuffer();
                        for (int j = cellBytes.length - 1; j >= 0; j--) {
                          cellBuffer.write(cellBytes[j].toRadixString(16).padLeft(2, "0"));
                        }
                        cells.add(cellBuffer.toString());
                      }

                      return _Block(
                        size: Size(dataGridWidth, blockHeight),
                        strLength: cellBytesCount * 2,
                        texts: cells,
                        border: Border(right: borderSide, bottom: borderSide),
                        cellSize: Size(dataGridColWidth, rowHeight),
                        colCount: colCount,
                      );
                    },
                  ),
                ),
              ),
              SizedBox(
                width: paddingBetweenDataChar,
                child: Container(color: Colors.transparent),
              ),
              SizedBox(
                width: charGridWidth,
                child: SelectableRegion(
                  selectionControls: _charSelectionControls,
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    controller: charScrollController,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 1, mainAxisExtent: blockHeight),
                    itemCount: blockCount,
                    itemBuilder: (context, index) {
                      index = index * blockBytesCount;
                      Uint8List bytes = state.read(index, min(blockBytesCount, length - index));
                      int cellCount = (bytes.length + cellBytesCount - 1) ~/ cellBytesCount;

                      List<String> cells = [];
                      for (int i = 0; i < cellCount; i++) {
                        int start = i * cellBytesCount;
                        Uint8List cellBytes = bytes.sublist(start, min(start + cellBytesCount, bytes.length));

                        StringBuffer cellBuffer = StringBuffer();
                        for (int j = cellBytes.length - 1; j >= 0; j--) {
                          int byte = cellBytes[j];
                          String str = String.fromCharCode(byte);
                          if (str.length != 1) str = "□"; //U+25A1;
                          cellBuffer.write(str);
                        }
                        cells.add(cellBuffer.toString());
                      }

                      return _Block(
                          size: Size(charGridWidth, blockHeight),
                          strLength: cellBytesCount,
                          texts: cells,
                          border: Border(),
                          cellSize: Size(charGridColWidth, rowHeight),
                          colCount: colCount
                      );
                    },
                  ),
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
  const _Block({required this.size, required this.strLength, required this.texts, required this.border, required this.cellSize, required this.colCount});

  ///整个 Block 的 大小
  final Size size;

  ///[texts]中每个 字符串 的 字符数
  final int strLength;

  ///由 用以显示的字符串 组成的列表
  final List<String> texts;

  ///指定每个 cell 的 边框 , 将会作用到每个 cell
  final Border border;

  ///每个 cell 的 大小
  final Size cellSize;

  ///列数
  ///同时用以计算 行数
  final int colCount;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(cursor: SystemMouseCursors.text,
        child: _BlockSelectableAdapter(size: size,
            strLength: strLength,
            texts: texts,
            border: border,
            cellSize: cellSize,
            colCount: colCount));
  }
}

class _BlockSelectableAdapter extends LeafRenderObjectWidget {
  const _BlockSelectableAdapter({required this.size, required this.strLength, required this.texts, required this.border, required this.cellSize, required this.colCount});

  final Size size;

  final int strLength;

  final List<String> texts;

  final Border border;

  final Size cellSize;

  final int colCount;

  @override
  RenderObject createRenderObject(BuildContext context) {
    SelectionRegistrar registrar = SelectionContainer.maybeOf(context)!;
    DefaultTextStyle defaultTextStyle = DefaultTextStyle.of(context);
    DefaultSelectionStyle defaultSelectionStyle = DefaultSelectionStyle.of(context);
    ThemeData theme = Theme.of(context);
    return _BlockRenderBox(
        selectionRegistrar: registrar,
        selectedBackground: theme.textSelectionTheme.selectionColor ?? defaultSelectionStyle.selectionColor ?? theme.colorScheme.primary,
        blockSize: size,
        strLength: strLength,
        charWidth: defaultTextStyle.style.fontSize! * fontWidthHighRatio,
        charHeight: defaultTextStyle.style.fontSize!,
        texts: texts.map((str) => TextSpan(text: str, style: defaultTextStyle.style)).toList(),
        border: border,
        cellWidth: cellSize.width,
        cellHeight: cellSize.height,
        colCount: colCount
    );
  }

  @override
  void updateRenderObject(BuildContext context, _BlockRenderBox renderObject) {
    DefaultTextStyle defaultTextStyle = DefaultTextStyle.of(context);
    DefaultSelectionStyle defaultSelectionStyle = DefaultSelectionStyle.of(context);
    ThemeData theme = Theme.of(context);
    renderObject
      ..selectedBackground = theme.textSelectionTheme.selectionColor ?? defaultSelectionStyle.selectionColor ?? theme.colorScheme.primary
      ..blockSize = size
      ..strLength = strLength
      ..charWidth = defaultTextStyle.style.fontSize! * fontWidthHighRatio
      ..charHeight = defaultTextStyle.style.fontSize!
      ..texts = texts.map((str) => TextSpan(text: str, style: defaultTextStyle.style)).toList()
      ..border = border
      ..cellWidth = cellSize.width
      ..cellHeight = cellSize.height
      ..colCount = colCount;
  }
}

class _BlockRenderBox extends RenderBox with Selectable, SelectionRegistrant {
  static const SelectionGeometry _noSelection = SelectionGeometry(status: SelectionStatus.none, hasContent: true);

  ///用于占位
  static const SelectionPoint ignore = SelectionPoint(localPosition: Offset.zero, lineHeight: 0, handleType: TextSelectionHandleType.collapsed);

  _BlockRenderBox({required SelectionRegistrar selectionRegistrar, required Color selectedBackground, required Size blockSize, required int strLength, required double charWidth, required double charHeight, required List<
      TextSpan> texts, required Border border, required double cellWidth, required double cellHeight, required int colCount})
      :
        _blockSize = blockSize,
        _selectedBackground = selectedBackground,
        _strLength = strLength,
        _charWidth = charWidth,
        _charHeight = charHeight,
        _texts = texts,
        _border = border,
        _cellWidth = cellWidth,
        _cellHeight = cellHeight,
        _colCount = colCount {
    registrar = selectionRegistrar;
    _selectionGeometry.addListener(markNeedsPaint);
  }

  final ValueNotifier<SelectionGeometry> _selectionGeometry = ValueNotifier(_noSelection);

  Color get selectedBackground => _selectedBackground;

  set selectedBackground(Color color) {
    _selectedBackground = color;
    markNeedsPaint();
  }

  Color _selectedBackground;

  Size get blockSize => _blockSize;

  set blockSize(Size value) {
    _blockSize = value;
    markNeedsLayout();
  }

  Size _blockSize;

  ///[texts]中每个 字符串 的 字符数
  int get strLength => _strLength;

  set strLength(int value) {
    _strLength = value;
    markNeedsPaint();
  }

  int _strLength;

  double get strWidth => strLength * charWidth;

  double get strHeight => charHeight;

  ///字符总数
  int get charCount => texts.length * strLength;


  double get charWidth => _charWidth;

  set charWidth(double value) {
    _charWidth = value;
    markNeedsLayout();
  }

  double _charWidth;


  double get charHeight => _charHeight;

  set charHeight(double value) {
    _charHeight = value;
    markNeedsLayout();
  }

  double _charHeight;


  List<TextSpan> get texts => _texts;

  set texts(List<TextSpan> value) {
    _texts = value;
    markNeedsPaint();
  }

  List<TextSpan> _texts;


  Border get border => _border;

  set border(Border value) {
    _border = value;
    markNeedsPaint();
  }

  Border _border;


  double get cellWidth => _cellWidth;

  set cellWidth(double value) {
    _cellWidth = value;
    markNeedsLayout();
  }

  double _cellWidth;


  double get cellHeight => _cellHeight;

  set cellHeight(double value) {
    _cellHeight = value;
    markNeedsLayout();
  }

  double _cellHeight;


  int get colCount => _colCount;

  set colCount(int value) {
    _colCount = value;
    markNeedsLayout();
  }

  int _colCount;


  int getCellIndex(Offset offset) {
    return max(0, min(colCount - 1, (offset.dx ~/ cellWidth))) + (offset.dy ~/ cellHeight) * colCount;
  }


  ///当offset.dx超出最大值限制时,与[getCellIndex]不同,[getCharIndexInString]将会返回[strLength],即下一个cell第一个char的索引,而非当前cell最后一个char的索引
  ///当offset.dx指向当前单元格中str右边时,同上
  int getCharIndexInString(Offset offset) {
    int colIndex = offset.dx ~/ cellWidth;
    if (colIndex < 0) return 0;
    if (colIndex >= colCount) return strLength;
    double cellXOffset = offset.dx - colIndex * cellWidth;
    cellXOffset -= (cellWidth - strWidth) / 2;
    return max(0, min(strLength, cellXOffset ~/ charWidth));
  }

  int getCharIndex(Offset offset) {
    return getCellIndex(offset) * strLength + getCharIndexInString(offset);
  }

  int get startIndex => max(0, min(charCount, getCharIndex(startOffset!)));

  int get endIndex => max(0, min(charCount, getCharIndex(endOffset!)));

  @override
  void performLayout() {
    size = blockSize;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    Canvas canvas = context.canvas;
    int index = 0;

    for (Rect selected in value.selectionRects) {
      Paint paint = Paint()
        ..color = selectedBackground;
      canvas.drawRect(selected, paint);
    }

    BREAK:
    while (true) {
      for (int i = 0; i < colCount; i++, index++) {
        if (index >= texts.length) {
          break BREAK;
        }

        double x = cellWidth * i;
        double y = index ~/ colCount * cellHeight;

        TextSpan text = texts[index];

        TextPainter painter = TextPainter(
          text: text,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
        );
        painter.layout(minWidth: cellWidth);
        painter.paint(canvas, Offset(x, y + (cellHeight - painter.height) / 2));

        _paintBorder(canvas, x, y);
      }
    }
  }

  void _paintBorder(Canvas canvas, double x, double y) {
    _paintBorderSide(canvas, border.top, x, y, cellWidth, border.top.width);
    _paintBorderSide(canvas, border.right, x + cellWidth - border.right.width, y, border.right.width, cellHeight);
    _paintBorderSide(canvas, border.bottom, x, y + cellHeight - border.bottom.width, cellWidth, border.bottom.width);
    _paintBorderSide(canvas, border.left, x, y, border.left.width, cellHeight);
  }

  void _paintBorderSide(Canvas canvas, BorderSide side, double x, double y, double width, double height) {
    if (side.style == BorderStyle.none) {
      return;
    }

    Rect rect = Rect.fromLTWH(x, y, width, height);
    Paint paint = Paint()
      ..color = side.color;
    canvas.drawRect(rect, paint);
  }

  @override
  void addListener(VoidCallback listener) {
    _selectionGeometry.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _selectionGeometry.removeListener(listener);
  }

  @override
  List<Rect> get boundingBoxes => <Rect>[paintBounds];

  @override
  int get contentLength => charCount;

  @override
  SelectionResult dispatchSelectionEvent(SelectionEvent event) {
    SelectionResult rs;
    switch (event.type) {
      case SelectionEventType.startEdgeUpdate:
      case SelectionEventType.endEdgeUpdate:
        SelectionEdgeUpdateEvent e = event as SelectionEdgeUpdateEvent;
        Offset localPoint = globalToLocal(e.globalPosition);
        Offset adjustedLocalPoint = SelectionUtils.adjustDragOffset(paintBounds, localPoint);
        if (event.type == SelectionEventType.startEdgeUpdate) {
          startOffset = adjustedLocalPoint;
        } else {
          endOffset = adjustedLocalPoint;
        }
        rs = SelectionUtils.getResultBasedOnRect(paintBounds, localPoint);
        break;

      case SelectionEventType.clear:
        startOffset = null;
        endOffset = null;
        rs = SelectionResult.none;
        break;

      case SelectionEventType.selectAll:
        startOffset = paintBounds.topLeft;
        endOffset = paintBounds.bottomRight;
        rs = SelectionResult.none;
        break;

      case SelectionEventType.selectWord:
        SelectWordSelectionEvent e = event as SelectWordSelectionEvent;
        Offset selectWordLocalOffset = globalToLocal(e.globalPosition);
        int textIndex = getCellIndex(selectWordLocalOffset);

        int rowIndex = textIndex ~/ colCount;
        int colIndex = textIndex % colCount;

        startOffset = Offset(colIndex * cellWidth, rowIndex * cellHeight);
        endOffset = Offset(colIndex * cellWidth + cellWidth - 1, rowIndex * cellHeight + cellHeight - 1);

        rs = SelectionResult.none;
        break;

      case SelectionEventType.selectParagraph:
        rs = SelectionResult.none;
        break;

      case SelectionEventType.granularlyExtendSelection:
        rs = SelectionResult.none;
        break;

      case SelectionEventType.directionallyExtendSelection:
        rs = SelectionResult.none;
        break;
    }

    _updateGeometry();
    return rs;
  }

  Offset? startOffset;

  Offset? endOffset;

  void _updateGeometry() {
    if (startOffset == null || endOffset == null) {
      _selectionGeometry.value = _noSelection;
      return;
    }

    int low = startIndex;
    int high = endIndex;

    if (low > high) {
      int tmp = low;
      low = high;
      high = tmp;
    }

    if (low == high) {
      _selectionGeometry.value = _noSelection;
      return;
    }

    List<Rect> selectionRects = [];
    for (int i = low; i < high; i++) {
      int textIndex = i ~/ strLength;
      int charIndex = i % strLength;

      int rowIndex = textIndex ~/ colCount;
      int colIndex = textIndex % colCount;

      Rect rect = Rect.fromLTWH(
          colIndex * cellWidth + (cellWidth - strWidth) / 2 + charIndex * charWidth,
          rowIndex * cellHeight + (cellHeight - strHeight) / 2,
          charWidth, charHeight
      );

      selectionRects.add(rect);
    }
    _selectionGeometry.value = SelectionGeometry(status: SelectionStatus.uncollapsed,
        hasContent: true,
        selectionRects: selectionRects,
        startSelectionPoint: ignore,
        endSelectionPoint: ignore);
  }

  @override
  SelectedContent? getSelectedContent() {
    if (!value.hasSelection) return null;
    StringBuffer buf = StringBuffer();
    int low = startIndex;
    int high = endIndex;

    if (low > high) {
      int tmp = low;
      low = high;
      high = tmp;
    }

    for (int i = low; i < high; i++) {
      int textIndex = i ~/ strLength;
      int charIndex = i % strLength;
      String c = texts[textIndex].text![charIndex];
      buf.write(c);
    }
    return SelectedContent(plainText: buf.toString());
  }

  @override
  SelectedContentRange? getSelection() {
    if (!value.hasSelection) return null;
    return SelectedContentRange(startOffset: startIndex, endOffset: endIndex);
  }

  @override
  void pushHandleLayers(LayerLink? startHandle, LayerLink? endHandle) {
  }

  @override
  SelectionGeometry get value {
    return _selectionGeometry.value;
  }
}

class TabToolbar extends StatelessWidget {
  const TabToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(children: [_OverwriteTool(), SizedBox(width: 20), _JumpTool()]);
  }
}

class _OverwriteTool extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    _State state = context.watch();
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: theme.colorScheme.surfaceDim),
      child: DefaultTextStyle(
        style: TextStyle(color: theme.colorScheme.onSurface),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(foregroundColor: theme.colorScheme.onSecondary, backgroundColor: theme.colorScheme.secondary),
                icon: Icon(Icons.save_as),
                onPressed: () async {
                  if (state.from >= state.to) {
                    showDialog(
                      context: context,
                      builder: (c) => AlertDialog(title: Text("invalid value"), content: Text("please input a valid value")),
                    );
                    return;
                  }

                  XFile? rs = await openFile();
                  if (rs == null) {
                    return;
                  }

                  String file = rs.path;
                  Uint8List data = await File(file).readAsBytes();

                  state.overwrite(state.from, state.to, data);
                },
                label: Text("overwrite"),
              ),
              SizedBox(width: 10),
              Text("from 0x"),
              _HexTextField(state.fromController, (v) => v >= 0),
              Text("to 0x"),
              _HexTextField(state.toController, (v) => v >= 0),
            ],
          ),
        ),
      ),
    );
  }
}

class _JumpTool extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    _State state = context.watch();
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: theme.colorScheme.surfaceDim),
      child: DefaultTextStyle(
        style: TextStyle(color: theme.colorScheme.onSurface),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(foregroundColor: theme.colorScheme.onSecondary, backgroundColor: theme.colorScheme.secondary),
                icon: Icon(Icons.directions_run),
                onPressed: () async {
                  if (state.jump >= state.length) {
                    showDialog(
                      context: context,
                      builder: (c) => AlertDialog(title: Text("out of range"), content: Text("please input a valid value")),
                    );
                    return;
                  }

                  state.jumpTo(state.jump);
                },
                label: Text("jump to"),
              ),
              SizedBox(width: 10),
              Text("0x"),
              _HexTextField(state.jumpController, (v) => v >= 0),
            ],
          ),
        ),
      ),
    );
  }
}

class _HexTextField extends StatelessWidget {
  const _HexTextField(this.controller, this.isCorrect);

  final TextEditingController controller;
  final bool Function(int)? isCorrect;

  @override
  Widget build(BuildContext context) {
    if (controller.text.isEmpty) controller.value = TextEditingValue(text: "0");
    DefaultTextStyle textStyle = DefaultTextStyle.of(context);
    return SizedBox(
      width: 200,
      child: Padding(
        padding: const EdgeInsets.only(left: 10, right: 10),
        child: TextField(
          controller: controller,
          style: textStyle.style,
          inputFormatters: [_HexInputFormatter(isCorrect: isCorrect)],
          decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
        ),
      ),
    );
  }
}

class _HexInputFormatter extends TextInputFormatter {
  _HexInputFormatter({this.isCorrect});

  bool Function(int)? isCorrect;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    TextEditingValue rs;
    String text;
    if (newValue.text.isEmpty) {
      rs = newValue;
      text = "0";
    } else {
      try {
        int v = int.parse(newValue.text, radix: 16);
        if (isCorrect != null && !isCorrect!(v)) {
          rs = oldValue;
        } else {
          rs = newValue;
        }
      } catch (e) {
        rs = oldValue;
      }
      text = rs.text.toUpperCase();
    }

    return TextEditingValue(text: text, selection: rs.selection);
  }
}
