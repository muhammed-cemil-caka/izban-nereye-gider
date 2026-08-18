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

  return fetch(adres)
    .then(function (yanit) {
      if (!yanit.ok) return null;
      return yanit.json().then(firestoreBelgesi);
    })
    .catch(function () { return null; });
}
