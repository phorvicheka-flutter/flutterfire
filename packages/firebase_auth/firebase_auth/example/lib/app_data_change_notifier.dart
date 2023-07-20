import 'package:flutter/widgets.dart';

import 'main.dart';

class AppDataChangeNotifier extends ChangeNotifier {
  KakaoUser? _kakaoUser; // Add the KakaoUser property

  bool get isLoginWithKakao =>
      _kakaoUser != null; // Return true if _kakaoUser is not null

  KakaoUser? get kakaoUser => _kakaoUser; // Add the getter for KakaoUser

  set kakaoUser(KakaoUser? user) {
    _kakaoUser = user;
    notifyListeners();
  }

  void logout() {
    _kakaoUser = null; // Reset _kakaoUser to null
    notifyListeners();
  }
}
