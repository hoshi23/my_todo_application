import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:location/location.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

///////////////////////////////
void main() => runApp(MyApp());

///////////////////////////////
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(theme: ThemeData(), home: MyHomePage());
  }
}

///////////////////////////////
class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  @override
  void initState() {
    super.initState();
  }

  /// ---- ① 非同期にカードリストを生成する関数 ----
  Future<List<dynamic>> getCards() async {
    var prefs = await SharedPreferences.getInstance();
    List<Widget> cards = [];
    var todo = prefs.getStringList("todo") ?? [];
    for (var jsonStr in todo) {
      // JSON形式の文字列から辞書形式のオブジェクトに変換し、各要素を取り出し
      var mapObj = jsonDecode(jsonStr);
      var title = mapObj['title'];
      var state = mapObj['state'];
      var memo = mapObj['memo'];
      var latitude = mapObj['latitude'];
      var longitude = mapObj['longitude'];
      bool isLocation = false;
      if (latitude != null && longitude != null) {
        isLocation = true;
      }
      cards.add(TodoCardWidget(label: title, state: state, memo: memo, latitude: latitude, longitude: longitude, isLocation: isLocation));
    }
    return cards;
  }

  /// ------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My TODO"),
        actions: [
          IconButton(
              onPressed: () {
                SharedPreferences.getInstance().then((prefs) async {
                  await prefs.setStringList("todo", []);
                  setState(() {});
                });
              },
              icon: const Icon(Icons.delete))
        ],
      ),
      body: Center(
        /// ---- ② 非同期にカードリストを更新するには、FutureBuilder を使います----
        child: FutureBuilder<List>(
          future: getCards(), // <--- getCards()メソッドの実行状態をモニタリングする
          builder: (BuildContext context, AsyncSnapshot<List> snapshot) {
            switch (snapshot.connectionState) {
              case ConnectionState.none:
                return const Text('Waiting to start');
              case ConnectionState.waiting:
                return const Text('Loading...');
              default:
              // getCards()メソッドの処理が完了すると、ここが呼ばれる。
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                } else {
                  return ListView.builder(
                    // リストの中身は、snapshot.dataの中に保存されているので、
                    // 取り出して活用する
                      itemCount: snapshot.data!.length,
                      itemBuilder: (BuildContext context, int index) {
                        return snapshot.data![index];
                      });
                }
            }
          },
        ),

        /// ------------------------------------
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          var label = await _showTextInputDialog(context);
          if (label != null && label != "") {
            SharedPreferences prefs = await SharedPreferences.getInstance();
            var todo = prefs.getStringList("todo") ?? [];
            var memo  = await _showTextInputDialogMemo(context);
            if (memo == null) {
              memo = "";
            }
            var map = await _showTextInputDialogMap(context);
            debugPrint("finish map");
            bool isLocation = false;
            var latitude = null;
            var longitude = null;
            if (map != null) {
              isLocation = true;
              latitude = map.latitude;
              longitude = map.longitude;
            }
            // 辞書型オブジェクトを生成し、JSON形式の文字列に変換して保存
            var mapObj = {"title": label, "state": false, "memo": memo, "latitude": latitude, "longitude": longitude, "isLocation": isLocation};
            var jsonStr = jsonEncode(mapObj);
            todo.add(jsonStr);
            await prefs.setStringList("todo", todo);

            setState(() {});
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<String?> _showTextInputDialog(BuildContext context) async {
    final _textFieldController = TextEditingController();
    return showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('TODO'),
            content:
                TextField(
                  controller: _textFieldController,
                  decoration: const InputDecoration(hintText: "タスクの名称を入力してください。"),
                ),
            actions: <Widget>[
              ElevatedButton(
                child: const Text("キャンセル"),
                onPressed: () => Navigator.pop(context),
              ),
              ElevatedButton(
                child: const Text('OK'),
                onPressed: () =>
                    Navigator.pop(context, _textFieldController.text),
              ),
            ],
          );
        });
  }

  Future<String?> _showTextInputDialogMemo(BuildContext context) async {
    final _textFieldControllerMemo = TextEditingController();
    return showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('詳細'),
            content:
            TextField(
              controller: _textFieldControllerMemo,
              decoration: const InputDecoration(hintText: "タスクの内容を入力してください。"),
            ),
            actions: <Widget>[
              ElevatedButton(
                child: const Text("キャンセル"),
                onPressed: () => Navigator.pop(context),
              ),
              ElevatedButton(
                child: const Text('OK'),
                onPressed: () =>
                    Navigator.pop(context, _textFieldControllerMemo.text),
              ),
            ],
          );
        });
  }

  Future<LocationData?> _showTextInputDialogMap(BuildContext context) async {
    debugPrint("Map");
    Location location = new Location();

    bool _serviceEnabled;
    PermissionStatus _permissionGranted;
    LocationData _locationData;

    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) {
            () => Navigator.pop(context);
      }
    }

    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
            () => Navigator.pop(context);
      }
    }
    debugPrint("getlocation");
    _locationData = await location.getLocation();
    debugPrint("finish getlocation");
    return showDialog(
        context: context,
        builder: (context) {
          debugPrint("in return ");
          return AlertDialog(
            title: const Text('位置情報を追加'),
            content: Scaffold(
              body: Center(
                child: FlutterMap(
                  options: MapOptions(
                      center: (_locationData != null)
                          ? LatLng(_locationData.latitude!, _locationData.longitude!)
                          : LatLng(0, 0),
                      zoom: 18.0),
                  layers: [
                    TileLayerOptions(
                      urlTemplate:
                      "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                      subdomains: ['a', 'b', 'c'],
                      attributionBuilder: (_) =>
                      const Text("© OpenStreetMap contributors"),
                    ),
                    MarkerLayerOptions(markers: [
                      Marker(
                        width: 80.0,
                        height: 80.0,
                        point: (_locationData != null)
                            ? LatLng(_locationData.latitude!, _locationData.longitude!)
                            : LatLng(0, 0),
                        builder: (ctx) => const Icon(Icons.location_pin),
                      )
                    ]),
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              ElevatedButton(
                child: const Text("追加しない"),
                onPressed: () => Navigator.pop(context),
              ),
              ElevatedButton(
                child: const Text('追加'),
                onPressed: () =>
                    Navigator.pop(context, _locationData),
              ),
            ],
          );
        });
  }

}


////////////////////
class TodoCardWidget extends StatefulWidget {
  final String label;
  String memo;
  // 真偽値（Boolen）型のstateを外部からアクセスできるように修正
  var state = false;
  bool isVisible = true;
  var latitude = null;
  var longitude = null;
  bool isLocation = false;

  TodoCardWidget({
    Key? key,
    required this.label,
    required this.state,
    required this.memo,
    required this.latitude,
    required this.longitude,
    required this.isLocation,
  }) : super(key: key);

  @override
  _TodoCardWidgetState createState() => _TodoCardWidgetState();
}

class _TodoCardWidgetState extends State<TodoCardWidget> {
  void _changeState(value) async {
    setState(() {
      widget.state = value ?? false;
    });

    // --- ③ ボタンが押されたタイミング状態を更新し保存する ---
    SharedPreferences prefs = await SharedPreferences.getInstance();
    var todo = prefs.getStringList("todo") ?? [];

    for (int i = 0; i < todo.length; i++) {
      var mapObj = jsonDecode(todo[i]);
      if (mapObj["title"] == widget.label) {
        mapObj["state"] = widget.state;
        todo[i] = jsonEncode(mapObj);
      }
    }

    prefs.setStringList("todo", todo);

    /// ------------------------------------
  }

  Future<String?> _changeTextInputDialogMemo(BuildContext context, String before) async {
    final _textFieldControllerMemo = TextEditingController(text: before);
    return showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('詳細の更新'),
            content:
            TextField(
              controller: _textFieldControllerMemo,
              decoration: const InputDecoration(hintText: "タスクの内容を入力してください。"),

            ),
            actions: <Widget>[
              ElevatedButton(
                child: const Text("キャンセル"),
                onPressed: () => Navigator.pop(context, before),
              ),
              ElevatedButton(
                child: const Text('OK'),
                onPressed: () =>
                    Navigator.pop(context, _textFieldControllerMemo.text),
              ),
            ],
          );
        });
  }

  Future<LocationData?> _showTextInputDialogMap(BuildContext context, var latitude, var longitude) async {
    return showDialog(
        context: context,
        builder: (context) {
          debugPrint("in return ");
          return AlertDialog(
            title: const Text('位置情報'),
            content: Scaffold(
              body: Center(
                child: FlutterMap(
                  options: MapOptions(
                      center: (latitude != null && longitude != null)
                          ? LatLng(latitude!, longitude!)
                          : LatLng(0, 0),
                      zoom: 18.0),
                  layers: [
                    TileLayerOptions(
                      urlTemplate:
                      "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                      subdomains: ['a', 'b', 'c'],
                      attributionBuilder: (_) =>
                      const Text("© OpenStreetMap contributors"),
                    ),
                    MarkerLayerOptions(markers: [
                      Marker(
                        width: 80.0,
                        height: 80.0,
                        point: (latitude != null && longitude != null)
                            ? LatLng(latitude!, longitude!)
                            : LatLng(0, 0),
                        builder: (ctx) => const Icon(Icons.location_pin),
                      )
                    ]),
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              ElevatedButton(
                child: const Text("変更"),
                onPressed: () async {
                  var locationData = await _changeTextInputDialogMap(context);
                  Navigator.pop(context, locationData);
                },
              ),
              ElevatedButton(
                child: const Text("OK"),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          );
        });
  }

  Future<LocationData?> _showTextInputNoMap(BuildContext context) async {
    return showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('位置情報'),
            content:
              const Text("位置情報は追加されていません"),
            actions: <Widget>[
              ElevatedButton(
                child: const Text("変更"),
                onPressed: () async {
                  var locationData = await _changeTextInputDialogMap(context);
                  Navigator.pop(context, locationData);
                },
              ),
              ElevatedButton(
                child: const Text("OK"),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          );
        });
  }
  Future<LocationData?> _changeTextInputDialogMap(BuildContext context) async {
    debugPrint("Map");
    Location location = new Location();

    bool _serviceEnabled;
    PermissionStatus _permissionGranted;
    LocationData _locationData;

    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) {
            () => Navigator.pop(context);
      }
    }

    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
            () => Navigator.pop(context);
      }
    }
    debugPrint("getlocation");
    _locationData = await location.getLocation();
    debugPrint("finish getlocation");
    return showDialog(
        context: context,
        builder: (context) {
          debugPrint("in return ");
          return AlertDialog(
            title: const Text('位置情報を変更'),
            content: Scaffold(
              body: Center(
                child: FlutterMap(
                  options: MapOptions(
                      center: (_locationData != null)
                          ? LatLng(_locationData.latitude!, _locationData.longitude!)
                          : LatLng(0, 0),
                      zoom: 18.0),
                  layers: [
                    TileLayerOptions(
                      urlTemplate:
                      "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                      subdomains: ['a', 'b', 'c'],
                      attributionBuilder: (_) =>
                      const Text("© OpenStreetMap contributors"),
                    ),
                    MarkerLayerOptions(markers: [
                      Marker(
                        width: 80.0,
                        height: 80.0,
                        point: (_locationData != null)
                            ? LatLng(_locationData.latitude!, _locationData.longitude!)
                            : LatLng(0, 0),
                        builder: (ctx) => const Icon(Icons.location_pin),
                      )
                    ]),
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              ElevatedButton(
                child: const Text("キャンセル"),
                onPressed: () => Navigator.pop(context),
              ),
              ElevatedButton(
                child: const Text('変更'),
                onPressed: () =>
                    Navigator.pop(context, _locationData),
              ),
            ],
          );
        });
  }


  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(10),
      child: Visibility(
        visible: widget.isVisible,
        child: Container(
          padding: EdgeInsets.all(10),
          child: Row(
            children: [
              Checkbox(onChanged: _changeState, value: widget.state),
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(widget.label),
                      Row(
                          children: <Widget>[
                            IconButton(
                              iconSize: 20,
                              color: HexColor('000080'),
                              onPressed: () {
                                SharedPreferences.getInstance().then((prefs) async {
                                  var todo = prefs.getStringList("todo") ?? [];
                                  var len_todo = todo.length;
                                  var new_memo = await _changeTextInputDialogMemo(context, widget.memo);
                                  if (new_memo == null) {
                                    new_memo = "";
                                  }
                                  widget.memo = new_memo;
                                  for (int i = 0; i < len_todo; i++) {
                                    var mapObj = jsonDecode(todo[i]);
                                    if (mapObj["title"] == widget.label) {
                                      mapObj["memo"] = new_memo;
                                      break;
                                    }
                                  }
                                  await prefs.setStringList("todo", todo);
                                  setState(() {});
                                });
                              },
                              icon: Icon(Icons.create_outlined),
                            ),
                            IconButton(
                              iconSize: 20,
                              color: Colors.green,
                              onPressed: () {
                                SharedPreferences.getInstance().then((prefs) async {
                                  var locationData = null;
                                  var todo = prefs.getStringList("todo") ?? [];
                                  var len_todo = todo.length;
                                  for (int i = 0; i < len_todo; i++) {
                                    var mapObj = jsonDecode(todo[i]);
                                    if (mapObj["title"] == widget.label) {
                                      if (mapObj["isLocation"]) {
                                        locationData = await _showTextInputDialogMap(context, mapObj["latitude"], mapObj["longitude"]);
                                      }
                                      else {
                                        locationData = await _showTextInputNoMap(context);
                                      }
                                      if (locationData != null) {
                                        mapObj["latitude"] = locationData.latitude;
                                        mapObj["longitude"] = locationData.longitude;
                                        await prefs.setStringList("todo", todo);
                                      }
                                      break;
                                    }
                                  }
                                  setState(() {});
                                });
                              },
                              icon: Icon(Icons.location_on_outlined),
                            ),
                            IconButton(
                              iconSize: 20,
                              color: Colors.red,
                              onPressed: () {
                                SharedPreferences.getInstance().then((prefs) async {
                                  var todo = prefs.getStringList("todo") ?? [];
                                  var len_todo = todo.length;
                                  widget.isVisible = false;
                                  for (int i = 0; i < len_todo; i++) {
                                    var mapObj = jsonDecode(todo[i]);
                                    if (mapObj["title"] == widget.label) {
                                      todo.remove(todo[i]);
                                      break;
                                    }
                                  }
                                  await prefs.setStringList("todo", todo);
                                  setState(() {});
                                });
                              },
                              icon: Icon(Icons.disabled_by_default_outlined),
                            ),
                        ],),
                    ],
                  ),
                  Text(widget.memo,
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HexColor extends Color {
  static int _getColorFromHex(String hexColor) {
    hexColor = hexColor.toUpperCase().replaceAll('#', '');
    if (hexColor.length == 6) {
      hexColor = 'FF' + hexColor;
    }
    return int.parse(hexColor, radix: 16);
  }

  HexColor(final String hexColor) : super(_getColorFromHex(hexColor));
}

