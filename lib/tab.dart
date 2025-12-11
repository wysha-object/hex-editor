import 'dart:io';
import 'dart:math';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hex_editor/editor.dart';
import 'package:provider/provider.dart';

const int baseColCount = 32;
const double rowHeight = 30;
const double indexGridWidth = 130;
const double baseDataGridWidth = 800;
const double baseCharGridWidth = 320;
const double paddingBetweenDataChar = 50;

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
  _State(this._editor);

  double _offset = 0;

  ScrollController get scrollController {
    ScrollController scrollController = ScrollController(initialScrollOffset: _offset);
    scrollController.addListener(() {
      _offset = scrollController.offset;
    });
    return scrollController;
  }

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
                  Container(
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)),
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SelectableText(style: theme.textTheme.titleMedium, title),
                          SelectableText(style: theme.textTheme.titleSmall, "${state.length} Bytes"),
                        ],
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

    int factor = state.factor;
    int colCount = state.colCount;
    double dataGridWidth = state.dataGridWidth;
    double dataGridColWidth = state.dataGridCellWidth;
    double charGridWidth = state.charGridWidth;

    BorderSide borderSide = _gridBorderSide(theme);

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
                  state.factor = factor == 1 ? 2 : 1;
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
  const TabBody({super.key});

  @override
  Widget build(BuildContext context) {
    DefaultTextStyle defaultTextStyle = DefaultTextStyle.of(context);
    _State state = context.watch<_State>();

    ScrollController scrollController = state.scrollController;
    int length = state.length;
    int rowCount = state.rowCount;
    int colCount = state.colCount;

    return DefaultTextStyle(
      style: defaultTextStyle.style,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: Scrollbar(
          controller: scrollController,
          child: GridView.builder(
            controller: scrollController,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 1, mainAxisExtent: rowHeight),
            itemCount: rowCount,
            itemBuilder: (context, index) {
              int start = index * colCount;
              Uint8List data = state.read(start, min(length - start, colCount));

              return _RowBlock(data, index);
            },
          ),
        ),
      ),
    );
  }
}

class _RowBlock extends StatelessWidget {
  const _RowBlock(this.data, this.index);

  final Uint8List data;

  /// index of the _RowBlock
  final int index;

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    _State state = context.watch<_State>();

    int colCount = state.colCount;
    double dataGridWidth = state.dataGridWidth;
    double dataGridColWidth = state.dataGridCellWidth;
    double charGridWidth = state.charGridWidth;
    double charGridColWidth = state.charGridCellWidth;

    BorderSide borderSide = _gridBorderSide(theme);

    int numOfBytes = index * colCount;
    String text = numOfBytes.toRadixString(16).toUpperCase();
    text = "0x$text";

    List<String> dataCells = [];
    List<String> charCells = [];
    for (int b in data) {
      String hex = b.toRadixString(16).toLowerCase();
      hex = hex.padLeft(2, "0");
      dataCells.add(hex);
      charCells.add(String.fromCharCode(b));
    }

    double height = rowHeight;

    return PreferredSize(
      preferredSize: Size.fromHeight(height),
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          height: height,
          child: Row(
            children: [
              Expanded(child: Container(color: Colors.transparent)),
              SizedBox(
                width: indexGridWidth,
                height: height,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(right: borderSide, bottom: borderSide, left: borderSide),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(text, textAlign: TextAlign.left),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: dataGridWidth,
                height: height,
                child: _Block(dataGridColWidth, rowHeight, Border(right: borderSide, bottom: borderSide), dataCells),
              ),
              SizedBox(
                width: paddingBetweenDataChar,
                height: height,
                child: Container(color: Colors.transparent),
              ),
              SizedBox(width: charGridWidth, height: height, child: _Block(charGridColWidth, rowHeight, Border(), charCells)),
              Expanded(child: Container(color: Colors.transparent)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block(this.colWidth, this.rowHeight, this.itemBorder, this.data);

  final double colWidth;
  final double rowHeight;
  final Border itemBorder;

  final List<String> data;

  @override
  Widget build(BuildContext context) {
    int colCount = data.length;

    ThemeData theme = Theme.of(context);
    DefaultTextStyle textStyle = DefaultTextStyle.of(context);

    List<String> cells = [];
    for (int i = 0; i < colCount; i++) {
      String item;
      item = data[i];
      cells.add(item);
    }

    return CustomPaint(painter: _BlockPainter(theme, colWidth, rowHeight, itemBorder, cells, textStyle.style));
  }
}

class _BlockPainter extends CustomPainter {
  _BlockPainter(this.theme, this.colWidth, this.rowHeight, this.cellBorder, this.texts, this.textStyle);

  final ThemeData theme;

  final double colWidth;
  final double rowHeight;
  final Border cellBorder;

  final List<String> texts;
  final TextStyle textStyle;

  @override
  void paint(Canvas canvas, Size size) {
    var offset = Offset(0, 0);
    for (String item in texts) {
      paintCell(canvas, size, item, offset);
      offset = offset.translate(colWidth, 0);
    }
  }

  void paintCell(Canvas canvas, Size size, String item, Offset offset) {
    TextPainter textPaint = TextPainter(
      text: TextSpan(text: item, style: textStyle),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    textPaint.layout(minWidth: colWidth, maxWidth: colWidth);
    textPaint.paint(canvas, offset.translate(0, (rowHeight - textPaint.height) / 2));

    drawBorderSide(canvas, cellBorder.top, offset.dx, offset.dy, colWidth, cellBorder.top.width);
    drawBorderSide(canvas, cellBorder.right, offset.dx + colWidth - cellBorder.right.width, offset.dy, cellBorder.right.width, rowHeight);
    drawBorderSide(canvas, cellBorder.bottom, offset.dx, offset.dy + rowHeight - cellBorder.bottom.width, colWidth, cellBorder.bottom.width);
    drawBorderSide(canvas, cellBorder.left, offset.dx, offset.dy, cellBorder.left.width, rowHeight);
  }

  void drawBorderSide(Canvas canvas, BorderSide side, double left, double top, double width, double height) {
    Paint paint = Paint()..color = side.color;
    Rect rect = Rect.fromLTWH(left, top, width, height);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return this != oldDelegate;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _BlockPainter &&
          runtimeType == other.runtimeType &&
          colWidth == other.colWidth &&
          rowHeight == other.rowHeight &&
          cellBorder == other.cellBorder &&
          texts == other.texts &&
          textStyle == other.textStyle;

  @override
  int get hashCode => Object.hash(colWidth, rowHeight, cellBorder, texts, textStyle);
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
