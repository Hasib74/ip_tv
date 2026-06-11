importScripts("https://www.gstatic.com/firebasejs/9.10.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/9.10.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyD84ZQeB6LePgWspPdTfwfTaB_c_pPZurA",
  authDomain: "iptv-e14c0.firebaseapp.com",
  projectId: "iptv-e14c0",
  storageBucket: "iptv-e14c0.firebasestorage.app",
  messagingSenderId: "781909343868",
  appId: "1:781909343868:web:2026e05b31b6068f0953f9",
  measurementId: "G-Q7G3WQF6ND"
});

const messaging = firebase.messaging();

// Optional: Handle background messages
messaging.onBackgroundMessage((payload) => {
  console.log("Received background message ", payload);
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: "/icons/Icon-192.png"
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
