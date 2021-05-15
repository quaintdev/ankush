import 'dart:async';

import 'package:android_intent/android_intent.dart';
import 'package:device_apps/device_apps.dart';
import 'package:flutter/material.dart';
import 'package:screen_state/screen_state.dart';
import 'package:search_page/search_page.dart';

List<Application> apps = [];

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _loadApps();
  runApp(MyApp());
}

Future _loadApps() async {
  DeviceApps.listenToAppsChanges().listen((appChanged) {
    if (appChanged.event == ApplicationEventType.uninstalled) {
      DeviceApps.getApp(appChanged.packageName)
          .then((value) => apps.remove(value as ApplicationWithIcon));
    }
  });
  List<Application> appList = await DeviceApps.getInstalledApplications(
      includeAppIcons: false,
      onlyAppsWithLaunchIntent: true,
      includeSystemApps: true);
  if (apps.length == 0) {
    appList.forEach((element) {
      apps.add(element);
    });
  }
  //apps.sort((a, b) => a.appName.compareTo(b.appName));
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      darkTheme: ThemeData.dark(),
      home: MyHomePage(),
    );
  }
}

class ScreenStateEventEntry {
  ScreenStateEvent event;
  DateTime time;

  ScreenStateEventEntry(this.event) {
    time = DateTime.now();
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Screen _screen = Screen();
  StreamSubscription<ScreenStateEvent> _subscription;
  bool started = false;
  int unlockCount = 0;
  int screenOnTime = 0;
  DateTime lastScreenOnTime = DateTime.now();
  DateTime lastScreenOffTime = DateTime.now();
  int glass = 0;

  ScreenStateEventEntry lastEvent;

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    startListening();
  }

  void onData(ScreenStateEvent event) {
    if (lastEvent?.event != event) {
      lastEvent = ScreenStateEventEntry(event);
      switch (lastEvent.event) {
        case ScreenStateEvent.SCREEN_UNLOCKED:
          setState(() {
            unlockCount++;
          });
          break;
        case ScreenStateEvent.SCREEN_ON:
          int timeInMinutes = screenOnTime +
              lastScreenOffTime.difference(lastScreenOnTime).inMinutes;
          lastScreenOnTime = lastEvent.time;
          setState(() {
            screenOnTime = timeInMinutes;
          });
          break;
        case ScreenStateEvent.SCREEN_OFF:
          lastScreenOffTime = lastEvent.time;
          break;
        default:
      }
    }
  }

  void startListening() {
    try {
      _subscription = _screen.screenStateStream.listen(onData);
    } on ScreenStateException catch (exception) {
      print(exception);
    }
  }

  @override
  initState() {
    super.initState();
    initPlatformState();
  }

  String searchQuery = "";

  SearchPage<Application> _prepareSearchDelegate() {
    return SearchPage<Application>(
      showItemsOnEmpty: false,
      items: apps,
      onQueryUpdate: (query) => searchQuery = query,
      searchLabel: 'Search app',
      failure: Center(
        child: TextButton(
          onPressed: () {
            AndroidIntent _playStoreIntent = AndroidIntent(
              action: "action_view",
              data: "market://search?q=" + searchQuery,
            );
            _playStoreIntent.launch();
            Navigator.of(context).maybePop();
          },
          style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all(Colors.blue)),
          child: Text("Open in play store"),
        ),
      ),
      filter: (app) => [app.appName],
      builder: (app) {
        return ListTile(
          //leading: Image.memory(app.icon, width: 24.0),
          title: Text(app.appName),
          onTap: () {
            DeviceApps.openApp(app.packageName);
            Navigator.of(context).maybePop();
          },
          onLongPress: () {
            AndroidIntent intent = AndroidIntent(
              action: "android.settings.APPLICATION_DETAILS_SETTINGS",
              package: app.packageName,
              data: "package:" + app.packageName,
            );
            intent.launch();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Padding(
              padding:
                  const EdgeInsets.only(top: 100.0, left: 16.0, right: 16.0),
              child: Container(
                height: 100.0,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "So far today",
                            style: TextStyle(fontSize: 24.0),
                          ),
                          SizedBox(
                            height: 8.0,
                          ),
                          Text(
                            "Screen unlocks: " + unlockCount.toStringAsFixed(0),
                            style: TextStyle(fontSize: 16.0),
                          ),
                          Text(
                            "Screen Time: " +
                                screenOnTime.toStringAsFixed(1) +
                                " min",
                            style: TextStyle(fontSize: 16.0),
                          ),
                          Text("Water: " +
                              (getWaterInMl(glass)).toStringAsFixed(1) +
                              " ml")
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Next " + remainingHoursOfDay().toString() + "h",
                            style: TextStyle(fontSize: 24.0),
                          ),
                          SizedBox(
                            height: 8.0,
                          ),
                          Text(
                            (unlockCount + unlockCount * projectionFactor())
                                .toStringAsFixed(0),
                            style: TextStyle(fontSize: 16.0),
                          ),
                          Text(
                            (screenOnTime + screenOnTime * projectionFactor())
                                    .toStringAsFixed(1) +
                                " min",
                            style: TextStyle(fontSize: 16.0),
                          ),
                          Text((getWaterInMl(glass) +
                                      getWaterInMl(glass) * projectionFactor())
                                  .toStringAsFixed(1) +
                              " ml")
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                IconButton(
                  color: Colors.white,
                  icon: Icon(Icons.local_drink),
                  onPressed: () {
                    setState(() {
                      glass++;
                    });
                  },
                ),
                IconButton(
                  color: Colors.white,
                  icon: Icon(Icons.attach_money),
                  onPressed: () {
                    DeviceApps.openApp("com.zerodha.kite3");
                  },
                ),
                IconButton(
                  color: Colors.white,
                  icon: Icon(Icons.music_note),
                  onPressed: () {
                    DeviceApps.openApp("com.spotify.music");
                  },
                ),
                IconButton(
                    color: Colors.white,
                    icon: Icon(Icons.search),
                    onPressed: () => showSearch(
                          context: context,
                          delegate: _prepareSearchDelegate(),
                        )),
                IconButton(
                  color: Colors.white,
                  icon: Icon(Icons.dialpad),
                  onPressed: () {
                    DeviceApps.openApp("com.android.dialer");
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

double projectionFactor() {
  int hoursSinceMorning = DateTime.now().hour - 7;
  return (remainingHoursOfDay() / hoursSinceMorning);
}

int remainingHoursOfDay() {
  int currentHour = DateTime.now().hour;
  return 24 - currentHour;
}

int getWaterInMl(int glass) {
  return 250 * glass;
}
