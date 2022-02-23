import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:geiger_api/geiger_api.dart';
import 'geiger_api_connector/geiger_api_connector.dart';
import 'geiger_api_connector/sensor_node_model.dart';
import 'services/geiger_listeners.dart';

GeigerApiConnector masterApiConnector =
    GeigerApiConnector(pluginId: GeigerApi.masterId);

Future<bool> initMasterPlugin() async {
  final bool initGeigerAPI = await masterApiConnector.connectToGeigerAPI();
  if (initGeigerAPI == false) return false;
  bool initLocalStorage =
      await masterApiConnector.connectToLocalStorage();
  if (initLocalStorage == false) return false;
 
    // Prepare some data roots
    initLocalStorage = await masterApiConnector.prepareRoot([
      'Chatbot',
      'sensors',
      GeigerApi.masterId,
    ], '');
    if (initLocalStorage == false) return false;


  final bool registerListener = await masterApiConnector.registerListener();
  if (registerListener == false) return false;
  masterApiConnector.addMessagehandler(MessageType.registerMenu, addMenuItem);
  return registerListener;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initMasterPlugin();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    log('Start building the application');
    return const MaterialApp(
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

const String pluginId = GeigerApi.masterId;

class _MyHomePageState extends State<MyHomePage> {
  List<Message> events = [];
  String errorMessage = '';
  String userData = '';
  String deviceData = '';
  List<MenuItem> menuList = [];
  bool isInProcessing = false;

  SensorDataModel userNodeDataModel = SensorDataModel(
      sensorId: 'mi-cyberrange-score-sensor-id',
      name: 'MI Cyberrange Score',
      minValue: '0',
      maxValue: '100',
      valueType: 'double',
      flag: '1',
      threatsImpact:
          '80efffaf-98a1-4e0a-8f5e-gr89388352ph,High;80efffaf-98a1-4e0a-8f5e-gr89388354sp,Hight;80efffaf-98a1-4e0a-8f5e-th89388365it,Hight;80efffaf-98a1-4e0a-8f5e-gr89388350ma,Medium;80efffaf-98a1-4e0a-8f5e-gr89388356db,Medium');
  SensorDataModel deviceNodeDataModel = SensorDataModel(
      sensorId: 'mi-ksp-scanner-is-rooted-device',
      name: 'Is device rooted',
      minValue: 'false',
      maxValue: 'true',
      valueType: 'boolean',
      flag: '0',
      threatsImpact:
          '80efffaf-98a1-4e0a-8f5e-gr89388352ph,High;80efffaf-98a1-4e0a-8f5e-gr89388354sp,Hight;80efffaf-98a1-4e0a-8f5e-th89388365it,Hight;80efffaf-98a1-4e0a-8f5e-gr89388350ma,Medium;80efffaf-98a1-4e0a-8f5e-gr89388356db,Medium');

  _showSnackBar(String message) {
    SnackBar snackBar = SnackBar(
      content: Text(message),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Geiger Dummy Toolbox"),
      ),
      body: isInProcessing == true
          ? const Center(
              child: CircularProgressIndicator(
                backgroundColor: Colors.orange,
              ),
            )
          : Container(
              margin: const EdgeInsets.all(20),
              child: Column(
                children: [



                  const Divider(),
                  const SizedBox(height: 10),
                  const Text('Geiger Dummy Toolbox'),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () async {
                      List<MenuItem> menus =
                          await masterApiConnector.getMenueItems();
                      setState(() {
                        menuList = menus;
                      });
                    },
                    child: const Text('Get menu'),
                  ),
                  Expanded(
                      child: SizedBox(
                          child: ListView.builder(
                              itemCount: menuList.length,
                              itemBuilder: (context, index) {
                                return ElevatedButton(
                                  onPressed: () async {
                                    masterApiConnector
                                        .menuPressed(menuList[index].action);
                                  },
                                  child: Text(menuList[index].menu),
                                );
                              }))),

                  ElevatedButton(
                    onPressed: () async {
                      // trigger/send a STORAGE_EVENT event
                      setState(() {
                        isInProcessing = true;
                      });
                      final bool sentData = await masterApiConnector
                          .sendDataNode(
                              ':Chatbot:sensors:$pluginId:my-sensor-data', [
                        'category',
                        'isSubmitted',
                        'threatInfo'
                      ], [
                        'Malware',
                        'false',
                        jsonEncode({
                          'fileFullPath': 'Some/pathto/somthis.apk',
                          'objectName': 'somthing.apk',
                          'packageName': 'somthing.apk',
                          'virusName': 'gxv',
                          'isApplication': true,
                          'isDeviceAdminThreat': false
                        })
                      ]);
                      if (sentData == false) {
                        _showSnackBar('Failed to send data to Chatbot');
                      } else {
                        _showSnackBar('Data has been sent to Chatbot');
                      }
                      setState(() {
                        isInProcessing = false;
                      });
                    },
                    child: const Text('Send a threat info to Chatbot'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(40),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
