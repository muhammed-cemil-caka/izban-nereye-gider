// Firestore'dan durak verisini çeker.
//
// Firebase JS SDK'sı yerine REST API kullanılıyor: paket yöneticisi, derleme adımı
// ve CDN bağımlılığı olmadan çalışsın diye. Okuma yetkisi firestore.rules ile
// herkese açık olduğu için kimlik doğrulaması gerekmiyor.

var FIRESTORE_TABAN =
  'https://firestore.googleapis.com/v1/projects/' +
  FIREBASE_AYARI.projectId +
  '/databases/(default)/documents';

/** Firestore'un tipli değerini ({stringValue: "x"}) düz JS değerine çevirir. */
function firestoreDegeri(alan) {
  if (alan === null || alan === undefined) return null;
  if ('stringValue' in alan) return alan.stringValue;
  if ('integerValue' in alan) return Number(alan.integerValue);
  if ('doubleValue' in alan) return alan.doubleValue;
  if ('booleanValue' in alan) return alan.booleanValue;
  if ('nullValue' in alan) return null;
  if ('arrayValue' in alan) {
    return (alan.arrayValue.values || []).map(firestoreDegeri);
  }
  if ('mapValue' in alan) return firestoreBelgesi(alan.mapValue);
  return null;
}

/** Bir Firestore belgesinin alanlarını düz nesneye çevirir. */
function firestoreBelgesi(belge) {
  var sonuc = {};
  var alanlar = belge.fields || {};
  Object.keys(alanlar).forEach(function (ad) {
    sonuc[ad] = firestoreDegeri(alanlar[ad]);
  });
  return sonuc;
}

/**
 * Durakları Firestore'dan getirir; kuzeyden güneye sıralı döner.
 * Başarısız olursa hata fırlatır — çağıran taraf yerel kopyaya düşer.
 */
function firestoreDenDuraklariGetir() {
  var adres = FIRESTORE_TABAN + '/duraklar?pageSize=300&key=' + FIREBASE_AYARI.apiKey;

  return fetch(adres)
    .then(function (yanit) {
      if (!yanit.ok) throw new Error('Firestore yanıtı: ' + yanit.status);
      return yanit.json();
    })
    .then(function (veri) {
      var belgeler = veri.documents || [];
      if (belgeler.length === 0) throw new Error('Firestore boş.');

      return belgeler
        .map(firestoreBelgesi)
        .sort(function (a, b) { return a.sira - b.sira; });
    });
}

/** Hat bilgisini (sürüm, uç duraklar) getirir. Bulunamazsa null döner. */
function firestoreDenHatBilgisiGetir() {
  var adres = FIRESTORE_TABAN + '/hat/bilgi?key=' + FIREBASE_AYARI.apiKey;

  return fetch(adres).then(function (yanit) {
    if (!yanit.ok) throw new Error('hat/bilgi yanıtı: ' + yanit.status);
    return yanit.json().then(firestoreBelgesi);
  });
}

/* ---------- Okuma bütçesi ---------- */
//
// Firestore her BELGE için ayrı okuma sayar; 28 duraklık listeyi her ziyarette
// çekmek ziyaret başına 28 okuma demek. Durak verisi neredeyse hiç değişmediği
// için bunun yerine:
//
//   1. Tarayıcı önbelleği taze mi? → 0 okuma
//   2. Değilse tek belge (hat/bilgi) okunup sürüm karşılaştırılır → 1 okuma
//   3. Sürüm aynıysa uygulamayla gelen yerel kopya kullanılır → 0 ek okuma
//   4. Yalnızca sürüm değiştiyse 28 belgelik liste çekilir
//
// Böylece ziyaret başına maliyet 28 okumadan ~0'a iniyor; tam liste ancak veri
// gerçekten güncellendiğinde, tarayıcı başına bir kez okunuyor.

/**
 * İki x.y.z sürümünü karşılaştırır: a>b ise 1, a<b ise -1, eşitse 0.
 * Firestore'daki veri uygulamayla gelenden ESKİ olabilir (uygulama güncellendi
 * ama veritabanı henüz yüklenmedi); o durumda uzaktaki veri kullanılmamalı.
 */
function surumKarsilastir(a, b) {
  var pa = String(a).split('.').map(Number);
  var pb = String(b).split('.').map(Number);
  for (var i = 0; i < Math.max(pa.length, pb.length); i++) {
    var x = pa[i] || 0;
    var y = pb[i] || 0;
    if (x !== y) return x > y ? 1 : -1;
  }
  return 0;
}

var ONBELLEK_ANAHTAR = 'izban.veriOnbellegi';
var ONBELLEK_OMRU_MS = 6 * 60 * 60 * 1000; // 6 saat

function onbellektenOku(yerelSurum) {
  try {
    var ham = localStorage.getItem(ONBELLEK_ANAHTAR);
    if (!ham) return null;
    var kutu = JSON.parse(ham);
    if (!kutu || typeof kutu.zaman !== 'number') return null;
    if (Date.now() - kutu.zaman > ONBELLEK_OMRU_MS) return null;
    // Uygulama güncellendiyse önbellekteki eski veri atılır.
    if (surumKarsilastir(kutu.surum, yerelSurum) < 0) return null;
    return kutu;
  } catch (sorun) {
    return null; // bozuk kayıt veya özel mod
  }
}

function onbellegeYaz(surum, duraklar) {
  try {
    localStorage.setItem(ONBELLEK_ANAHTAR, JSON.stringify({
      zaman: Date.now(),
      surum: surum,
      duraklar: duraklar || null
    }));
  } catch (sorun) {
    // Kota dolu veya özel mod: önbelleksiz devam edilir.
  }
}

/**
 * Gösterilecek veriyi en az okumayla getirir.
 *
 * @param {string} yerelSurum duraklar.js içindeki sürüm
 * @returns {Promise<{duraklar: ?Array, surum: string, kaynak: string, okuma: number}>}
 *   `duraklar` null ise yerel kopya güncel demektir, değiştirmeye gerek yoktur.
 */
function guncelDuraklariGetir(yerelSurum) {
  var onbellek = onbellektenOku(yerelSurum);
  if (onbellek) {
    return Promise.resolve({
      duraklar: onbellek.duraklar,
      surum: onbellek.surum,
      kaynak: 'onbellek',
      okuma: 0
    });
  }

  return firestoreDenHatBilgisiGetir().then(function (hat) {
    if (!hat || !hat.surum) throw new Error('hat/bilgi okunamadı.');

    // Uzaktaki veri yeni DEĞİLSE (aynı ya da daha eski) yerel kopya kullanılır.
    // Eşitlikle yetinmek, veritabanı henüz güncellenmemişken uygulamanın kendi
    // yeni verisini eski veriyle ezmesine yol açardı.
    if (surumKarsilastir(hat.surum, yerelSurum) <= 0) {
      onbellegeYaz(yerelSurum, null);
      return { duraklar: null, surum: yerelSurum, kaynak: 'firebase', okuma: 1 };
    }

    return firestoreDenDuraklariGetir().then(function (duraklar) {
      onbellegeYaz(hat.surum, duraklar);
      return {
        duraklar: duraklar,
        surum: hat.surum,
        kaynak: 'firebase',
        okuma: 1 + duraklar.length
      };
    });
  });
}

