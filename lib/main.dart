import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
      ),
      home: LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  TextEditingController user = TextEditingController();
  TextEditingController pass = TextEditingController();

  void login() {
    if (user.text == "admin" && pass.text == "1234") {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => HomePage()));
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Wrong ID/Password")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(controller: user, decoration: InputDecoration(labelText: "ID")),
            TextField(controller: pass, decoration: InputDecoration(labelText: "Password")),
            SizedBox(height: 20),
            ElevatedButton(onPressed: login, child: Text("Login"))
          ],
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<String> workers = [];
  Map<String, List<Map<String, String>>> data = {};
  Map<String, double> salaryMap = {};
  Map<String, double> advanceMap = {};

  String? selectedWorker;

  TextEditingController inTime = TextEditingController();
  TextEditingController outTime = TextEditingController();
  TextEditingController newWorker = TextEditingController();
  TextEditingController salary = TextEditingController();
  TextEditingController advance = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('workers', jsonEncode(workers));
    prefs.setString('data', jsonEncode(data));
    prefs.setString('salary', jsonEncode(salaryMap));
    prefs.setString('advance', jsonEncode(advanceMap));
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();

    workers = List<String>.from(jsonDecode(prefs.getString('workers') ?? '[]'));

    data = Map<String, List<Map<String, String>>>.from(
      jsonDecode(prefs.getString('data') ?? '{}').map((key, value) => MapEntry(
          key,
          List<Map<String, String>>.from(
              value.map((e) => Map<String, String>.from(e)))))),
    );

    salaryMap = Map<String, double>.from(
        jsonDecode(prefs.getString('salary') ?? '{}')
            .map((k, v) => MapEntry(k, (v as num).toDouble())));

    advanceMap = Map<String, double>.from(
        jsonDecode(prefs.getString('advance') ?? '{}')
            .map((k, v) => MapEntry(k, (v as num).toDouble())));

    setState(() {});
  }

  Future<void> pickTime(TextEditingController controller) async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      controller.text = picked.format(context);
    }
  }

  void addWorker() {
    if (newWorker.text.isEmpty || workers.contains(newWorker.text)) return;

    setState(() {
      workers.add(newWorker.text);
      data[newWorker.text] = [];
      salaryMap[newWorker.text] = double.tryParse(salary.text) ?? 0;
      advanceMap[newWorker.text] = double.tryParse(advance.text) ?? 0;
    });

    saveData();
    newWorker.clear();
    salary.clear();
    advance.clear();
  }

  void deleteWorker() {
    if (selectedWorker == null) return;

    setState(() {
      workers.remove(selectedWorker);
      data.remove(selectedWorker);
      salaryMap.remove(selectedWorker);
      advanceMap.remove(selectedWorker);
      selectedWorker = null;
    });

    saveData();
  }

  void submit() {
    if (selectedWorker == null || inTime.text.isEmpty || outTime.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Fill all fields")));
      return;
    }

    data[selectedWorker]!.add({
      "date": DateTime.now().toString().split(' ')[0],
      "in": inTime.text,
      "out": outTime.text
    });

    saveData();

    inTime.clear();
    outTime.clear();

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text("Saved Successfully")));
  }

  double calculateSalary(String worker) {
    int days = data[worker]?.length ?? 0;
    double perDay = (salaryMap[worker] ?? 0) / 30;
    double total = perDay * days;
    double advance = advanceMap[worker] ?? 0;
    return total - advance;
  }

  Future<void> downloadExcel() async {
    final dir = await getExternalStorageDirectory();

    for (var worker in workers) {
      String csv = "Date,In,Out\n";
      for (var row in data[worker] ?? []) {
        csv += "${row['date']},${row['in']},${row['out']}\n";
      }

      double finalSalary = calculateSalary(worker);
      csv += "\nFinal Salary:,$finalSalary";

      final file = File("${dir!.path}/$worker.csv");
      await file.writeAsString(csv);
    }

    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Excel with salary saved")));
  }

  void clearForm() {
    inTime.clear();
    outTime.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("RS"),
        backgroundColor: Colors.grey[900],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: selectedWorker,
              hint: Text("Select Worker"),
              items: workers
                  .map((w) => DropdownMenuItem(value: w, child: Text(w)))
                  .toList(),
              onChanged: (val) {
                setState(() {
                  selectedWorker = val;
                });
              },
            ),
            SizedBox(height: 10),
            TextField(
              controller: inTime,
              readOnly: true,
              onTap: () => pickTime(inTime),
              decoration: InputDecoration(labelText: "In Time"),
            ),
            TextField(
              controller: outTime,
              readOnly: true,
              onTap: () => pickTime(outTime),
              decoration: InputDecoration(labelText: "Out Time"),
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: submit,
                    child: Text("Submit"),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: clearForm,
                    child: Text("Clear"),
                  ),
                ),
              ],
            ),
            Divider(height: 30),
            TextField(controller: newWorker, decoration: InputDecoration(labelText: "Worker Name")),
            TextField(controller: salary, decoration: InputDecoration(labelText: "Salary"), keyboardType: TextInputType.number),
            TextField(controller: advance, decoration: InputDecoration(labelText: "Advance"), keyboardType: TextInputType.number),
            ElevatedButton(onPressed: addWorker, child: Text("Add Worker")),
            ElevatedButton(onPressed: deleteWorker, child: Text("Delete Worker")),
            if (selectedWorker != null)
              Text("Final Salary: ₹${calculateSalary(selectedWorker!).toStringAsFixed(2)}"),
            ElevatedButton(onPressed: downloadExcel, child: Text("Download Excel")),
          ],
        ),
      ),
    );
  }
}
