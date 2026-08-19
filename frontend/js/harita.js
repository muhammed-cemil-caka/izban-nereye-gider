// Harita katmanı — Leaflet + OpenStreetMap döşemeleri.
//
// Döşeme sunucusu notu: tile.openstreetmap.org bağışlarla dönen bir altyapıdır
// ve kullanım politikası ağır/ticari kullanımı kısıtlar. Geliştirme ve düşük
// trafik için uygundur; yayına çıkarken anahtarlı bir sağlayıcıya ya da kendi
// sunduğumuz döşemelere geçilmelidir. Adres tek yerde tutulduğu için bu
// değişiklik bir satırdır.
var DOSEME_ADRESI = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
var DOSEME_KATKI =
  '© <a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noopener">OpenStreetMap</a> katkıcıları';

// Duraklar çizilene kadar geçerli olan başlangıç görünümü.
var IZMIR_MERKEZ = { enlem: 38.42, boylam: 27.14 };

var HAT_RENGI = '#7a8798';
var GUZERGAH_RENGI = '#0b5fa5';
var YURUYUS_RENGI = '#b3541e';

/**
 * Harita kurar ve üzerinde çalışacak küçük bir arayüz döndürür.
 * @param {string} elemanKimligi harita kabının id'si
 * @param {function} duragaTiklandi (durak) => void
 * @param {function} konumSuruklendi ({enlem, boylam}) => void
 */
