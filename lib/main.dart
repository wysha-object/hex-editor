import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hex_editor/tab.dart';

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
  static const double titleHeight = 100;
  static const double headerHeight = 50;

  int index = 0;
  List<HexTab> tabs = <HexTab>[];

  @override
  Widget build(BuildContext context) {
    List<Widget> tabHeader = [];
    List<Widget> tabBody = [];
    for (var tab in tabs) {
      tabHeader.add(tab.overview);
      tabBody.add(tab.body);
    }
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: titleHeight,
        title: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 30, right: 100),
              child: const Text("Hex Editor"),
            ),
            Expanded(
              child: SizedBox(
                height: titleHeight,
                child: ReorderableListView(
                  scrollDirection: Axis.horizontal,
                  children: tabHeader,
                  onReorder: (o, n) => {
                    setState(() {
                      if (o < n) {
                        n--;
                        if (index > o && index <= n) {
                          index--;
                        } else if (index == o) {
                          index = n;
                        }
                      } else {
                        if (index >= n && index < o) {
                          index++;
                        } else if (index == o) {
                          index = n;
                        }
                      }

                      HexTab hexTab = tabs.removeAt(o);
                      tabs.insert(n, hexTab);
                    }),
                  },
                ),
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(headerHeight),
          child: tabs.length > 0 ? tabs[index].header : Container(),
        ),
      ),
      body: IndexedStack(index: index, children: tabBody),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          children: [
            ElevatedButton.icon(
              onPressed: () async {
                final FilePickerResult? rs = await FilePicker.platform
                    .pickFiles();
                if (rs == null) {
                  return;
                }
                setState(() {
                  for (var file in rs.paths) {
                    if (file == null) continue;

                    bool exist = false;
                    for (var e in tabs) {
                      if (e.path == file) exist = true;
                    }
                    if (exist) continue;

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
                  }
                });
              },
              icon: Icon(Icons.insert_drive_file),
              label: Text("open"),
            ),
          ],
        ),
      ),
    );
  }
}
