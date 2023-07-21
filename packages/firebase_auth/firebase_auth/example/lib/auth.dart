// Copyright 2022, the Chromium project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_example/app_data_change_notifier.dart';
import 'package:firebase_auth_example/main.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter_signin_button/flutter_signin_button.dart';
import 'package:flutter_web_auth/flutter_web_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;

import 'kakao_login_button.dart';

typedef OAuthSignIn = void Function();

// If set to true, the app will request notification permissions to use
// silent verification for SMS MFA instead of Recaptcha.
const withSilentVerificationSMSMFA = true;
const isKakaoSignInWithFirebase = true;

/// Helper class to show a snackbar using the passed context.
class ScaffoldSnackbar {
  // ignore: public_member_api_docs
  ScaffoldSnackbar(this._context);

  /// The scaffold of current context.
  factory ScaffoldSnackbar.of(BuildContext context) {
    return ScaffoldSnackbar(context);
  }

  final BuildContext _context;

  /// Helper method to show a SnackBar.
  void show(String message) {
    ScaffoldMessenger.of(_context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}

/// The mode of the current auth session, either [AuthMode.login] or [AuthMode.register].
// ignore: public_member_api_docs
enum AuthMode { login, register, phone }

extension on AuthMode {
  String get label => this == AuthMode.login
      ? 'Sign in'
      : this == AuthMode.phone
          ? 'Sign in'
          : 'Register';
}

/// Entrypoint example for various sign-in flows with Firebase.
class AuthGate extends StatefulWidget {
  // ignore: public_member_api_docs
  const AuthGate({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController phoneController = TextEditingController();

  GlobalKey<FormState> formKey = GlobalKey<FormState>();
  String error = '';
  String verificationId = '';

  AuthMode mode = AuthMode.login;

  bool isLoading = false;

  void setIsLoading() {
    if (mounted) {
      setState(() {
        isLoading = !isLoading;
      });
    }
  }

  late Map<Buttons, OAuthSignIn> authButtons;

  @override
  void initState() {
    super.initState();

    if (withSilentVerificationSMSMFA && !kIsWeb) {
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      messaging.requestPermission();
    }

    if (!kIsWeb && Platform.isMacOS) {
      authButtons = {
        Buttons.Apple: () => _handleMultiFactorException(
              _signInWithApple,
            ),
      };
    } else {
      authButtons = {
        Buttons.Google: () => _handleMultiFactorException(
              _signInWithGoogle,
            ),
        Buttons.Facebook: () => _handleMultiFactorException(
              _signInWithFacebook,
            ),
        Buttons.Apple: () => _handleMultiFactorException(
              _signInWithApple,
            ),
        Buttons.GitHub: () => _handleMultiFactorException(
              _signInWithGitHub,
            ),
        Buttons.Microsoft: () => _handleMultiFactorException(
              _signInWithMicrosoft,
            ),
        Buttons.Twitter: () => _handleMultiFactorException(
              _signInWithTwitter,
            ),
        Buttons.Yahoo: () => _handleMultiFactorException(
              _signInWithYahoo,
            ),
      };
    }
  }

  // @override
  // void didUpdateWidget(AuthGate oldAuthGateWidget) {
  //   super.didUpdateWidget(oldAuthGateWidget);

  //   print('Widget updated with new data');
  // }

  Future<OAuthToken?> _signInWithKakao() async {
    // Login combination sample + Detailed error handling callback
    bool talkInstalled = await isKakaoTalkInstalled();
    // If Kakao Talk has been installed, log in with Kakao Talk. Otherwise, log in with Kakao Account.
    if (talkInstalled) {
      try {
        OAuthToken token = await UserApi.instance.loginWithKakaoTalk();
        print('Login succeeded. ${token.accessToken}');
        return token;
      } catch (e) {
        print('Login failed. $e');

        // After installing Kakao Talk, if a user does not complete app permission and cancels Login with Kakao Talk, skip to log in with Kakao Account, considering that the user does not want to log in.
        // You could implement other actions such as going back to the previous page.
        if (e is PlatformException && e.code == 'CANCELED') {
          return null;
        }

        // If a user is not logged into Kakao Talk after installing Kakao Talk and allowing app permission, make the user log in with Kakao Account.
        try {
          OAuthToken token = await UserApi.instance.loginWithKakaoAccount();
          print('Login succeeded. ${token.accessToken}');
          return token;
        } catch (e) {
          print('Login failed. $e');
          return null;
        }
      }
    } else {
      try {
        print('Start Login');
        OAuthToken token = await UserApi.instance.loginWithKakaoAccount();
        print('Login succeeded. ${token.accessToken}');
        return token;
      } catch (e) {
        print('Login failed. $e');
        return null;
      }
    }
  }

  Future<void> retrieveUserInfo() async {
    // Retrieving user information
    try {
      KakaoUser user = await UserApi.instance.me();
      print('Succeeded in retrieving user information'
          '\nService user ID: ${user.id}'
          '\nEmail: ${user.kakaoAccount?.email}'
          '\nNickname: ${user.kakaoAccount?.profile?.nickname}'
          '\nProfile Thumbnail Image URI: ${user.kakaoAccount?.profile?.thumbnailImageUrl}');
      // Update the KakaoUser in AppData
      Provider.of<AppDataChangeNotifier>(context, listen: false).kakaoUser =
          user;
    } catch (e) {
      print('Failed to retrieve user information');
    }
  }

  Future<void> _onKakaoLoginButtonTap() async {
    setIsLoading();
    try {
      if (isKakaoSignInWithFirebase) {
        await _signInWithKakaoFirebase();
      } else {
        OAuthToken? token = await _signInWithKakao();
        print('token: $token');
        if (token != null) {
          await retrieveUserInfo();
        }
      }
    } catch (e) {
      print('Login fails. $e');
      setState(() {
        error = '$e';
      });
    } finally {
      setIsLoading();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: FocusScope.of(context).unfocus,
      child: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SafeArea(
                  child: Form(
                    key: formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Visibility(
                            visible: error.isNotEmpty,
                            child: MaterialBanner(
                              backgroundColor:
                                  Theme.of(context).colorScheme.error,
                              content: SelectableText(error),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      error = '';
                                    });
                                  },
                                  child: const Text(
                                    'dismiss',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                )
                              ],
                              contentTextStyle:
                                  const TextStyle(color: Colors.white),
                              padding: const EdgeInsets.all(10),
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (mode != AuthMode.phone)
                            Column(
                              children: [
                                TextFormField(
                                  controller: emailController,
                                  decoration: const InputDecoration(
                                    hintText: 'Email',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                  autofillHints: const [AutofillHints.email],
                                  validator: (value) =>
                                      value != null && value.isNotEmpty
                                          ? null
                                          : 'Required',
                                ),
                                const SizedBox(height: 20),
                                TextFormField(
                                  controller: passwordController,
                                  obscureText: true,
                                  decoration: const InputDecoration(
                                    hintText: 'Password',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (value) =>
                                      value != null && value.isNotEmpty
                                          ? null
                                          : 'Required',
                                ),
                              ],
                            ),
                          if (mode == AuthMode.phone)
                            TextFormField(
                              controller: phoneController,
                              decoration: const InputDecoration(
                                hintText: '+12345678910',
                                labelText: 'Phone number',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) =>
                                  value != null && value.isNotEmpty
                                      ? null
                                      : 'Required',
                            ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: isLoading
                                  ? null
                                  : () => _handleMultiFactorException(
                                        _emailAndPassword,
                                      ),
                              child: isLoading
                                  ? const CircularProgressIndicator.adaptive()
                                  : Text(mode.label),
                            ),
                          ),
                          TextButton(
                            onPressed: _resetPassword,
                            child: const Text('Forgot password?'),
                          ),
                          // Kakao
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: isLoading
                                  ? Container(
                                      color: Colors.grey[200],
                                      height: 50,
                                      width: double.infinity,
                                    )
                                  : SizedBox(
                                      width: double.infinity,
                                      height: 50,
                                      child: KakaoLoginButton(
                                        onTap: _onKakaoLoginButtonTap,
                                      ),
                                    ),
                            ),
                          ),
                          ...authButtons.keys
                              .map(
                                (button) => Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 5),
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    child: isLoading
                                        ? Container(
                                            color: Colors.grey[200],
                                            height: 50,
                                            width: double.infinity,
                                          )
                                        : SizedBox(
                                            width: double.infinity,
                                            height: 50,
                                            child: SignInButton(
                                              button,
                                              onPressed: authButtons[button]!,
                                            ),
                                          ),
                                  ),
                                ),
                              )
                              .toList(),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OutlinedButton(
                              onPressed: isLoading
                                  ? null
                                  : () {
                                      if (mode != AuthMode.phone) {
                                        setState(() {
                                          mode = AuthMode.phone;
                                        });
                                      } else {
                                        setState(() {
                                          mode = AuthMode.login;
                                        });
                                      }
                                    },
                              child: isLoading
                                  ? const CircularProgressIndicator.adaptive()
                                  : Text(
                                      mode != AuthMode.phone
                                          ? 'Sign in with Phone Number'
                                          : 'Sign in with Email and Password',
                                    ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (mode != AuthMode.phone)
                            RichText(
                              text: TextSpan(
                                style: Theme.of(context).textTheme.bodyLarge,
                                children: [
                                  TextSpan(
                                    text: mode == AuthMode.login
                                        ? "Don't have an account? "
                                        : 'You have an account? ',
                                  ),
                                  TextSpan(
                                    text: mode == AuthMode.login
                                        ? 'Register now'
                                        : 'Click to login',
                                    style: const TextStyle(color: Colors.blue),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {
                                        setState(() {
                                          mode = mode == AuthMode.login
                                              ? AuthMode.register
                                              : AuthMode.login;
                                        });
                                      },
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 10),
                          RichText(
                            text: TextSpan(
                              style: Theme.of(context).textTheme.bodyLarge,
                              children: [
                                const TextSpan(text: 'Or '),
                                TextSpan(
                                  text: 'continue as guest',
                                  style: const TextStyle(color: Colors.blue),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = _anonymousAuth,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future _resetPassword() async {
    String? email;
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Send'),
            ),
          ],
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter your email'),
              const SizedBox(height: 20),
              TextFormField(
                onChanged: (value) {
                  email = value;
                },
              ),
            ],
          ),
        );
      },
    );

    if (email != null) {
      try {
        await auth.sendPasswordResetEmail(email: email!);
        ScaffoldSnackbar.of(context).show('Password reset email is sent');
      } catch (e) {
        ScaffoldSnackbar.of(context).show('Error resetting');
      }
    }
  }

  Future<void> _anonymousAuth() async {
    setIsLoading();

    try {
      await auth.signInAnonymously();
    } on FirebaseAuthException catch (e) {
      setState(() {
        error = '${e.message}';
      });
    } catch (e) {
      setState(() {
        error = '$e';
      });
    } finally {
      setIsLoading();
    }
  }

  Future<void> _handleMultiFactorException(
    Future<void> Function() authFunction,
  ) async {
    setIsLoading();
    try {
      await authFunction();
    } on FirebaseAuthMultiFactorException catch (e) {
      setState(() {
        error = '${e.message}';
      });
      final firstHint = e.resolver.hints.first;
      if (firstHint is! PhoneMultiFactorInfo) {
        return;
      }
      await auth.verifyPhoneNumber(
        multiFactorSession: e.resolver.session,
        multiFactorInfo: firstHint,
        verificationCompleted: (_) {},
        verificationFailed: print,
        codeSent: (String verificationId, int? resendToken) async {
          final smsCode = await getSmsCodeFromUser(context);

          if (smsCode != null) {
            // Create a PhoneAuthCredential with the code
            final credential = PhoneAuthProvider.credential(
              verificationId: verificationId,
              smsCode: smsCode,
            );

            try {
              await e.resolver.resolveSignIn(
                PhoneMultiFactorGenerator.getAssertion(
                  credential,
                ),
              );
            } on FirebaseAuthException catch (e) {
              print(e.message);
            }
          }
        },
        codeAutoRetrievalTimeout: print,
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        error = '${e.message}';
      });
    } catch (e) {
      setState(() {
        error = '$e';
      });
    }
    setIsLoading();
  }

  Future<void> _emailAndPassword() async {
    if (formKey.currentState?.validate() ?? false) {
      if (mode == AuthMode.login) {
        await auth.signInWithEmailAndPassword(
          email: emailController.text,
          password: passwordController.text,
        );
      } else if (mode == AuthMode.register) {
        await auth.createUserWithEmailAndPassword(
          email: emailController.text,
          password: passwordController.text,
        );
      } else {
        await _phoneAuth();
      }
    }
  }

  Future<void> _phoneAuth() async {
    if (mode != AuthMode.phone) {
      setState(() {
        mode = AuthMode.phone;
      });
    } else {
      if (kIsWeb) {
        final confirmationResult =
            await auth.signInWithPhoneNumber(phoneController.text);
        final smsCode = await getSmsCodeFromUser(context);

        if (smsCode != null) {
          await confirmationResult.confirm(smsCode);
        }
      } else {
        await auth.verifyPhoneNumber(
          phoneNumber: phoneController.text,
          verificationCompleted: (_) {},
          verificationFailed: (e) {
            setState(() {
              error = '${e.message}';
            });
          },
          codeSent: (String verificationId, int? resendToken) async {
            final smsCode = await getSmsCodeFromUser(context);

            if (smsCode != null) {
              // Create a PhoneAuthCredential with the code
              final credential = PhoneAuthProvider.credential(
                verificationId: verificationId,
                smsCode: smsCode,
              );

              try {
                // Sign the user in (or link) with the credential
                await auth.signInWithCredential(credential);
              } on FirebaseAuthException catch (e) {
                setState(() {
                  error = e.message ?? '';
                });
              }
            }
          },
          codeAutoRetrievalTimeout: (e) {
            setState(() {
              error = e;
            });
          },
        );
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    // Trigger the authentication flow
    final googleUser = await GoogleSignIn().signIn();

    // Obtain the auth details from the request
    final googleAuth = await googleUser?.authentication;

    if (googleAuth != null) {
      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Once signed in, return the UserCredential
      await auth.signInWithCredential(credential);
    }
  }

  Future<void> _signInWithFacebook() async {
    final LoginResult result = await FacebookAuth.instance.login();
    if (result.status == LoginStatus.success) {
      // Create a credential from the access token
      final OAuthCredential credential =
          FacebookAuthProvider.credential(result.accessToken!.token);
      // Once signed in, return the UserCredential
      await FirebaseAuth.instance.signInWithCredential(credential);
    }
  }

  // https://firebase.google.com/docs/auth/flutter/custom-auth
  Future<UserCredential?> _signInWithKakaoFirebase() async {
    try {
      const client_id = 'b1540cc867505107fa1c27522a9e04da';
      const redirect_uri =
          'https://4b59-118-44-27-227.ngrok-free.app/callbacks/kakao/sign_in';
      const uri_token =
          'https://4b59-118-44-27-227.ngrok-free.app/callbacks/kakao/token';

      final clientState = const Uuid().v4();
      final url = Uri.https('kauth.kakao.com', '/oauth/authorize', {
        'response_type': 'code',
        'client_id': client_id,
        'response_mode': 'form_get',
        'redirect_uri': redirect_uri,
        'prompt': 'select_account',
        // 'scope': 'account_email profile_nickname',
        'state': clientState,
      });

      final result = await FlutterWebAuth.authenticate(
        url: url.toString(),
        callbackUrlScheme: 'webauthcallback',
      ); //"applink"//"signinwithapple"
      final body = Uri.parse(result).queryParameters;
      print(body['code']);

      final tokenUrl = Uri.https('kauth.kakao.com', '/oauth/token', {
        'grant_type': 'authorization_code',
        'client_id': client_id,
        // 'redirect_uri': redirect_uri_token,
        'redirect_uri': redirect_uri,
        'code': body['code'],
      });
      var responseTokens = await http.post(tokenUrl);
      Map<String, dynamic> bodys = json.decode(responseTokens.body);
      var response = await http.post(
        Uri.parse(uri_token),
        body: {'accessToken': bodys['access_token']},
      );
      // return FirebaseAuth.instance.signInWithCustomToken(response.body);
      return FirebaseAuth.instance.signInWithCustomToken(response.body);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'invalid-custom-token':
          print('The supplied token is not a Firebase custom auth token.');
          break;
        case 'custom-token-mismatch':
          print('The supplied token is for a different Firebase project.');
          break;
        default:
          print('Unkown error.');
      }
      return null;
    }
  }

  Future<void> _signInWithTwitter() async {
    TwitterAuthProvider twitterProvider = TwitterAuthProvider();

    if (kIsWeb) {
      await auth.signInWithPopup(twitterProvider);
    } else {
      await auth.signInWithProvider(twitterProvider);
    }
  }

  Future<void> _signInWithApple() async {
    final appleProvider = AppleAuthProvider();
    appleProvider.addScope('email');

    if (kIsWeb) {
      // Once signed in, return the UserCredential
      await auth.signInWithPopup(appleProvider);
    } else {
      await auth.signInWithProvider(appleProvider);
    }
  }

  Future<void> _signInWithYahoo() async {
    final yahooProvider = YahooAuthProvider();

    if (kIsWeb) {
      // Once signed in, return the UserCredential
      await auth.signInWithPopup(yahooProvider);
    } else {
      await auth.signInWithProvider(yahooProvider);
    }
  }

  Future<void> _signInWithGitHub() async {
    final githubProvider = GithubAuthProvider();

    if (kIsWeb) {
      await auth.signInWithPopup(githubProvider);
    } else {
      await auth.signInWithProvider(githubProvider);
    }
  }

  Future<void> _signInWithMicrosoft() async {
    final microsoftProvider = MicrosoftAuthProvider();

    if (kIsWeb) {
      await auth.signInWithPopup(microsoftProvider);
    } else {
      await auth.signInWithProvider(microsoftProvider);
    }
  }
}

Future<String?> getSmsCodeFromUser(BuildContext context) async {
  String? smsCode;

  // Update the UI - wait for the user to enter the SMS code
  await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        title: const Text('SMS code:'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Sign in'),
          ),
          OutlinedButton(
            onPressed: () {
              smsCode = null;
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
        ],
        content: Container(
          padding: const EdgeInsets.all(20),
          child: TextField(
            onChanged: (value) {
              smsCode = value;
            },
            textAlign: TextAlign.center,
            autofocus: true,
          ),
        ),
      );
    },
  );

  return smsCode;
}
