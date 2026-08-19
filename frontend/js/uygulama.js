// Arayüz katmanı — hesaplama için hesap.js, veri için duraklar.js kullanılır.
(function () {
  'use strict';

  var BINIS_ANAHTAR = 'izban.binis';
  var INIS_ANAHTAR = 'izban.inis';
  var TEMA_ANAHTAR = 'izban.tema';

  // Gösterimde kullanılan veri. Sayfa yerel kopyayla anında açılır; Firestore
  // yanıtı gelince bununla değiştirilip arayüz yeniden çizilir.
  var aktifDuraklar = DURAKLAR;

  var oge = {
    binis: document.getElementById('binisSecim'),
    inis: document.getElementById('inisSecim'),
    tersCevir: document.getElementById('tersCevirDugmesi'),
    hata: document.getElementById('hataMesaji'),
    sonuc: document.getElementById('sonucBolumu'),
    yonRozeti: document.getElementById('yonRozeti'),
    sure: document.getElementById('sureDegeri'),
    durak: document.getElementById('durakDegeri'),
    aktarmaSayisi: document.getElementById('aktarmaDegeri'),
    ozetCumle: document.getElementById('ozetCumle'),
    hatSemasi: document.getElementById('hatSemasi'),
    aktarmaKarti: document.getElementById('aktarmaKarti'),
    aktarmaListesi: document.getElementById('aktarmaListesi'),
    veriSurumu: document.getElementById('veriSurumu'),
    veriKaynagi: document.getElementById('veriKaynagi'),
    konumKarti: document.getElementById('konumKarti'),
    konumMetni: document.getElementById('konumMetni'),
    konumSonucu: document.getElementById('konumSonucu'),
    yakinDurakAd: document.getElementById('yakinDurakAd'),
    yakinDurakMesafe: document.getElementById('yakinDurakMesafe'),
    binisYap: document.getElementById('binisYapDugmesi'),
    yolTarifi: document.getElementById('yolTarifiBaglantisi'),
    konumTekrar: document.getElementById('konumTekrarDugmesi'),
    binisYolTarifi: document.getElementById('binisYolTarifi'),
    konumDogruluk: document.getElementById('konumDogruluk'),
    konumAlternatif: document.getElementById('konumAlternatif'),
    konumAlternatifListe: document.getElementById('konumAlternatifListe'),
    konumArama: document.getElementById('konumArama'),
    konumAramaDurum: document.getElementById('konumAramaDurum'),
    konumAramaListe: document.getElementById('konumAramaListe'),
    tema: document.getElementById('temaDugmesi')
  };

  /* ---------- Tema ---------- */

  function temayiUygula(tema) {
    document.documentElement.setAttribute('data-tema', tema);
    try { localStorage.setItem(TEMA_ANAHTAR, tema); } catch (e) { /* özel mod */ }
  }

  function temayiBaslat() {
    var kayitli = null;
    try { kayitli = localStorage.getItem(TEMA_ANAHTAR); } catch (e) { /* özel mod */ }
    if (kayitli) document.documentElement.setAttribute('data-tema', kayitli);

    oge.tema.addEventListener('click', function () {
      var suanki = document.documentElement.getAttribute('data-tema');
      if (!suanki) {
        var sistemKoyu = window.matchMedia('(prefers-color-scheme: dark)').matches;
        suanki = sistemKoyu ? 'koyu' : 'acik';
      }
      temayiUygula(suanki === 'koyu' ? 'acik' : 'koyu');
    });
  }

  /* ---------- Durak listeleri ---------- */

  function secimleriDoldur() {
    [oge.binis, oge.inis].forEach(function (secim) {
      secim.textContent = '';
      aktifDuraklar.forEach(function (durak) {
        var secenek = document.createElement('option');
        secenek.value = durak.kod;
        secenek.textContent = durak.ad;
        secim.appendChild(secenek);
      });
    });
  }

  function baslangicSeciminiYukle() {
    var kayitliBinis = null, kayitliInis = null;
    try {
      kayitliBinis = localStorage.getItem(BINIS_ANAHTAR);
      kayitliInis = localStorage.getItem(INIS_ANAHTAR);
    } catch (e) { /* özel mod */ }

    var kodlar = aktifDuraklar.map(function (d) { return d.kod; });
    oge.binis.value = kodlar.indexOf(kayitliBinis) !== -1 ? kayitliBinis : 'halkapinar';
    oge.inis.value = kodlar.indexOf(kayitliInis) !== -1 ? kayitliInis : 'havalimani';

    // Kayıtlı değerler aynıysa iniş durağını kaydır.
    if (oge.binis.value === oge.inis.value) {
      var indeks = kodlar.indexOf(oge.binis.value);
      oge.inis.value = kodlar[(indeks + 1) % kodlar.length];
    }
  }

  function secimiKaydet() {
    try {
      localStorage.setItem(BINIS_ANAHTAR, oge.binis.value);
      localStorage.setItem(INIS_ANAHTAR, oge.inis.value);
    } catch (e) { /* özel mod */ }
  }

  /* ---------- Çizim ---------- */

  function hatSemasiniCiz(sonuc) {
    oge.hatSemasi.textContent = '';
    sonuc.guzergah.forEach(function (durak, sira) {
      var ucNokta = sira === 0 || sira === sonuc.guzergah.length - 1;

      var satir = document.createElement('li');
      satir.className = 'hat-durak' + (ucNokta ? ' hat-durak--uc' : '');

      var ad = document.createElement('span');
      ad.className = 'hat-durak-ad';
      ad.textContent = durak.ad;
      satir.appendChild(ad);

      var ilce = document.createElement('span');
      ilce.className = 'hat-durak-ilce';
      ilce.textContent = durak.ilce;
      satir.appendChild(ilce);

      if (sira === 0) satir.appendChild(rozetYap('BİNİŞ'));
      if (sira === sonuc.guzergah.length - 1) satir.appendChild(rozetYap('İNİŞ'));
      if (durak.aktarma && durak.aktarma.length) satir.appendChild(rozetYap('AKTARMA'));

      oge.hatSemasi.appendChild(satir);
    });
  }

  function rozetYap(metin) {
    var rozet = document.createElement('span');
    rozet.className = 'rozet';
    rozet.textContent = metin;
    return rozet;
  }

  function aktarmalariCiz(sonuc) {
    oge.aktarmaListesi.textContent = '';
    if (!sonuc.aktarmalar.length) {
      oge.aktarmaKarti.hidden = true;
      return;
    }
    sonuc.aktarmalar.forEach(function (aktarma) {
      var satir = document.createElement('li');

      var ad = document.createElement('strong');
      ad.textContent = aktarma.ad;
      satir.appendChild(ad);

      var hatlar = document.createElement('span');
      hatlar.className = 'aktarma-hatlar';
      hatlar.textContent = aktarma.hatlar.join(' · ');
      satir.appendChild(hatlar);

      oge.aktarmaListesi.appendChild(satir);
    });
    oge.aktarmaKarti.hidden = false;
  }

  function sonucuGoster(sonuc) {
    oge.yonRozeti.textContent = sonuc.yonEtiketi;
    oge.yonRozeti.setAttribute('data-yon', sonuc.yon);
    oge.sure.textContent = sonuc.sureMetni;
    oge.durak.textContent = sonuc.durakSayisi;
    oge.aktarmaSayisi.textContent = sonuc.aktarmalar.length;
    oge.ozetCumle.textContent =
      sonuc.binis.ad + ' durağından bindin: ' + sonuc.yonEtiketi + 'ndeki trene binmelisin. ' +
      sonuc.durakSayisi + ' durak sonra, yaklaşık ' + sonuc.sureMetni + ' içinde ' +
      sonuc.inis.ad + ' durağındasın.';

    hatSemasiniCiz(sonuc);
    aktarmalariCiz(sonuc);

    oge.hata.hidden = true;
    oge.sonuc.hidden = false;
  }

  /** Seçili biniş durağına yürüyerek yol tarifi bağlantısını tazeler. */
  function binisYolTarifiniGuncelle(durak) {
    if (!durak.konum || (!durak.konum.enlem && !durak.konum.boylam)) {
      oge.binisYolTarifi.hidden = true;
      return;
    }
    oge.binisYolTarifi.hidden = false;
    oge.binisYolTarifi.href = yolTarifiAdresi(durak);
    oge.binisYolTarifi.textContent = durak.ad + ' durağına yol tarifi →';
  }

  function hataGoster(mesaj) {
    oge.hata.textContent = mesaj;
    oge.hata.hidden = false;
    oge.sonuc.hidden = true;
  }

  /* ---------- Konum ---------- */

  var yakinDurak = null;

  function konumDurumunuYaz(metin, durum) {
    oge.konumMetni.textContent = metin;
    oge.konumKarti.setAttribute('data-durum', durum);
    oge.konumSonucu.hidden = durum !== 'hazir';
    oge.konumTekrar.hidden = durum !== 'hata';
  }

  // Bu değerin üstündeki doğruluklarda en yakın durak yanılabilir; kullanıcı uyarılır.
  var KABA_KONUM_ESIGI_M = 200;

  // Konumdan hesaplanan, mesafeye göre sıralı tam aday listesi. Kullanıcı
  // alternatiflerden birini seçtiğinde de bu sıra korunur.
  var tumAdaylar = [];

  function yakinDuragiGoster(adaylar, dogrulukM, kesinMi) {
    var enYakin = adaylar[0];
    yakinDurak = enYakin.durak;

    oge.yakinDurakAd.textContent = enYakin.durak.ad;
    oge.yakinDurakMesafe.textContent = mesafeBicimle(enYakin.mesafeM);
    oge.yolTarifi.href = yolTarifiAdresi(enYakin.durak);
    oge.yolTarifi.setAttribute(
      'aria-label',
      enYakin.durak.ad + ' durağına yürüyerek yol tarifi (Google Haritalar\'da açılır)'
    );

    dogruluguYaz(dogrulukM, kesinMi);
    alternatifleriYaz(adaylar.slice(1));

    konumDurumunuYaz('', 'hazir');
  }

  function dogruluguYaz(dogrulukM, kesinMi) {
    if (dogrulukM === null) {
      // Elle girilen konum: doğruluk kavramı geçerli değil.
      oge.konumDogruluk.setAttribute('data-kaba', 'hayir');
      oge.konumDogruluk.textContent = 'Konum senin girdiğin yere göre hesaplandı.';
      return;
    }

    var kaba = dogrulukM > KABA_KONUM_ESIGI_M;
    oge.konumDogruluk.setAttribute('data-kaba', kaba ? 'evet' : 'hayir');

    var metin = kaba
      ? 'Konum ±' + Math.round(dogrulukM) + ' m doğrulukla alındı — en yakın durak ' +
        'şaşabilir, aşağıdan seçebilirsin.'
      : 'Konum doğruluğu ±' + Math.round(dogrulukM) + ' m';

    // İzleme sürdüğü sürece konum iyileşmeye devam edebilir.
    if (!kesinMi) metin += ' · iyileştiriliyor…';

    oge.konumDogruluk.textContent = metin;
  }

  /** GPS şaşarsa kullanıcı doğru durağı kendisi seçebilsin. */
  function alternatifleriYaz(digerleri) {
    oge.konumAlternatifListe.textContent = '';

    if (!digerleri.length) {
      oge.konumAlternatif.hidden = true;
      return;
    }

    digerleri.forEach(function (aday) {
      var satir = document.createElement('li');
      var dugme = document.createElement('button');
      dugme.type = 'button';

      var ad = document.createElement('span');
      ad.textContent = aday.durak.ad;
      dugme.appendChild(ad);

      var mesafe = document.createElement('span');
      mesafe.className = 'konum-alternatif-mesafe';
      mesafe.textContent = mesafeBicimle(aday.mesafeM);
      dugme.appendChild(mesafe);

      dugme.addEventListener('click', function () {
        // Seçilen durak öne alınır; kalanlar mesafe sırasını korur, böylece
        // liste "en yakın önce" mantığından kopmaz.
        var kalanlar = tumAdaylar.filter(function (d) {
          return d.durak.kod !== aday.durak.kod;
        });
        yakinDuragiGoster([aday].concat(kalanlar), sonDogruluk.dogrulukM, true);
        oge.binis.value = aday.durak.kod;
        guncelle();
      });

      satir.appendChild(dugme);
      oge.konumAlternatifListe.appendChild(satir);
    });

    oge.konumAlternatif.hidden = false;
  }

  var sonDogruluk = { dogrulukM: 0, enYakinMesafe: 0 };
  var izlemeyiDurdur = null;

  /** Bir konumdan aday listesini kurup arayüzü tazeler. */
  function konumuIsle(konum, kesinMi) {
    var adaylar = enYakinDuraklar(aktifDuraklar, konum, 4);
    if (!adaylar.length) {
      konumDurumunuYaz('Duraklarda koordinat bilgisi yok.', 'hata');
      return;
    }
    sonDogruluk = { dogrulukM: konum.dogrulukM, enYakinMesafe: adaylar[0].mesafeM };
    tumAdaylar = adaylar;
    yakinDuragiGoster(adaylar, konum.dogrulukM, kesinMi);
  }

  function konumuBul() {
    if (izlemeyiDurdur) izlemeyiDurdur();
    konumDurumunuYaz('Konumun alınıyor…', 'bekliyor');

    izlemeyiDurdur = konumIzle(
      function (konum, kesinMi) { konumuIsle(konum, kesinMi); },
      function (mesaj) {
        // İzin reddi dahil her durumda site çalışmaya devam eder.
        konumDurumunuYaz(mesaj, 'hata');
      }
    );
  }

  /* ---------- Elle konum düzeltme ---------- */

  var aramaSayaci = null;

  function aramaDurumuYaz(metin) {
    oge.konumAramaDurum.textContent = metin;
    oge.konumAramaDurum.hidden = !metin;
  }

  function aramayiKapat() {
    oge.konumAramaListe.textContent = '';
    aramaDurumuYaz('');
    oge.konumArama.value = '';
    document.getElementById('konumDuzelt').open = false;
  }

  function aramaSatiriEkle(etiket, secildi) {
    var satir = document.createElement('li');
    var dugme = document.createElement('button');
    dugme.type = 'button';
    dugme.textContent = etiket;
    dugme.addEventListener('click', secildi);
    satir.appendChild(dugme);
    oge.konumAramaListe.appendChild(satir);
  }

  function aramaBasligiEkle(metin) {
    var satir = document.createElement('li');
    satir.className = 'konum-arama-baslik';
    satir.textContent = metin;
    oge.konumAramaListe.appendChild(satir);
  }

  /** Durak eşleşmeleri: yerel veri, ağ gerektirmez, her zaman çalışır. */
  function durakSonuclariniYaz(sorgu) {
    var eslesenler = durakAra(aktifDuraklar, sorgu).slice(0, 5);
    if (!eslesenler.length) return 0;

    aramaBasligiEkle('Duraklar');
    eslesenler.forEach(function (durak) {
      aramaSatiriEkle(durak.ad + ' · ' + durak.ilce, function () {
        // "Buradayım" demek yerine doğrudan durağı seçmek daha net.
        if (izlemeyiDurdur) izlemeyiDurdur();
        konumuIsle({
          enlem: durak.konum.enlem,
          boylam: durak.konum.boylam,
          dogrulukM: null
        }, true);
        oge.binis.value = durak.kod;
        guncelle();
        aramayiKapat();
      });
    });
    return eslesenler.length;
  }

  function yerSonuclariniYaz(sonuclar) {
    if (!sonuclar.length) return;

    aramaBasligiEkle('Yerler');
    sonuclar.forEach(function (yer) {
      aramaSatiriEkle(yer.ad, function () {
        // Elle girilen konum tarayıcıdan daha güvenilir sayılır: izleme durur.
        if (izlemeyiDurdur) izlemeyiDurdur();
        konumuIsle({ enlem: yer.enlem, boylam: yer.boylam, dogrulukM: null }, true);
        aramayiKapat();
      });
    });
  }

  function aramayiBagla() {
    oge.konumArama.addEventListener('input', function () {
      var sorgu = oge.konumArama.value;
      clearTimeout(aramaSayaci);
      oge.konumAramaListe.textContent = '';

      if (sorgu.trim().length < 3) {
        aramaDurumuYaz('');
        return;
      }

      // Durak eşleşmeleri anında gösterilir; ağ beklenmez.
      var durakSayisi = durakSonuclariniYaz(sorgu);

      // Nominatim ücretsiz ve gönüllü bir servis; her tuşta istek atılmaz.
      aramaSayaci = setTimeout(function () {
        aramaDurumuYaz('Yerler aranıyor…');
        yerAra(sorgu)
          .then(function (sonuclar) {
            yerSonuclariniYaz(sonuclar);
            aramaDurumuYaz(
              sonuclar.length || durakSayisi
                ? ''
                : 'Sonuç yok. Mahalle, cadde veya durak adı deneyebilirsin.'
            );
          })
          .catch(function () {
            aramaDurumuYaz(durakSayisi ? '' : 'Yer araması şu an çalışmıyor.');
          });
      }, 600);
    });
  }

  /* ---------- Akış ---------- */

  function guncelle() {
    var sonuc = yolculukHesapla(aktifDuraklar, oge.binis.value, oge.inis.value);
    if (!sonuc.gecerli) {
      hataGoster(sonuc.hata);
      return;
    }
    secimiKaydet();
    sonucuGoster(sonuc);
    binisYolTarifiniGuncelle(sonuc.binis);
  }

  function baslat() {
    temayiBaslat();
    secimleriDoldur();
    baslangicSeciminiYukle();
    oge.veriSurumu.textContent = HAT_VERISI.surum + ' (' + HAT_VERISI.guncellemeTarihi + ')';

    oge.binis.addEventListener('change', guncelle);
    oge.inis.addEventListener('change', guncelle);
    oge.tersCevir.addEventListener('click', function () {
      var gecici = oge.binis.value;
      oge.binis.value = oge.inis.value;
      oge.inis.value = gecici;
      guncelle();
    });

    oge.binisYap.addEventListener('click', function () {
      if (!yakinDurak) return;
      oge.binis.value = yakinDurak.kod;
      // Biniş ile iniş çakışırsa iniş durağını hattın diğer ucuna al.
      if (oge.inis.value === oge.binis.value) {
        var kodlar = aktifDuraklar.map(function (d) { return d.kod; });
        var indeks = kodlar.indexOf(yakinDurak.kod);
        oge.inis.value = indeks < kodlar.length / 2 ? kodlar[kodlar.length - 1] : kodlar[0];
      }
      guncelle();
      oge.binis.focus();
    });

    oge.konumTekrar.addEventListener('click', konumuBul);
    aramayiBagla();

    guncelle();
    firestoreDanTazele();
    konumuBul();
  }

  /**
   * Firestore'dan güncel veriyi çeker. Başarılı olursa arayüzü yeni veriyle
   * yeniden çizer; başarısız olursa sayfa yerel kopyayla çalışmaya devam eder.
   */
  function firestoreDanTazele() {
    if (typeof guncelDuraklariGetir !== 'function') return;

    guncelDuraklariGetir(HAT_VERISI.surum)
      .then(function (sonuc) {
        // duraklar null ise yerel kopya güncel demektir; listeyi yeniden kurmaya
        // gerek yok, ekranda zaten doğru veri duruyor.
        if (sonuc.duraklar) {
          var oncekiBinis = oge.binis.value;
          var oncekiInis = oge.inis.value;

          aktifDuraklar = sonuc.duraklar;
          secimleriDoldur();

          // Seçimler yeni listede de varsa korunur.
          var kodlar = sonuc.duraklar.map(function (d) { return d.kod; });
          oge.binis.value = kodlar.indexOf(oncekiBinis) !== -1 ? oncekiBinis : kodlar[0];
          oge.inis.value = kodlar.indexOf(oncekiInis) !== -1 ? oncekiInis : kodlar[kodlar.length - 1];

          guncelle();
        }

        oge.veriSurumu.textContent = sonuc.surum;
        oge.veriKaynagi.textContent =
          sonuc.kaynak === 'onbellek' ? 'Firebase (önbellek)' : 'Firebase';
      })
      .catch(function (sorun) {
        // Ağ yoksa, kurallar engelliyorsa veya belge yoksa buraya düşer.
        console.warn('Firestore okunamadı, yerel kopya kullanılıyor:', sorun.message);
        oge.veriKaynagi.textContent = 'yerel kopya';
      });
  }

  baslat();
})();
