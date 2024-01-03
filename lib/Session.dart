import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class Session {
  static Map<String, String> headers = {};
  static bool cookieExists = false;

  static Future<http.Response> get(String url) async {
    http.Response response = await http.get(Uri.parse(url), headers: headers);
    return response;
  }

  static Future<http.Response> post(String url, dynamic data) async {
    http.Response response = await http.post(Uri.parse(url), body: data, headers: headers);
    return response;
  }

  static Future<http.Response> put(String url, dynamic data) async {
    http.Response response = await http.put(Uri.parse(url), body: data, headers: headers);
    return response;
  }

  static void updateCookie() async{
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String cookieVal = prefs.getString("jwt") ?? "";
    if(cookieVal != "") {
      headers['cookie'] = cookieVal;
      cookieExists = true;
    }
  }
}