function haritaKur(elemanKimligi, duragaTiklandi, konumSuruklendi) {
  var harita = L.map(elemanKimligi, {
    zoomControl: true,
    attributionControl: true
  });

  // Katman eklemeden önce bir görünüm ayarlanmalı: görünümsüz haritada Leaflet
  // piksel sınırlarını hesaplayamıyor ve döşeme katmanı hata veriyor.
  // Duraklar çizilince fitBounds bu görünümün yerini alır.
  harita.setView([IZMIR_MERKEZ.enlem, IZMIR_MERKEZ.boylam], 10);

  L.tileLayer(DOSEME_ADRESI, {
    maxZoom: 19,
    attribution: DOSEME_KATKI
  }).addTo(harita);

  var kap = document.getElementById(elemanKimligi);
  var bekleyenSinir = null;

  /** Kap ölçülebilir durumda mı? Gizli veya sıfır genişlikteyken hesap yapılamaz. */
  function kapOlculebilir() {
    return kap && kap.offsetWidth > 0 && kap.offsetHeight > 0;
  }

  /**
   * Sınırlara oturtur. Kap henüz ölçülemiyorsa istek saklanır ve boyut
   * geldiğinde uygulanır — sıfır boyutlu haritada fitBounds, Leaflet'in
   * piksel sınırı hesabını bozup hata fırlatıyor.
   */
  function sinirlaraOturt(sinir, dolgu) {
    if (!sinir || !sinir.isValid()) return;

    if (!kapOlculebilir()) {
      bekleyenSinir = { sinir: sinir, dolgu: dolgu };
      return;
    }
    bekleyenSinir = null;
    harita.fitBounds(sinir, { padding: dolgu });
  }

  function bekleyeniUygula() {
    harita.invalidateSize();
    if (bekleyenSinir && kapOlculebilir()) {
      var istek = bekleyenSinir;
      bekleyenSinir = null;
      harita.fitBounds(istek.sinir, { padding: istek.dolgu });
    }
  }

  var hatCizgisi = null;
  var guzergahCizgisi = null;
  var durakKatmani = L.layerGroup().addTo(harita);
  var konumIsareti = null;
  var yuruyusCizgisi = null;
  var durakIsaretleri = {};

  /** Tüm hattı ve durakları çizer. Yalnızca veri değiştiğinde çağrılır. */
  function duraklariCiz(duraklar) {
    durakKatmani.clearLayers();
    durakIsaretleri = {};

    var noktalar = duraklar
      .filter(function (d) { return d.konum && (d.konum.enlem || d.konum.boylam); })
      .map(function (d) { return [d.konum.enlem, d.konum.boylam]; });

    if (hatCizgisi) harita.removeLayer(hatCizgisi);
    hatCizgisi = L.polyline(noktalar, {
      color: HAT_RENGI, weight: 3, opacity: .55
    }).addTo(harita);

    duraklar.forEach(function (durak) {
      if (!durak.konum || (!durak.konum.enlem && !durak.konum.boylam)) return;

      var isaret = L.circleMarker([durak.konum.enlem, durak.konum.boylam], {
        radius: 5,
        color: HAT_RENGI,
        weight: 2,
        fillColor: '#ffffff',
        fillOpacity: 1
      });

      isaret.bindTooltip(durak.ad, { direction: 'top' });
      isaret.on('click', function () { duragaTiklandi(durak); });
      isaret.addTo(durakKatmani);

      durakIsaretleri[durak.kod] = isaret;
    });

    if (noktalar.length) sinirlaraOturt(hatCizgisi.getBounds(), [24, 24]);
  }

  /** Seçili yolculuğu vurgular: güzergâh çizgisi, biniş ve iniş işaretleri. */
  function guzergahiVurgula(sonuc) {
    Object.keys(durakIsaretleri).forEach(function (kod) {
      durakIsaretleri[kod].setStyle({
        radius: 5, color: HAT_RENGI, weight: 2, fillColor: '#ffffff'
      });
    });

    if (guzergahCizgisi) harita.removeLayer(guzergahCizgisi);
    if (!sonuc || !sonuc.gecerli) return;

    guzergahCizgisi = L.polyline(
      sonuc.guzergah
        .filter(function (d) { return d.konum; })
        .map(function (d) { return [d.konum.enlem, d.konum.boylam]; }),
      { color: GUZERGAH_RENGI, weight: 5, opacity: .9 }
    ).addTo(harita);

    ucNoktayiIsaretle(sonuc.binis.kod, '#0b7a63');
    ucNoktayiIsaretle(sonuc.inis.kod, '#b3541e');
  }

  function ucNoktayiIsaretle(kod, renk) {
    var isaret = durakIsaretleri[kod];
    if (isaret) {
      isaret.setStyle({ radius: 8, color: renk, weight: 3, fillColor: renk });
      isaret.bringToFront();
    }
  }

  /**
   * Kullanıcı konumunu sürüklenebilir bir işaretle gösterir.
   * Sürükleme, masaüstünde şaşan tarayıcı konumunu elle düzeltmenin en pratik yolu.
   */
  function konumuGoster(konum) {
    if (!konumIsareti) {
      konumIsareti = L.marker([konum.enlem, konum.boylam], {
        draggable: true,
        autoPan: true,
        title: 'Konumun — sürükleyerek düzeltebilirsin'
      }).addTo(harita);

      konumIsareti.bindTooltip('Buradasın · sürükleyebilirsin', { direction: 'top' });

      konumIsareti.on('dragend', function () {
        var yer = konumIsareti.getLatLng();
        konumSuruklendi({ enlem: yer.lat, boylam: yer.lng });
      });
    } else {
      konumIsareti.setLatLng([konum.enlem, konum.boylam]);
    }
  }

  /** Yürüyüş rotasını çizer ve görünür alana oturtur. */
  function yuruyusRotasiniCiz(noktalar) {
    yuruyusRotasiniTemizle();
    if (!noktalar || !noktalar.length) return;

    yuruyusCizgisi = L.polyline(noktalar, {
      color: YURUYUS_RENGI,
      weight: 5,
      opacity: .95,
      dashArray: '1 9',
      lineCap: 'round'
    }).addTo(harita);

    sinirlaraOturt(yuruyusCizgisi.getBounds(), [40, 40]);
  }

  function yuruyusRotasiniTemizle() {
    if (yuruyusCizgisi) {
      harita.removeLayer(yuruyusCizgisi);
      yuruyusCizgisi = null;
    }
  }

  function guzergahaOdaklan() {
    if (guzergahCizgisi) sinirlaraOturt(guzergahCizgisi.getBounds(), [32, 32]);
  }

  function konumaOdaklan(konum, yakinlik) {
    harita.setView([konum.enlem, konum.boylam], yakinlik || 14);
  }

  /** Kap boyutu değiştiğinde çağrılmalı. */
  function boyutuTazele() {
    harita.invalidateSize();
  }

  // Kap, harita kurulduktan sonra yeniden boyutlanabiliyor (pencere değişimi,
  // yazı tipi yüklenmesi, kartın geç yerleşmesi). Leaflet bunu kendiliğinden
  // fark etmiyor; eski ölçüyle çalışıp döşemeleri eksik bırakıyor.
  if (typeof ResizeObserver === 'function') {
    var gozlemci = new ResizeObserver(bekleyeniUygula);
    gozlemci.observe(kap);
  } else {
    window.addEventListener('resize', bekleyeniUygula);
  }

  // İlk yerleşim tamamlandıktan sonra bir kez daha ölç.
  setTimeout(bekleyeniUygula, 0);

  return {
    yuruyusRotasiniCiz: yuruyusRotasiniCiz,
    yuruyusRotasiniTemizle: yuruyusRotasiniTemizle,
    duraklariCiz: duraklariCiz,
    guzergahiVurgula: guzergahiVurgula,
    konumuGoster: konumuGoster,
    guzergahaOdaklan: guzergahaOdaklan,
    konumaOdaklan: konumaOdaklan,
    boyutuTazele: boyutuTazele
  };
}
