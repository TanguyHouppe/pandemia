import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:pandemia/components/home/visit.dart';
import 'package:pandemia/data/database/models/Location.dart';
import 'package:pandemia/data/populartimes/payloads/populartimes.dart';
import 'package:pandemia/data/state/AppModel.dart';

import '../../populartimes/parser/parser.dart';
import '../database.dart';

class DataCollect {
  var res;
  static var result = 0.0;
  static AppDatabase db = new AppDatabase();
  // ignore: non_constant_identifier_names
  DateTime last_notif;

  static final DataCollect _singleton = DataCollect._internal();

  //methode permettant de créer un singleton
  factory DataCollect() {
    return _singleton;
  }

  DataCollect._internal();

  //methode permettant de creer une notification
  Future _showNotificationWithDefaultSound(taux) async {
    FlutterLocalNotificationsPlugin flip =
        new FlutterLocalNotificationsPlugin();

    // app_icon needs to be a added as a drawable
    // resource to the Android head project.
    var android = new AndroidInitializationSettings('@mipmap/ic_launcher');
    // ignore: non_constant_identifier_names
    var IOS = new IOSInitializationSettings();

    // initialise settings for both Android and iOS device.
    var settings = new InitializationSettings(android, IOS);
    flip.initialize(settings);
    // Show a notification after every 15 minute with the first
    // appearance happening a minute after invoking the method
    var androidPlatformChannelSpecifics = new AndroidNotificationDetails(
        'your channel id', 'your channel name', 'your channel description',
        importance: Importance.Max, priority: Priority.High);
    var iOSPlatformChannelSpecifics = new IOSNotificationDetails();

    // initialise channel platform for both Android and iOS device.
    var platformChannelSpecifics = new NotificationDetails(
        androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
    var texte = 'Votre taux d\'exposition quotidien est de ' + taux.toString();
    await flip.show(0, 'Pandemia', texte, platformChannelSpecifics,
        payload: 'Default_Sound');
  }

  void findPlaceFromString(String address) async {
    String key = AppModel.apiKey;
    const _host =
        'https://maps.googleapis.com/maps/api/place/findplacefromtext/json';
    var encoded = Uri.encodeComponent(address);
    // TODO filter place types (prevent registering cities, for example, for they cannot provide popular times)
    final uri = Uri.parse('$_host?input=$encoded&inputtype=textquery'
        '&fields=name,place_id,formatted_address,geometry'
        '&locationbias=circle:467.0@50.68078750377484,3.2189865969121456'
        '&key=$key');
    print('hitting $uri');

    http.Response response = await http.get(uri);
    final responseJson = json.decode(response.body);
    var candidates = responseJson['candidates'];
    if (candidates.length != 0) {
      res = candidates[0]['name'];
    }
  }

  /*
  *methode permettant de recuperer des donnees de flux de personnes a partir d'une adresse
  *retourne une valeur representant le taux d'exposition
   */
  recupDonnees(liste, i, nb, n, r, v) async {
    var name;
    //url permettant de recuperer ces donnees au format JSON
    String url =
        "https://www.google.de/search?tbm=map&ych=1&h1=en&pb=!4m12!1m3!1d4005.9771522653964!2d-122.42072974863942!3d37.8077459796541!2m3!1f0!2f0!3f0!3m2!1i1125!2i976!4f13.1!7i20!10b1!12m6!2m3!5m1!6e2!20e3!10b1!16b1!19m3!2m2!1i392!2i106!20m61!2m2!1i203!2i100!3m2!2i4!5b1!6m6!1m2!1i86!2i86!1m2!1i408!2i200!7m46!1m3!1e1!2b0!3e3!1m3!1e2!2b1!3e2!1m3!1e2!2b0!3e3!1m3!1e3!2b0!3e3!1m3!1e4!2b0!3e3!1m3!1e8!2b0!3e3!1m3!1e3!2b1!3e2!1m3!1e9!2b1!3e2!1m3!1e10!2b0!3e3!1m3!1e10!2b1!3e2!1m3!1e10!2b0!3e4!2b1!4b1!9b0!22m6!1sa9fVWea_MsX8adX8j8AE%3A1!2zMWk6Mix0OjExODg3LGU6MSxwOmE5ZlZXZWFfTXNYOGFkWDhqOEFFOjE!7e81!12e3!17sa9fVWea_MsX8adX8j8AE%3A564!18e15!24m15!2b1!5m4!2b1!3b1!5b1!6b1!10m1!8e3!17b1!24b1!25b1!26b1!30m1!2b1!36b1!26m3!2m2!1i80!2i92!30m28!1m6!1m2!1i0!2i0!2m2!1i458!2i976!1m6!1m2!1i1075!2i0!2m2!1i1125!2i976!1m6!1m2!1i0!2i0!2m2!1i1125!2i20!1m6!1m2!1i0!2i956!2m2!1i1125!2i976!37m1!1e81!42b1!47m0!49m1!3b1&q=$name $n $r $v";
    String encodedUrl = Uri.encodeFull(url);

    var response = await http.get(encodedUrl);
    var file = response.body;
    PopularTimes stats;
    try {
      stats = Parser.parseResponse(file);

      var arrive = liste[i].timestamp.hour;
      var depart = liste[i + nb].timestamp.hour;
      var jour = liste[i].timestamp.weekday;
      var k;

      var dayResult = stats.stats[jour];
      List<int> listResult = [];
      if (dayResult.containsData) {
        for (k = arrive; k <= depart; k++) {
          if (k >= 7) {
            listResult.add(dayResult.times[k - 7][1]);
          }
        }
      }
      var c = 0;
      print(listResult);
      print(nb);
      listResult.forEach((element) => c += element);
      var moyenne = c / listResult.length;
      //
      return moyenne * nb * 0.125;
    } catch (err) {
      stats = new PopularTimes(hasData: false);
      return 0.0;
    }
  }

  /*
  *methode generant l'affichage de la notification a partir d'une certaine condition et modifie le taux d'exposition
  * retourne la liste des lieux visite

   */
  Future<List<Visit>> conv() async {
    List<Visit> listeVisite = [];
    List<Location> liste = await db.getLocations();
    Placemark old;
    Location oldLoc;
    int nb = 0;
    int i = liste.length - 1;
    DateTime now = new DateTime.now();
    double moyenne;

    var n;
    var r;
    var v;
    result = 0;
    while (i >= 0 && now.difference(liste[i].timestamp).inDays < 1) {
      List<Placemark> placemark = await Geolocator()
          .placemarkFromCoordinates(liste[i].lat, liste[i].lng);
      n = placemark[0].name;
      r = placemark[0].thoroughfare;
      v = placemark[0].locality;

      if (old != null &&
          n == old.name &&
          r == old.thoroughfare &&
          v == old.locality) {
        nb += 1;
      } else {
        if (nb >= 3) {
          listeVisite.add(new Visit(liste[i + 1], nb));
          findPlaceFromString('$n $r $v');
          moyenne = await recupDonnees(
              liste, i + 1, nb, old.name, old.thoroughfare, old.locality);
          result += moyenne;
        }
        nb = 0;
      }
      old = placemark[0];
      oldLoc = liste[i];
      i = i - 1;
    }
    if (nb >= 3) {
      listeVisite.add(new Visit(oldLoc, nb));
      findPlaceFromString('$n $r $v');
      i = i + 1;
      if (i == -1) {
        i = 0;
      }

      moyenne = await recupDonnees(liste, i, nb, n, r, v);
      result += moyenne;
    }
    if (result >= 50) {
      if (last_notif == null || now.difference(last_notif).inHours >= 2) {
        _showNotificationWithDefaultSound(result);
        last_notif = now;
      }
    }
    return listeVisite;
  }
}
