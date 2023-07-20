import 'package:flutter/material.dart';

class KakaoLoginButton extends StatelessWidget {
  final VoidCallback onTap;

  KakaoLoginButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Image.asset(
        'assets/images/kakao_login_medium_narrow.png',
        width: 100, // Adjust the width as per your requirement
        height: 100, // Adjust the height as per your requirement
      ),
    );
  }
}
