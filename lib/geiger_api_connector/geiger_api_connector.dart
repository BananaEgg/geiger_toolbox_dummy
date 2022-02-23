import 'dart:developer';

import 'package:geiger_api/geiger_api.dart';
import 'package:geiger_localstorage/geiger_localstorage.dart';

import 'geiger_event_listener.dart';

class GeigerApiConnector {
  GeigerApiConnector({
    required this.pluginId,
  });

  String pluginId; // Unique and assigned by GeigerToolbox
  GeigerApi? pluginApi;
  StorageController? storageController;

  String? currentUserId; // will be retrieved from GeigerStorage
  String? currentDeviceId; // will be retrieved from GeigerStorage

  GeigerEventListener? pluginListener;
  List<MessageType> handledEvents = [];
  bool isListenerRegistered = false;

  // Get an instance of GeigerApi, to be able to start working with GeigerToolbox
  Future<bool> connectToGeigerAPI() async {
    log('Trying to connect to the GeigerApi');
    if (pluginApi != null) {
      log('Plugin $pluginId has been initialized');
      return true;
    } else {
      try {
        flushGeigerApiCache();
        if (pluginId == GeigerApi.masterId) {
          pluginApi =
              await getGeigerApi('', pluginId, Declaration.doNotShareData);
          log('MasterId: ${pluginApi.hashCode}');
          return true;
        } else {
          pluginApi = await getGeigerApi(
              './$pluginId', pluginId, Declaration.doNotShareData);
          log('pluginApi: ${pluginApi.hashCode}');
          return true;
        }
      } catch (e) {
        log('Failed to get the GeigerAPI');
        log(e.toString());
        return false;
      }
    }
  }

  Future menuPressed(GeigerUrl url) async {
    pluginApi!.menuPressed(url);
  }

  Future<List<MenuItem>> getMenueItems() async {
    List<MenuItem> menuList = [];

    try {
      menuList = pluginApi!.getMenuList();
    } catch (e) {
      log(e.toString());
    }

    return menuList;
  }

  // Get UUID of user or device
  Future getUUID(var key) async {
    var local = await storageController!.get(':Local');
    var temp = await local.getValue(key);
    return temp?.getValue('en');
  }

  
  /// Prepare a root node with given path
  Future<bool> prepareRoot(List<String> rootPath, String? owner) async {
    String currentRoot = '';
    int currentIndex = 0;
    while (currentIndex < rootPath.length) {
      try {
        await storageController!.addOrUpdate(NodeImpl(rootPath[currentIndex],
            owner ?? '', currentRoot == '' ? ':' : currentRoot));
        currentRoot = '$currentRoot:${rootPath[currentIndex]}';
        currentIndex++;
      } catch (e) {
        log('Failed to prepare the path: $currentRoot:${rootPath[currentIndex]}');
        log(e.toString());
        return false;
      }
    }
    Node testNode = await storageController!.get(currentRoot);
    log('Root: ${testNode.toString()}');
    return true;
  }

  // Get an instance of GeigerStorage to read/write data
  Future<bool> connectToLocalStorage() async {
    log('Trying to connect to the GeigerStorage');
    if (storageController != null) {
      log('Plugin $pluginId has already connected to the GeigerStorage (${storageController.hashCode})');
      return true;
    } else {
      try {
        storageController = pluginApi!.getStorage();
        log('Connected to the GeigerStorage ${storageController.hashCode}');
        currentUserId = await getUUID('currentUser');
        currentDeviceId = await getUUID('currentDevice');
        log('currentUserId: $currentUserId');
        log('currentDeviceId: $currentDeviceId');
        return true;
      } catch (e) {
        log('Failed to connect to the GeigerStorage');
        log(e.toString());
        return false;
      }
    }
  }

  // Dynamically define the handler for each message type
  void addMessagehandler(MessageType type, Function handler) {
    if (pluginListener == null) {
      pluginListener = GeigerEventListener('PluginListener-$pluginId');
      log('PluginListener: ${pluginListener.hashCode}');
    }
    handledEvents.add(type);
    pluginListener!.addMessageHandler(type, handler);
  }

  // Register the listener to listen all messages (events)
  Future<bool> registerListener() async {
    if (isListenerRegistered == true) {
      log('Plugin ${pluginListener.hashCode} has been registered already!');
      return true;
    } else {
      if (pluginListener == null) {
        pluginListener = GeigerEventListener('PluginListener-$pluginId');
        log('PluginListener: ${pluginListener.hashCode}');
      }
      try {
        // await pluginApi!
        //     .registerListener(handledEvents, pluginListener!); // This should be correct one
        await pluginApi!
            .registerListener([MessageType.allEvents], pluginListener!);
        await pluginApi!
            .registerListener([MessageType.registerPlugin], pluginListener!);
        log('Plugin ${pluginListener.hashCode} has been registered and activated');
        isListenerRegistered = true;
        return true;
      } catch (e) {
        log('Failed to register listener');
        log(e.toString());
        return false;
      }
    }
  }

  // Send a simple message which contain only the message type to the GeigerToolbox
  Future<bool> sendAMessageType(MessageType messageType) async {
    try {
      log('Trying to send a message type $messageType');
      final GeigerUrl testUrl =
          GeigerUrl.fromSpec('geiger://${GeigerApi.masterId}/test');
      final Message request = Message(
        pluginId,
        GeigerApi.masterId,
        messageType,
        testUrl,
      );
      await pluginApi!.sendMessage(request);
      log('A message type $messageType has been sent successfully');
      return true;
    } catch (e) {
      log('Failed to send a message type $messageType');
      log(e.toString());
      return false;
    }
  }

  // Show some statistics of Listener
  String getListenerToString() {
    return pluginListener.toString();
  }

  // Get the list of received messages
  List<Message> getAllMessages() {
    return pluginListener!.getAllMessages();
  }


  Future<void> readData() async {
    String nodePath = ':Device:data';
    try {
      Node node = await storageController!.get(nodePath);
      log('Reading node: ');
      log(node.toString());
    } catch (e) {
      log('Failed to get node $nodePath');
      log(e.toString());
    }
  }


  Future<String?> readGeigerValueOfUserSensor(
      String _pluginId, String sensorId) async {
    return await _readValueOfNod(
        ':Users:$currentUserId:$_pluginId:data:metrics:$sensorId');
  }

  Future<String?> readGeigerValueOfDeviceSensor(
      String _pluginId, String sensorId) async {
    return await _readValueOfNod(
        ':Device:$currentDeviceId:$_pluginId:data:metrics:$sensorId');
  }

  Future<String?> _readValueOfNod(String nodePath) async {
    log('Going to get value of node at $nodePath');
    try {
      Node node = await storageController!.get(nodePath);
      var temp = await node.getValue('GEIGERValue');
      return temp?.getValue('en');
    } catch (e) {
      log('Failed to get value of node at $nodePath');
      log(e.toString());
    }
  }

    /// Send a data node which include creating a new node and write the data
  Future<bool> sendDataNode(
      String nodePath, List<String> keys, List<String> values) async {
    if (keys.length != values.length) {
      log('The size of keys and values must be the same');
      return false;
    }
    try {
      Node node = NodeImpl(nodePath, '');
      for (var i = 0; i < keys.length; i++) {
        await node.addValue(NodeValueImpl(keys[i], values[i]));
      }
      await storageController!.addOrUpdate(node);
      return true;
    } catch (e) {
      log('Failed to send a data node: $nodePath');
      log(e.toString());
      return false;
    }
  }
}
