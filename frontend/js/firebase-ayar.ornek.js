// Bu dosyayı "firebase-ayar.js" adıyla kopyalayıp kendi proje bilgilerinizi yazın.
// firebase-ayar.js .gitignore içindedir; anahtarları depoya göndermeyin.
//
// Değerleri Firebase Konsolu → Proje ayarları → Uygulamalarınız bölümünden alın.
//
// Not: Site şu an duraklar.js içindeki yerel veriyle çalışır; Firebase bağlantısı
// canlı veri/favoriler eklendiğinde devreye girer.

const FIREBASE_AYARI = {
  apiKey: 'BURAYA_API_ANAHTARI',
  authDomain: 'PROJE.firebaseapp.com',
  projectId: 'PROJE',
  storageBucket: 'PROJE.appspot.com',
  messagingSenderId: 'GONDERICI_KIMLIGI',
  appId: 'UYGULAMA_KIMLIGI'
};

// API taban adresi: Hosting üzerinden yayındayken "/api", yerelde emülatör adresi.
const API_ADRESI = location.hostname === 'localhost'
  ? 'http://localhost:5001/PROJE/europe-west1/api'
  : '/api';
