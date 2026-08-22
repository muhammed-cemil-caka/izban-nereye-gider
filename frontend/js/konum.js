// Tarayıcı konum servisi sarmalayıcısı.
//
// Not: Geolocation API yalnızca güvenli bağlamda çalışır — https:// veya
// localhost. file:// veya düz http:// üzerinden açıldığında tarayıcı isteği
// sessizce reddeder, o yüzden durum ayrıca kontrol ediliyor.

// Tek bir getCurrentPosition çağrısı çoğu zaman ilk gelen kaba konumu döndürür
// (Wi-Fi/IP tabanlı, kilometrelerce sapabilir). Bunun yerine watchPosition ile
// konum akışı dinlenip en iyi ölçüm tutuluyor: ya hedef doğruluğa ulaşılır ya da
// süre dolunca eldeki en iyisi kullanılır.
var HEDEF_DOGRULUK_M = 30;    // bu doğruluğa inince izlemeyi bitir
var ILK_SONUC_SURESI_MS = 6000; // bu süre sonunda eldeki en iyi ölçüm gösterilir
var IZLEME_SURESI_MS = 45000; // konumu iyileştirmek için toplam izleme süresi
var BEKCI_SURESI_MS = 15000;  // hiçbir ölçüm gelmezse pes etme süresi

/**
 * Tarayıcı konum desteği ve güvenli bağlam kontrolü.
 *
 * Hazır metin değil SÖZLÜK ANAHTARI döner: hata satırı ekranda dururken
 * kullanıcı dili değiştirebiliyor, arayüz onu yeniden çevirebilsin.
 */
function konumDesteklenirMi() {
  if (!('geolocation' in navigator)) {
    return { destekli: false, sebep: 'konumDesteklenmiyor' };
  }
  if (!window.isSecureContext) {
    return { destekli: false, sebep: 'konumGuvenliBaglam' };
  }
  return { destekli: true };
}

/**
 * Konumu izlemeye devam ederek zamanla iyileştirir.
 *
 * Tek ölçümle yetinmek masaüstünde büyük sapmalara yol açıyor: ilk gelen Wi-Fi
 * tabanlı konum yüzlerce metre şaşabiliyor. Burada izleme açık tutulup her
 * daha isabetli ölçümde geri çağrı tetikleniyor — böylece konum, Google
 * Haritalar'ın mavi noktası gibi, zamanla toparlanıyor.
 *
 * @param {function} olcumGeldi  her iyileşmede çağrılır: (konum, kesinMi)
 * @param {function} hataOldu    kalıcı hatada çağrılır: (sozlukAnahtari)
 * @returns {function} izlemeyi erken durdurmak için çağrılacak fonksiyon
 */
