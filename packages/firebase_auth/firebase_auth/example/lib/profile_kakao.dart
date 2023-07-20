// Copyright 2022, the Chromium project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:firebase_auth_example/main.dart';
import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:provider/provider.dart';

import 'app_data_change_notifier.dart';

/// Displayed as a profile image if the user doesn't have one.
const placeholderImage =
    'https://upload.wikimedia.org/wikipedia/commons/c/cd/Portrait_Placeholder_Square.png';

/// Profile page shows after sign in or registerationg
class ProfileKakaoPage extends StatelessWidget {
  /// Example code for sign out.
  Future<void> _signOut(BuildContext context) async {
    // Logout
    try {
      await UserApi.instance.logout();
      print('Logout succeeds. Tokens are deleted from SDK.');
      // Obtain an instance of AppDataChangeNotifier
      final appData =
          Provider.of<AppDataChangeNotifier>(context, listen: false);

      // Call the logout method to reset the _kakaoUser to null
      appData.logout();
    } catch (e) {
      print('Logout fails. Tokens are deleted from SDK.');
    }
  }

  @override
  Widget build(BuildContext context) {
    KakaoUser? user = Provider.of<AppDataChangeNotifier>(context).kakaoUser;
    return GestureDetector(
      onTap: FocusScope.of(context).unfocus,
      child: Scaffold(
        body: Stack(
          children: [
            Center(
              child: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            maxRadius: 60,
                            backgroundImage: NetworkImage(
                              user?.kakaoAccount?.profile?.thumbnailImageUrl ??
                                  placeholderImage,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(user?.id.toString() ?? 'Id'),
                      const SizedBox(height: 10),
                      Text(user?.kakaoAccount?.profile?.nickname ?? 'Nickname'),
                      const SizedBox(height: 10),
                      Text(user?.kakaoAccount?.email ?? 'Email'),
                      const SizedBox(height: 20),
                      const Divider(),
                      TextButton(
                        onPressed: () => _signOut(context),
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
