import 'dart:io';
import 'dart:math';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/gestures.dart';
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

    double dataGridWidth = state.dataGridWidth;
    double dataGridColWidth = state.dataGridCellWidth;
    double charGridWidth = state.charGridWidth;
    double charGridColWidth = state.charGridCellWidth;

    BorderSide borderSide = _gridBorderSide(theme);

    ScrollController indexScrollController = state.indexScrollController;
    ScrollController dataScrollController = state.dataScrollController;
    ScrollController charScrollController = state.charScrollController;

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
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 1, childAspectRatio: indexGridWidth / rowHeight),
                  itemCount: rowCount,
                  itemBuilder: (context, index) {
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
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 1, childAspectRatio: dataGridWidth / rowHeight),
                    itemCount: rowCount,
                    itemBuilder: (context, index) {
                      index = index * colCount;
                      Uint8List bytes = state.read(index, min(colCount, length - index));
                      return _Block(
                        bytes: bytes,
                        textBuilder: (byte) => byte.toRadixString(16).padLeft(2, "0"),
                        border: Border(right: borderSide, bottom: borderSide),
                        cellWidth: dataGridColWidth,
                        cellHeight: rowHeight,
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
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 1, childAspectRatio: charGridWidth / rowHeight),
                    itemCount: rowCount,
                    itemBuilder: (context, index) {
                      index = index * colCount;
                      Uint8List bytes = state.read(index, min(colCount, length - index));
                      return _Block(bytes: bytes, textBuilder: (byte) => String.fromCharCode(byte), border: Border(), cellWidth: charGridColWidth, cellHeight: rowHeight);
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
  const _Block({required this.bytes, required this.textBuilder, required this.border, required this.cellWidth, required this.cellHeight});

  final Uint8List bytes;
  final String Function(int byte) textBuilder;

  final Border border;

  final double cellWidth;
  final double cellHeight;

  @override
  Widget build(BuildContext context) {
    List<Widget> children = [];
    for (int i = 0; i < bytes.length; i++) {
      children.add(
        SizedBox(
          width: cellWidth,
          height: cellHeight,
          child: Container(
            decoration: BoxDecoration(border: border),
            child: Center(child: Text(textBuilder(bytes[i]))),
          ),
        ),
      );
    }
    return Row(children: children);
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