function konumIzle(olcumGeldi, hataOldu) {
  var durum = konumDesteklenirMi();
  if (!durum.destekli) {
    hataOldu(durum.sebep);
    return function () {};
  }

  var enIyi = null;
  var izleyici = null;
  var ilkSonucSayaci = null;
  var izlemeSayaci = null;
  var bekciSayaci = null;
  var ilkSonucVerildi = false;
  var bitti = false;

  function durdur() {
    if (bitti) return;
    bitti = true;
    if (izleyici !== null) navigator.geolocation.clearWatch(izleyici);
    clearTimeout(ilkSonucSayaci);
    clearTimeout(izlemeSayaci);
    clearTimeout(bekciSayaci);
  }

  function bildir(kesinMi) {
    if (enIyi) olcumGeldi(enIyi, kesinMi);
  }

  izleyici = navigator.geolocation.watchPosition(
    function (sonuc) {
      var olcum = {
        enlem: sonuc.coords.latitude,
        boylam: sonuc.coords.longitude,
        dogrulukM: sonuc.coords.accuracy
      };

      // Yalnızca daha isabetli ölçümler eskisinin yerini alır.
      if (enIyi && olcum.dogrulukM >= enIyi.dogrulukM) return;
      enIyi = olcum;

      // Hedefe ulaşıldıysa izlemeye gerek yok.
      if (olcum.dogrulukM <= HEDEF_DOGRULUK_M) {
        ilkSonucVerildi = true;
        durdur();
        bildir(true);
        return;
      }

      // İlk sonuç verildikten sonraki her iyileşme arayüze yansıtılır.
      if (ilkSonucVerildi) bildir(false);
    },
    function (hata) {
      if (bitti) return;
      durdur();
      hataOldu(konumHatasiniAcikla(hata));
    },
    { enableHighAccuracy: true, timeout: BEKCI_SURESI_MS, maximumAge: 0 }
  );

  // Hedefe ulaşılmasa bile kullanıcı sonsuza kadar beklemesin.
  ilkSonucSayaci = setTimeout(function () {
    if (enIyi && !ilkSonucVerildi) {
      ilkSonucVerildi = true;
      bildir(false);
    }
  }, ILK_SONUC_SURESI_MS);

  // İyileştirme sonsuza kadar sürmesin; pil ve gereksiz iş.
  izlemeSayaci = setTimeout(function () {
    durdur();
    bildir(true);
  }, IZLEME_SURESI_MS);

  // Tarayıcı hiçbir geri çağrı yapmazsa arayüz asılı kalmasın.
  bekciSayaci = setTimeout(function () {
    if (!enIyi) {
      durdur();
      hataOldu('konumYanitVermedi');
    }
  }, BEKCI_SURESI_MS + 2000);

  return durdur;
}

/** Tarayıcı hata koduna karşılık gelen sözlük anahtarı. */
function konumHatasiniAcikla(hata) {
  switch (hata.code) {
    case hata.PERMISSION_DENIED:
      return 'konumIzniYok';
    case hata.POSITION_UNAVAILABLE:
      return 'konumBilgisiYok';
    case hata.TIMEOUT:
      return 'konumZamanAsimi';
    default:
      return 'konumAlinamadi';
  }
}
/* ---------- Elle konum düzeltme ---------- */
//
// Masaüstünde tarayıcı konumu Wi-Fi tabanlıdır ve yüzlerce metre şaşabilir.
// Kullanıcı kendi yerini arayarak düzeltebilsin diye Nominatim kullanılıyor:
// ücretsiz, anahtar gerektirmiyor, durak verisini üretirken de aynı servisi
// kullanıyoruz. Sonuçlar İzmir çevresiyle sınırlanır.

var NOMINATIM_ARAMA = 'https://nominatim.openstreetmap.org/search';
var IZMIR_KUTUSU = '26.8,39.0,27.7,37.8'; // lon_min, lat_max, lon_max, lat_min

/**
 * Yer adı arar.
 * @returns {Promise<Array<{ad: string, enlem: number, boylam: number}>>}
 */
function yerAra(sorgu) {
  var temiz = String(sorgu || '').trim();
  if (temiz.length < 3) return Promise.resolve([]);

  var adres = NOMINATIM_ARAMA +
    '?format=jsonv2&limit=5&countrycodes=tr&bounded=1' +
    '&viewbox=' + IZMIR_KUTUSU +
    '&q=' + encodeURIComponent(temiz);

  return fetch(adres, { headers: { 'Accept': 'application/json' } })
    .then(function (yanit) {
      if (!yanit.ok) throw new Error(ceviriMetni('aramaBasarisiz', { kod: yanit.status }));
      return yanit.json();
    })
    .then(function (sonuclar) {
      return (sonuclar || []).map(function (s) {
        return {
          ad: s.display_name,
          enlem: parseFloat(s.lat),
          boylam: parseFloat(s.lon)
        };
      });
    });
}

