import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      cards.add(TodoCardWidget(label: title, state: state, memo: memo));
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

          if (label != null) {
            SharedPreferences prefs = await SharedPreferences.getInstance();
            var todo = prefs.getStringList("todo") ?? [];
            var memo  = await _showTextInputDialogMemo(context);
            if (memo == null) {
              memo = "";
            }
            // 辞書型オブジェクトを生成し、JSON形式の文字列に変換して保存
            var mapObj = {"title": label, "state": false, "memo": memo};
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

  final _textFieldController = TextEditingController();

  Future<String?> _showTextInputDialog(BuildContext context) async {
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

  final _textFieldControllerMemo = TextEditingController();
  Future<String?> _showTextInputDialogMemo(BuildContext context) async {
    return showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('TODO'),
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

}

////////////////////
class TodoCardWidget extends StatefulWidget {
  final String label;
  final String memo;
  // 真偽値（Boolen）型のstateを外部からアクセスできるように修正
  var state = false;

  TodoCardWidget({
    Key? key,
    required this.label,
    required this.state,
    required this.memo,
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
        mapObj["memo"] = widget.memo;
        todo[i] = jsonEncode(mapObj);
      }
    }

    prefs.setStringList("todo", todo);

    /// ------------------------------------
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(10),
      child: Container(
        padding: EdgeInsets.all(10),
        child: Row(
          children: [
            Checkbox(onChanged: _changeState, value: widget.state),
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Text(widget.label),
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
    );
  }
}

