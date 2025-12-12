import 'dart:math';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:hex_editor/tab.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(const HexEditorNotifierProvider());
}

class HexEditorNotifierProvider extends StatelessWidget {
  const HexEditorNotifierProvider({super.key});

  @override
  Widget build(BuildContext context) {
    bool defaultIsDarkMode = WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    return ChangeNotifierProvider(create: (context) => AppState(defaultIsDarkMode), child: const HexEditorThemeProvider());
  }
}

class AppState extends ChangeNotifier {
  AppState(this._isDarkMode);

  bool _isDarkMode;

  bool get isDarkMode => _isDarkMode;

  set isDarkMode(bool value) {
    _isDarkMode = value;
    notifyListeners();
  }
}

class HexEditorThemeProvider extends StatelessWidget {
  const HexEditorThemeProvider({super.key});

  @override
  Widget build(BuildContext context) {
    AppState appState = Provider.of<AppState>(context);

    return MaterialApp(
      title: "Hex Editor",
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: appState.isDarkMode ? Brightness.dark : Brightness.light),
        textTheme: TextTheme(
          titleLarge: TextStyle(fontFamily: "Impact"),
          bodySmall: TextStyle(fontFamily: "Consolas"),
        ),
      ),
      home: HexEditorRoot(),
    );
  }
}

class HexEditorRoot extends StatefulWidget {
  const HexEditorRoot({super.key});

  @override
  State<HexEditorRoot> createState() => _HexEditorRootState();
}

class _HexEditorRootState extends State<HexEditorRoot> {
  static const double titleHeight = 100;
  static const double headerHeight = 30;
  static const double bottomHeight = 120;

  final ScrollController _scrollController = ScrollController();

  int _index = 0;

  int get index => _index;

  set index(int value) {
    _index = value;
    if (value >= 0 && value < tabs.length) {
      tabBarState.current = tabs[value];
    }
  }

  final HexTabState tabBarState = HexTabState();

  List<HexTab> tabs = <HexTab>[];

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);

    List<Widget> overviewList = [];
    List<Widget> headerList = [];
    List<Widget> bodyList = [];
    List<Widget> toolbarList = [];
    if (tabs.isNotEmpty) {
      HexTab current = tabs[index];
      for (var tab in tabs) {
        overviewList.add(ChangeNotifierProvider.value(key: ObjectKey(tab), value: tabBarState, child: tab.overview));
        headerList.add(Container(key: ObjectKey(current), child: tab.header));
        bodyList.add(Container(key: ObjectKey(current), child: tab.body));
        toolbarList.add(Container(key: ObjectKey(current), child: tab.toolbar));
      }
    }

    return ChangeNotifierProvider.value(
      value: tabBarState,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: titleHeight,
          title: Row(
            children: [
              Padding(padding: const EdgeInsets.only(left: 30, right: 90), child: const Logo()),
              Expanded(
                child: SizedBox(
                  height: titleHeight,
                  child: Scrollbar(
                    controller: _scrollController,
                    child: ReorderableListView(
                      scrollController: _scrollController,
                      scrollDirection: Axis.horizontal,
                      children: overviewList,
                      onReorder: (o, n) => {
                        setState(() {
                          int tmp = index;
                          if (o < n) {
                            n--;
                            if (tmp > o && tmp <= n) {
                              tmp--;
                            } else if (tmp == o) {
                              tmp = n;
                            }
                          } else {
                            if (tmp >= n && tmp < o) {
                              tmp++;
                            } else if (tmp == o) {
                              tmp = n;
                            }
                          }

                          HexTab hexTab = tabs.removeAt(o);
                          tabs.insert(n, hexTab);

                          index = tmp;
                        }),
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(headerHeight),
            child: DefaultTextStyle(
              style: theme.textTheme.bodySmall!,
              child: IndexedStack(index: index, children: headerList),
            ),
          ),
        ),
        body: DefaultTextStyle(
          style: theme.textTheme.bodySmall!,
          child: IndexedStack(index: index, children: bodyList),
        ),
        bottomNavigationBar: BottomAppBar(
          height: bottomHeight,
          child: DefaultTextStyle(
            style: theme.textTheme.bodyLarge!,
            child: Row(
              children: [
                OpenTool(isFileNotAlreadyOpen, useFile),
                Expanded(
                  child: Padding(
                    padding: EdgeInsetsGeometry.all(10),
                    child: IndexedStack(index: index, children: toolbarList),
                  ),
                ),
                SwitchTool(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool isFileNotAlreadyOpen(String path) {
    bool notAlreadyOpen = true;
    for (var e in tabs) {
      if (e.path == path) notAlreadyOpen = false;
    }
    return notAlreadyOpen;
  }

  void useFile(String path) {
    setState(() {
      HexTab tab = HexTab(
        headerHeight,
        path,
        () {
          setState(() {
            for (int i = 0; i < tabs.length; i++) {
              if (tabs[i].path == path) {
                index = i;
                break;
              }
            }
          });
        },
        () {
          setState(() {
            int? tmp;
            for (int i = 0; i < tabs.length; i++) {
              if (tabs[i].path == path) {
                tmp = i;
                break;
              }
            }
            if (tmp == null) return;

            tabs.removeAt(tmp);
            if (index > tmp) {
              index--;
            } else if (index == tmp) {
              index = max(0, index - 1);
            }
          });
        },
      );
      tabs.add(tab);
      index = tabs.length - 1;
    });
  }
}

class OpenTool extends StatelessWidget {
  const OpenTool(this.isCorrect, this.useFile, {super.key});

  final bool Function(String) isCorrect;
  final void Function(String) useFile;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: ElevatedButton.icon(onPressed: openNewFile, icon: Icon(Icons.insert_drive_file), label: Text("open")),
    );
  }

  void openNewFile() async {
    XFile? rs = await openFile();
    if (rs == null) {
      return;
    }

    var file = rs.path;
    if (isCorrect(file)) useFile(file);
  }
}

class SwitchTool extends StatelessWidget {
  const SwitchTool({super.key});

  @override
  Widget build(BuildContext context) {
    AppState appState = context.watch<AppState>();
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Switch(value: appState.isDarkMode, onChanged: (v) => appState.isDarkMode = v),
    );
  }
}

class Logo extends StatelessWidget {
  const Logo({super.key});

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(5),
      child: Row(
        children: [
          Text("Hex"),
          SizedBox(width: 15),
          Container(
            decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Text("Editor", style: TextStyle(color: theme.colorScheme.onPrimary)),
            ),
          ),
        ],
      ),
    );
  }
}
