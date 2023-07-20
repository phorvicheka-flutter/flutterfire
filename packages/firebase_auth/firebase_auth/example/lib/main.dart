// Copyright 2022, the Chromium project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_example/profile_kakao.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart'
    as kakao_flutter_sdk_user;
import 'package:provider/provider.dart';

import 'app_data_change_notifier.dart';
import 'auth.dart';
import 'firebase_options.dart';
import 'profile.dart';

/// Requires that a Firebase local emulator is running locally.
/// See https://firebase.flutter.dev/docs/auth/start/#optional-prototype-and-test-with-firebase-local-emulator-suite
bool shouldUseFirebaseEmulator = false;
String facebookAuthAppId = '1668977596911004';

late final FirebaseApp app;
late final FirebaseAuth auth;

// Create an alias for the User class from the Kakao Flutter SDK
typedef KakaoUser = kakao_flutter_sdk_user.User;
typedef KakaoSdk = kakao_flutter_sdk_user.KakaoSdk;

// Requires that the Firebase Auth emulator is running locally
// e.g via `melos run firebase:emulator`.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // We're using the manual installation on non-web platforms since Google sign in plugin doesn't yet support Dart initialization.
  // See related issue: https://github.com/flutter/flutter/issues/96391

  // We store the app and auth to make testing with a named instance easier.
  app = await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  auth = FirebaseAuth.instanceFor(app: app);

  if (shouldUseFirebaseEmulator) {
    await auth.useAuthEmulator('localhost', 9099);
  }

  if (kIsWeb || defaultTargetPlatform == TargetPlatform.macOS) {
    // initialiaze the facebook javascript SDK
    await FacebookAuth.instance.webAndDesktopInitialize(
      appId: facebookAuthAppId,
      cookie: true,
      xfbml: true,
      version: 'v15.0',
    );
  }

  KakaoSdk.init(
    nativeAppKey: '3d671d050c4f4b221c4fd5dce31a5dad',
    javaScriptAppKey: '659fd5c08365cb80aae07835b4030106',
  );

  runApp(
    ChangeNotifierProvider(
      create: (context) => AppDataChangeNotifier(),
      child: const AuthExampleApp(),
    ),
  );
}

/// The entry point of the application.
///
/// Returns a [MaterialApp].
class AuthExampleApp extends StatelessWidget {
  const AuthExampleApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Firebase Example App',
      theme: ThemeData(primarySwatch: Colors.amber),
      home: Scaffold(
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isLoginWithKakao =
                Provider.of<AppDataChangeNotifier>(context).isLoginWithKakao;
            return Row(
              children: [
                Visibility(
                  visible: constraints.maxWidth >= 1200,
                  child: Expanded(
                    child: Container(
                      height: double.infinity,
                      color: Theme.of(context).colorScheme.primary,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Firebase Auth Desktop',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: constraints.maxWidth >= 1200
                      ? constraints.maxWidth / 2
                      : constraints.maxWidth,
                  child: isLoginWithKakao
                      ? ProfileKakaoPage()
                      : StreamBuilder<User?>(
                          stream: auth.authStateChanges(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              return const ProfilePage();
                            }
                            return const AuthGate();
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
