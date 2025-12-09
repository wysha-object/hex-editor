import 'dart:math';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:hex_editor/tab.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(const HexEditorApplication());
}

class HexEditorApplication extends StatelessWidget {
  const HexEditorApplication({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Hex Editor",
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        textTheme: TextTheme(
          titleLarge: TextStyle(fontSize: 30, fontFamily: "Impact"),
          titleSmall: TextStyle(fontSize: 20),
          bodyLarge: TextStyle(fontSize: 15),
          bodySmall: TextStyle(fontSize: 12, fontFamily: "Consolas"),
        ),
      ),
      home: const HexEditorRootPage(),
    );
  }
}

class HexEditorRootPage extends StatefulWidget {
  const HexEditorRootPage({super.key});

  @override
  State<HexEditorRootPage> createState() => _HexEditorRootPageState();
}

class _HexEditorRootPageState extends State<HexEditorRootPage> {
  static const double titleHeight = 90;
  static const double headerHeight = 30;
  static const double bottomHeight = 120;

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
        headerList.add(Container(key: ObjectKey(current), child: current.header));
        bodyList.add(Container(key: ObjectKey(current), child: current.body));
        toolbarList.add(Container(key: ObjectKey(current), child: current.toolbar));
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
                  child: ReorderableListView(
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
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      XFile? rs = await openFile();
                      if (rs == null) {
                        return;
                      }

                      var file = rs.path;

                      bool exist = false;
                      for (var e in tabs) {
                        if (e.path == file) exist = true;
                      }

                      if (exist) return;
                      setState(() {
                        HexTab tab = HexTab(
                          headerHeight,
                          file,
                          () {
                            setState(() {
                              for (int i = 0; i < tabs.length; i++) {
                                if (tabs[i].path == file) {
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
                                if (tabs[i].path == file) {
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
                    },
                    icon: Icon(Icons.insert_drive_file),
                    label: Text("open"),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsetsGeometry.all(10),
                    child: IndexedStack(index: index, children: toolbarList),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
            decoration: BoxDecoration(color: theme.colorScheme.secondary, borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Text("Editor", style: TextStyle(color: theme.colorScheme.onSecondary)),
            ),
          ),
        ],
      ),
    );
  }
}
