// Arayüz katmanı — hesaplama için hesap.js, veri için duraklar.js kullanılır.
(function () {
  'use strict';

  var BINIS_ANAHTAR = 'izban.binis';
  var INIS_ANAHTAR = 'izban.inis';
  var TEMA_ANAHTAR = 'izban.tema';

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
    DURAKLAR.forEach(function (durak) {
      [oge.binis, oge.inis].forEach(function (secim) {
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

    var kodlar = DURAKLAR.map(function (d) { return d.kod; });
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

  function hataGoster(mesaj) {
    oge.hata.textContent = mesaj;
    oge.hata.hidden = false;
    oge.sonuc.hidden = true;
  }

  /* ---------- Akış ---------- */

  function guncelle() {
    var sonuc = yolculukHesapla(DURAKLAR, oge.binis.value, oge.inis.value);
    if (!sonuc.gecerli) {
      hataGoster(sonuc.hata);
      return;
    }
    secimiKaydet();
    sonucuGoster(sonuc);
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

    guncelle();
  }

  baslat();
})();
