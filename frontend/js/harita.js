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
    attributionControl: true,
    // leaflet-rotate: haritayı gidiş yönüne çevirebilmek için.
    // Leaflet bunu yerleşik desteklemiyor.
    rotate: true,
    bearing: 0,
    touchRotate: false,
    shiftKeyRotate: false
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
  var konumIsaretiYonlendirmede = false;
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

  var basiliTutmaSayaci = null;
  var BASILI_TUTMA_MS = 2000;

  /** Basılı tutarken bu kadar pikselden fazla kayma, haritayı kaydırmaktır. */
  var BASILI_TUTMA_KAYMASI_PX = 14;

  /**
   * İşareti 2 saniye basılı tutunca taşınabilir yapar.
   *
   * Taşımanın sürekli açık olması, haritayı kaydırırken parmağın işarete
   * değmesiyle konumun yanlışlıkla değişmesine yol açıyordu.
   *
   * Leaflet'in kendi sürüklemesi kullanılmıyor: `marker.dragging.enable()`
   * yalnızca BUNDAN SONRAKİ basışı yakalıyor. İki saniye dolduğunda parmak
   * çoktan basılı olduğu için sürükleme o hareket boyunca hiç başlamıyordu —
   * "basılı tutunca yeri değişmiyor" bunun sonucuydu. Taşıma bu yüzden
   * pointer olaylarıyla elle yürütülüyor.
   */
  function basiliTutmayiBagla(isaret) {
    var eleman = isaret.getElement();
    if (!eleman) return;

    // Basılı tutarken parmak oynayınca sayfa kaymasın.
    eleman.style.touchAction = 'none';

    var isaretciKimligi = null;
    var basmaNoktasi = null;      // basıldığı andaki kap noktası
    var sonNokta = null;
    var baslangicNoktasi = null;  // taşımanın açıldığı andaki kap noktası
    var baslangicKonumu = null;   // iğnenin o andaki coğrafi konumu
    var tasimaAktif = false;
    var igneOynadi = false;

    function kapNoktasi(olay) {
      return harita.mouseEventToContainerPoint(olay);
    }

    /**
     * Parmağın kat ettiği yolu iğnenin başlangıç konumuna uygular.
     *
     * Parmağın altındaki nokta doğrudan alınmıyor, FARK uygulanıyor:
     * kullanıcı iğneyi neresinden tuttuysa orası parmağın altında kalır.
     */
    function tasinanKonum(nokta) {
      var baslangicEkran = harita.latLngToContainerPoint(baslangicKonumu);
      return harita.containerPointToLatLng(
        baslangicEkran.add(nokta.subtract(baslangicNoktasi))
      );
    }

    function bas(olay) {
      if (olay.button === 2) return; // sağ tık
      birak();

      isaretciKimligi = olay.pointerId;
      basmaNoktasi = kapNoktasi(olay);
      sonNokta = basmaNoktasi;

      // İşaretçi yakalanır: iğne parmağın altından kaysa da olaylar gelmeye
      // devam etsin.
      try {
        if (eleman.setPointerCapture) eleman.setPointerCapture(olay.pointerId);
      } catch (sorun) { /* yakalanamayan işaretçi: olaylar yine de gelir */ }

      basiliTutmaSayaci = setTimeout(function () {
        tasimaAktif = true;
        igneOynadi = false;
        baslangicNoktasi = sonNokta;
        baslangicKonumu = isaret.getLatLng();
        eleman.classList.add('konum-isareti--hazir');
        // Taşıma sırasında harita parmakla birlikte kaymasın.
        harita.dragging.disable();
        if (navigator.vibrate) navigator.vibrate(30);
      }, BASILI_TUTMA_MS);
    }

    function oynat(olay) {
      if (olay.pointerId !== isaretciKimligi) return;
      sonNokta = kapNoktasi(olay);

      if (!tasimaAktif) {
        // Parmak kayıyorsa kullanıcı haritayı kaydırmak istiyordur.
        if (sonNokta.distanceTo(basmaNoktasi) > BASILI_TUTMA_KAYMASI_PX) birak();
        return;
      }

      olay.preventDefault();
      igneOynadi = true;
      isaret.setLatLng(tasinanKonum(sonNokta));
    }

    function kaldir(olay) {
      if (olay.pointerId !== isaretciKimligi) return;

      var tasindi = tasimaAktif && igneOynadi;
      var yer = isaret.getLatLng();
      birak();

      // Yalnızca gerçekten taşındıysa bildir: iki saniye basıp bırakmak
      // konumu değiştirmemeli.
      if (tasindi) konumSuruklendi({ enlem: yer.lat, boylam: yer.lng });
    }

    function birak() {
      clearTimeout(basiliTutmaSayaci);
      basiliTutmaSayaci = null;
      if (tasimaAktif) harita.dragging.enable();

      isaretciKimligi = null;
      basmaNoktasi = null;
      sonNokta = null;
      baslangicNoktasi = null;
      baslangicKonumu = null;
      tasimaAktif = false;
      igneOynadi = false;
      eleman.classList.remove('konum-isareti--hazir');
    }

    eleman.addEventListener('pointerdown', bas);
    eleman.addEventListener('pointermove', oynat);
    eleman.addEventListener('pointerup', kaldir);
    eleman.addEventListener('pointercancel', function (olay) {
      if (olay.pointerId === isaretciKimligi) birak();
    });
  }

  /**
   * Yönlendirme sırasında kullanılan yön oku. Normal iğne yerine, hareket
   * yönüne dönen bir ok gösterilir — kullanıcı nereye baktığını görsün.
   */
  function yonOkuSimgesi(aci) {
    return L.divIcon({
      className: 'konum-oku',
      iconSize: [34, 34],
      iconAnchor: [17, 17],
      html:
        '<div class="konum-oku-govde" style="transform: rotate(' + (aci || 0) + 'deg)">' +
        '<svg viewBox="0 0 24 24" width="20" height="20" aria-hidden="true">' +
        '<path d="M12 2 L19 21 L12 16.5 L5 21 Z" fill="currentColor"/>' +
        '</svg></div>'
    });
  }

  /**
   * Kullanıcı konumunu gösterir.
   *
   * Normalde sürüklenebilir bir iğnedir — masaüstünde şaşan tarayıcı konumunu
   * elle düzeltmenin en pratik yolu. Yönlendirme sırasında yön okuna dönüşür ve
   * sürüklenemez olur; yürürken yanlışlıkla taşınmasın.
   *
   * @param {object} konum
   * @param {object} [secenekler] {yonlendirme: boolean, aci: number}
   */
  function konumuGoster(konum, secenekler) {
    var yonlendirmede = Boolean(secenekler && secenekler.yonlendirme);
    sonGosterilenKonum = { enlem: konum.enlem, boylam: konum.boylam };
    konumaDonGorunurlugunuTazele();
    var aci = secenekler && typeof secenekler.aci === 'number' ? secenekler.aci : 0;

    // Mod değiştiyse işaret baştan kurulur: Leaflet'te bir işaretin
    // sürüklenebilirliği ve simgesi sonradan güvenle değiştirilemiyor.
    if (konumIsareti && konumIsaretiYonlendirmede !== yonlendirmede) {
      harita.removeLayer(konumIsareti);
      konumIsareti = null;
    }

    if (!konumIsareti) {
      konumIsareti = L.marker([konum.enlem, konum.boylam], {
        // Sürükleme kapalı başlar; 2 saniye basılı tutunca açılır. Sürekli
        // açık olması, haritayı kaydırırken yanlışlıkla taşımaya yol açıyordu.
        draggable: false,
        autoPan: !yonlendirmede,
        icon: yonlendirmede ? yonOkuSimgesi(aci) : new L.Icon.Default(),
        title: yonlendirmede
          ? 'Konumun'
          : 'Konumun — yerini düzeltmek için 2 saniye basılı tut'
      }).addTo(harita);

      konumIsareti.bindTooltip(
        yonlendirmede ? 'Buradasın' : 'Buradasın · düzeltmek için 2 sn basılı tut',
        { direction: 'top' }
      );

      if (!yonlendirmede) basiliTutmayiBagla(konumIsareti);

      konumIsaretiYonlendirmede = yonlendirmede;
    } else {
      konumIsareti.setLatLng([konum.enlem, konum.boylam]);

      // Okun yönünü döndürmek için simgeyi yeniden kurmaya gerek yok.
      if (yonlendirmede) {
        var govde = konumIsareti.getElement() &&
                    konumIsareti.getElement().querySelector('.konum-oku-govde');
        if (govde) govde.style.transform = 'rotate(' + aci + 'deg)';
      }
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

  /* ---------- Yön ---------- */

  var hedefAci = null;
  var mevcutAci = null;
  var takipKaresi = null;
  var DONUS_ESIGI_DERECE = 8;
  var DONUS_HIZI = 4.0;

  /**
   * Haritayı gidiş yönüne çevirir: kullanıcının baktığı yön yukarı bakar.
   * Mobildeki davranışın aynısı.
   */
  function haritayiYoneCevir(aci) {
    if (typeof aci !== 'number' || !harita.setBearing) return;

    if (mevcutAci !== null) {
      var fark = (aci - hedefAci + 540) % 360 - 180;
      if (hedefAci !== null && Math.abs(fark) < DONUS_ESIGI_DERECE) return;
    }

    hedefAci = aci;
    if (mevcutAci === null) {
      mevcutAci = aci;
      harita.setBearing(-aci);
      return;
    }
    donusuCalistir();
  }

  /** Üstel yumuşatma: hedef değişse de dönüş hızı korunur, takılma olmaz. */
  function donusuCalistir() {
    if (takipKaresi !== null) return;

    var sonZaman = null;

    function kare(zaman) {
      var dt = sonZaman === null ? 1 / 60 : (zaman - sonZaman) / 1000;
      sonZaman = zaman;

      var fark = (hedefAci - mevcutAci + 540) % 360 - 180;
      var k = 1 - Math.exp(-DONUS_HIZI * dt);
      mevcutAci = (mevcutAci + fark * k + 360) % 360;
      harita.setBearing(-mevcutAci);

      if (Math.abs(fark) > 0.3) {
        takipKaresi = requestAnimationFrame(kare);
      } else {
        takipKaresi = null;
      }
    }

    takipKaresi = requestAnimationFrame(kare);
  }

  function haritayiKuzeyeAl() {
    if (takipKaresi !== null) cancelAnimationFrame(takipKaresi);
    takipKaresi = null;
    hedefAci = null;
    mevcutAci = null;
    if (harita.setBearing) harita.setBearing(0);
  }

  function guzergahaOdaklan() {
    if (guzergahCizgisi) sinirlaraOturt(guzergahCizgisi.getBounds(), [32, 32]);
  }

  // Kullanıcı uzaklaştırdıysa yakınlaştırmasını zorla değiştirme.
  var KAMERA_ESIGI_M = 8;
  var sonKameraHedefi = null;

  function konumaOdaklan(konum, yakinlik) {
    // GPS dururken bile birkaç metre oynuyor; her ölçümde kamerayı taşımak
    // haritayı sürekli ileri geri kaydırıyor (mobildeki eşik ile aynı).
    if (sonKameraHedefi &&
        metreUzaklik(konum, sonKameraHedefi) < KAMERA_ESIGI_M) {
      return;
    }
    sonKameraHedefi = { enlem: konum.enlem, boylam: konum.boylam };

    var hedefYakinlik = yakinlik || 14;
    if (harita.getZoom() > hedefYakinlik) hedefYakinlik = harita.getZoom();

    harita.setView([konum.enlem, konum.boylam], hedefYakinlik, {
      animate: true,
      duration: 1.2,
      easeLinearity: 0.2
    });
  }

  /* ---------- Konuma dön ---------- */

  var sonGosterilenKonum = null;
  var konumaDonDenetimi = null;

  /**
   * Haritanın köşesinde duran "konumuma dön" düğmesi.
   *
   * Kullanıcı hattın başka bir yerine bakmak için haritayı kaydırdığında
   * konumuna dönmek için geri kaydırmak zorunda kalmasın.
   */
  function konumaDonDugmesiniKur() {
    var Dugme = L.Control.extend({
      options: { position: 'topright' },
      onAdd: function () {
        var kutu = L.DomUtil.create('div', 'leaflet-bar konuma-don');
        var baglanti = L.DomUtil.create('a', '', kutu);

        baglanti.href = '#';
        baglanti.title = 'Konumuma dön';
        baglanti.setAttribute('role', 'button');
        baglanti.setAttribute('aria-label', 'Konumuma dön');
        baglanti.innerHTML =
          '<svg viewBox="0 0 24 24" width="16" height="16" aria-hidden="true">' +
          '<path d="M12 1v4M12 19v4M1 12h4M19 12h4" stroke="currentColor" ' +
          'stroke-width="2" stroke-linecap="round" fill="none"/>' +
          '<circle cx="12" cy="12" r="6" stroke="currentColor" stroke-width="2" fill="none"/>' +
          '<circle cx="12" cy="12" r="2.2" fill="currentColor"/></svg>';

        // Konum bilinmiyorsa dönülecek yer de yok.
        kutu.style.display = sonGosterilenKonum ? '' : 'none';

        L.DomEvent.disableClickPropagation(kutu);
        L.DomEvent.on(baglanti, 'click', function (olay) {
          L.DomEvent.stop(olay);
          konumaGeriDon();
        });

        return kutu;
      }
    });

    konumaDonDenetimi = new Dugme();
    konumaDonDenetimi.addTo(harita);
  }

  function konumaDonGorunurlugunuTazele() {
    var kutu = konumaDonDenetimi && konumaDonDenetimi.getContainer();
    if (kutu) kutu.style.display = sonGosterilenKonum ? '' : 'none';
  }

  /** Kamerayı kullanıcının konumuna geri getirir. */
  function konumaGeriDon() {
    if (!sonGosterilenKonum) return;

    // Gürültü eşiği yalnızca kendiliğinden gelen ölçümler içindir; düğmeye
    // basıldığında kamera her hâlükârda konuma dönmeli.
    sonKameraHedefi = null;
    konumaOdaklan(sonGosterilenKonum, 16);
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

  konumaDonDugmesiniKur();

  // İlk yerleşim tamamlandıktan sonra bir kez daha ölç.
  setTimeout(bekleyeniUygula, 0);

  return {
    haritayiYoneCevir: haritayiYoneCevir,
    haritayiKuzeyeAl: haritayiKuzeyeAl,
    yuruyusRotasiniCiz: yuruyusRotasiniCiz,
    yuruyusRotasiniTemizle: yuruyusRotasiniTemizle,
    duraklariCiz: duraklariCiz,
    guzergahiVurgula: guzergahiVurgula,
    konumuGoster: konumuGoster,
    guzergahaOdaklan: guzergahaOdaklan,
    konumaOdaklan: konumaOdaklan,
    konumaGeriDon: konumaGeriDon,
    boyutuTazele: boyutuTazele
  };
}
