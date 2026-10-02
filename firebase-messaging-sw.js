// Firebase Cloud Messaging service worker (웹 백그라운드 푸시 수신).
//
// firebase_messaging_web 플러그인이 이 파일(웹 루트)을 자동 등록한다.
// firebaseConfig 값은 클라이언트 공개값(Firebase 웹 앱 설정) — 시크릿 아님.
// 프로젝트: nest-lionandthelab (#62668430721).
//
// 참고: 웹 푸시 토큰 발급에는 이 파일 외에 VAPID 공개키(LION_FCM_WEB_VAPID_KEY)가
// 필요하다. 아직 미발급 상태면 토큰은 null이고 백그라운드 SW만 준비된다.
/* eslint-disable no-undef */

importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyDX4h-Xsmtbc0fgmWnBRVCs4U6LEIuXj5M',
  authDomain: 'nest-lionandthelab.firebaseapp.com',
  projectId: 'nest-lionandthelab',
  storageBucket: 'nest-lionandthelab.firebasestorage.app',
  messagingSenderId: '62668430721',
  appId: '1:62668430721:web:c28341e74a628675e45c80',
  measurementId: 'G-TTCEFJTGTM',
});

const messaging = firebase.messaging();

// 백그라운드 수신 — data-only 메시지가 아니면 브라우저가 자동 표시하므로,
// 여기서는 커스텀 표시가 필요할 때만 처리한다.
messaging.onBackgroundMessage((payload) => {
  const title = (payload.notification && payload.notification.title) || 'Nest';
  const options = {
    body: (payload.notification && payload.notification.body) || '',
    icon: '/icons/Icon-192.png',
    data: payload.data || {},
  };
  self.registration.showNotification(title, options);
});
