// Web push for the Vesta Padre web panel (Firebase Cloud Messaging).
// The browser runs this file in the background, also with the page closed.
// The server sends `notification` + `webpush.fcmOptions.link`: the Firebase
// SDK shows the notification and, on tap, opens or focuses that link.
//
// Keep the version equal to the Firebase JS SDK that FlutterFire loads
// (firebase_core_web: supportedFirebaseJsSdkVersion).
importScripts('https://www.gstatic.com/firebasejs/12.19.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/12.19.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyAMAvjrzQOz0DS678r-Qs7RcXXoTJ0IVSo',
  appId: '1:467514559504:web:efb16f0458dc2d8d510e95',
  messagingSenderId: '467514559504',
  projectId: 'vesta-opensource',
  authDomain: 'vesta-opensource.firebaseapp.com',
  storageBucket: 'vesta-opensource.firebasestorage.app',
});

firebase.messaging();