/* ---------- Sürekli takip ---------- */
//
// konumIzle() ilk isabetli ölçümde durur; bu, açılışta hızlı sonuç vermek için
// doğru ama işaretin donmasına yol açıyor. Takip modu daha düşük maliyetle
// açık kalır ve kullanıcı hareket ettikçe konumu tazeler. Yönlendirme kendi
// akışını kullandığı için takip o sırada durdurulur.

var TAKIP_ESIGI_M = 20; // bu kadar hareket etmeden arayüz güncellenmez

/**
 * Konumu düşük maliyetle izlemeye devam eder.
 * @param {function} olcumGeldi (konum) => void
 * @returns {function} takibi durduran fonksiyon
 */
function konumTakibiBaslat(olcumGeldi) {
  var durum = konumDesteklenirMi();
  if (!durum.destekli) return function () {};

  var sonBildirilen = null;

  var izleyici = navigator.geolocation.watchPosition(
    function (sonuc) {
      var konum = {
        enlem: sonuc.coords.latitude,
        boylam: sonuc.coords.longitude,
        dogrulukM: sonuc.coords.accuracy
      };

      // Küçük dalgalanmalarda arayüzü boş yere güncelleme.
      if (sonBildirilen) {
        var p = Math.PI / 180;
        var dx = (konum.boylam - sonBildirilen.boylam) * 111320 * Math.cos(konum.enlem * p);
        var dy = (konum.enlem - sonBildirilen.enlem) * 110574;
        if (Math.sqrt(dx * dx + dy * dy) < TAKIP_ESIGI_M) return;
      }

      sonBildirilen = konum;
      olcumGeldi(konum);
    },
    function () { /* takip sessizce durur, açılıştaki hata zaten gösterildi */ },
    // Takipte yüksek isabet istenmiyor: pil ömrü, açılış ölçümünden daha önemli.
    { enableHighAccuracy: false, maximumAge: 10000, timeout: 30000 }
  );

  return function () { navigator.geolocation.clearWatch(izleyici); };
}

/* ---------- Pusula ---------- */
//
// Telefon çevrildiğinde harita da dönsün diye cihaz yönü dinlenir. iOS 13+
// izin ister; izin verilmezse hareket yönüne düşülür (mobildeki davranışın
// aynısı).

/**
 * Pusulayı dinler.
 * @param {function} aciGeldi (derece) => void
 * @returns {function} dinlemeyi durduran fonksiyon
 */
function pusulayiDinle(aciGeldi) {
  var sonAci = null;

  function isle(olay) {
    var aci = null;

    // iOS kendi mutlak başlığını verir; diğerleri alpha üzerinden.
    if (typeof olay.webkitCompassHeading === 'number') {
      aci = olay.webkitCompassHeading;
    } else if (olay.absolute && typeof olay.alpha === 'number') {
      aci = 360 - olay.alpha;
    }

    if (aci === null || isNaN(aci)) return;
    aci = (aci + 360) % 360;

    // Küçük sapmalarda haber verme; ok ve harita titremesin.
    if (sonAci !== null) {
      var fark = (aci - sonAci + 540) % 360 - 180;
      if (Math.abs(fark) < 4) return;
    }

    sonAci = aci;
    aciGeldi(aci);
  }

  var olayAdi = 'ondeviceorientationabsolute' in window
    ? 'deviceorientationabsolute'
    : 'deviceorientation';

  function bagla() {
    window.addEventListener(olayAdi, isle);
  }

  // iOS 13+ açık izin istiyor; kullanıcı etkileşimi olmadan reddedilebilir.
  if (typeof DeviceOrientationEvent !== 'undefined' &&
      typeof DeviceOrientationEvent.requestPermission === 'function') {
    DeviceOrientationEvent.requestPermission()
      .then(function (sonuc) { if (sonuc === 'granted') bagla(); })
      .catch(function () { /* izin yok: hareket yönü kullanılır */ });
  } else {
    bagla();
  }

  return function () { window.removeEventListener(olayAdi, isle); };
}
