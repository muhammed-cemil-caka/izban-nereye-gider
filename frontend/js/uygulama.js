// Arayüz katmanı — hesaplama için hesap.js, veri için duraklar.js kullanılır.
(function () {
  'use strict';

  var BINIS_ANAHTAR = 'izban.binis';
  var INIS_ANAHTAR = 'izban.inis';
  var TEMA_ANAHTAR = 'izban.tema';
  var ELLE_KONUM_ANAHTAR = 'izban.elleKonum';

  // Gösterimde kullanılan veri. Sayfa yerel kopyayla anında açılır; Firestore
  // yanıtı gelince bununla değiştirilip arayüz yeniden çizilir.
  var aktifDuraklar = DURAKLAR;
  var harita = null;

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
    seferKutusu: document.getElementById('seferKutusu'),
    seferBaslik: document.getElementById('seferBaslik'),
    seferListesi: document.getElementById('seferListesi'),
    seferNot: document.getElementById('seferNot'),
    hatSemasi: document.getElementById('hatSemasi'),
    aktarmaKarti: document.getElementById('aktarmaKarti'),
    aktarmaListesi: document.getElementById('aktarmaListesi'),
    aktarmaSayisi: document.getElementById('aktarmaSayisi'),
    geziKarti: document.getElementById('geziKarti'),
    geziGruplari: document.getElementById('geziGruplari'),
    veriSurumu: document.getElementById('veriSurumu'),
    veriKaynagi: document.getElementById('veriKaynagi'),
    konumKarti: document.getElementById('konumKarti'),
    konumMetni: document.getElementById('konumMetni'),
    konumSonucu: document.getElementById('konumSonucu'),
    yakinDurakAd: document.getElementById('yakinDurakAd'),
    yakinDurakMesafe: document.getElementById('yakinDurakMesafe'),
    binisYap: document.getElementById('binisYapDugmesi'),
    yolTarifi: document.getElementById('yolTarifiDugmesi'),
    arabaTarifi: document.getElementById('arabaTarifiDugmesi'),
    rotaKipYuruyus: document.getElementById('rotaKipYuruyus'),
    rotaKipAraba: document.getElementById('rotaKipAraba'),
    yonlendirmeToplamEtiket: document.getElementById('yonlendirmeToplamEtiket'),
    rotaSonucu: document.getElementById('rotaSonucu'),
    rotaBaslik: document.getElementById('rotaBaslik'),
    rotaOlcu: document.getElementById('rotaOlcu'),
    rotaAdimlar: document.getElementById('rotaAdimlar'),
    rotaAdimSayisi: document.getElementById('rotaAdimSayisi'),
    rotaTemizle: document.getElementById('rotaTemizle'),
    rotaDurum: document.getElementById('rotaDurum'),
    haritaKarti: document.querySelector('.harita-karti'),
    haritaIpucu: document.querySelector('.harita-karti .harita-ipucu'),
    haritaKatki: document.querySelector('.harita-katki'),
    yonlendirmeBaslat: document.getElementById('yonlendirmeBaslat'),
    yonlendirmePaneli: document.getElementById('yonlendirmePaneli'),
    yonlendirmeManevra: document.getElementById('yonlendirmeManevra'),
    yonlendirmeMesafe: document.getElementById('yonlendirmeMesafe'),
    yonlendirmeKalan: document.getElementById('yonlendirmeKalan'),
    yonlendirmeCubuk: document.getElementById('yonlendirmeCubuk'),
    yonlendirmeYurunen: document.getElementById('yonlendirmeYurunen'),
    yonlendirmeToplam: document.getElementById('yonlendirmeToplam'),
    yonlendirmeSes: document.getElementById('yonlendirmeSes'),
    yonlendirmeBitir: document.getElementById('yonlendirmeBitir'),
    yonlendirmeUyari: document.getElementById('yonlendirmeUyari'),
    konumTekrar: document.getElementById('konumTekrarDugmesi'),
    binisYolTarifi: document.getElementById('binisYolTarifi'),
    konumDogruluk: document.getElementById('konumDogruluk'),
    konumAlternatif: document.getElementById('konumAlternatif'),
    konumAlternatifListe: document.getElementById('konumAlternatifListe'),
    konumArama: document.getElementById('konumArama'),
    konumAramaDurum: document.getElementById('konumAramaDurum'),
    konumAramaListe: document.getElementById('konumAramaListe'),
    tema: document.getElementById('temaDugmesi'),
    dil: document.getElementById('dilDugmesi')
  };

  /* ---------- Tema ---------- */

  /* ---------- Dil ---------- */

  var dilKodu = typeof dilKodunuBul === 'function' ? dilKodunuBul() : 'tr';

  /** Sözlükten metin. Anahtar yoksa anahtarın kendisi döner (gözden kaçmasın). */
  function ceviri(anahtar) {
    var sozluk = (typeof DILLER !== 'undefined' && DILLER[dilKodu]) || {};
    return sozluk[anahtar] || anahtar;
  }

  /**
   * Sayfadaki işaretli metinleri seçili dile çevirir.
   *
   * Yalnızca ARAYÜZ çevrilir; durak ve turistik yer adları özel isim olduğu
   * için olduğu gibi kalır, turistik özetler de Türkçe Vikipedi'den geliyor.
   */
  function diliUygula() {
    document.documentElement.lang = dilKodu;

    document.querySelectorAll('[data-ceviri]').forEach(function (el) {
      el.textContent = ceviri(el.dataset.ceviri);
    });
    document.querySelectorAll('[data-ceviri-yer]').forEach(function (el) {
      el.placeholder = ceviri(el.dataset.ceviriYer);
    });
    document.querySelectorAll('[data-ceviri-baslik]').forEach(function (el) {
      var metin = ceviri(el.dataset.ceviriBaslik);
      el.title = metin;
      el.setAttribute('aria-label', metin);
    });

    oge.dil.textContent = dilKodu === 'tr' ? 'EN' : 'TR';
    if (oge.haritaIpucu) oge.haritaIpucu.textContent = ceviri('haritaIpucu');
    if (oge.haritaKatki) {
      oge.haritaKatki.innerHTML = ceviri('haritaKatki').replace(
        'OpenStreetMap',
        '<a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noopener noreferrer">OpenStreetMap</a>'
      );
    }

    guncelle();
    if (sonKonum && tumAdaylar.length) {
      yakinDuragiGoster(tumAdaylar, sonDogruluk.dogrulukM, true);
    }
  }

  function dilDegistir() {
    dilKodu = dilKodu === 'tr' ? 'en' : 'tr';
    try { localStorage.setItem(DIL_ANAHTAR, dilKodu); } catch (e) { /* özel mod */ }
    diliUygula();
  }

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

  var AKTARMA_SIMGELERI = {
    Metro: 'Ⓜ',
    Tramvay: '🚊',
    Vapur: '⛴',
    ESHOT: '🚌'
  };

  /**
   * Aktarma noktasına yürüyüş rotası çizip canlı yönlendirmeyi başlatır.
   *
   * Kullanıcı "metroya nasıl giderim" diye sorduğunda beklediği şey rota
   * değil, yönlendirmenin kendisi; bu yüzden ayrıca "Başla"ya basması
   * gerekmiyor.
   */
  function aktarmayaYonlendir(nokta, durakAdi) {
    var hedef = {
      ad: (nokta.ad || durakAdi) + ' ' + nokta.tur.toLowerCase(),
      konum: nokta.konum
    };
    yolTarifiniGoster(hedef, 'yuruyus', { yonlendir: true });
  }

  // Çok hat olan duraklarda liste kartı şişirmesin diye ilki gösterilir.
  var GORUNUR_OTOBUS_HATTI = 12;

  /** ESHOT hat numaralarını küçük şeritler hâlinde yazar. */
  function otobusHatlariniYaz(hatlar) {
    var kutu = document.createElement('div');
    kutu.className = 'otobus-hatlari';

    var simge = document.createElement('span');
    simge.className = 'otobus-simge';
    simge.setAttribute('aria-hidden', 'true');
    simge.textContent = '🚌';
    kutu.appendChild(simge);

    hatlar.slice(0, GORUNUR_OTOBUS_HATTI).forEach(function (hat) {
      var etiket = document.createElement('span');
      etiket.className = 'otobus-hat';
      etiket.textContent = hat;
      kutu.appendChild(etiket);
    });

    if (hatlar.length > GORUNUR_OTOBUS_HATTI) {
      var kalan = document.createElement('span');
      kalan.className = 'otobus-kalan';
      kalan.textContent = '+' + (hatlar.length - GORUNUR_OTOBUS_HATTI) + ' hat';
      kutu.appendChild(kalan);
    }

    return kutu;
  }

  // Aktarma listesinde aynı anda görünecek en fazla satır. Uzun bir
  // yolculukta 29 aktarma oluyor ve kart sayfayı ekran boyu uzatıyordu.
  var GORUNUR_AKTARMA = 10;

  /** Aktarma listesini tam 10 satıra sabitler (adım listesindeki yöntem). */
  function aktarmaYuksekliginiAyarla(adet) {
    var liste = oge.aktarmaListesi;
    liste.style.removeProperty('--aktarma-yukseklik');
    if (adet <= GORUNUR_AKTARMA) return;

    var ilk = liste.children[0];
    var sonrasi = liste.children[GORUNUR_AKTARMA];
    if (!ilk || !sonrasi) return;

    var yukseklik = sonrasi.offsetTop - ilk.offsetTop;
    if (yukseklik > 0) liste.style.setProperty('--aktarma-yukseklik', yukseklik + 'px');
  }

  /* ---------- Sefer saatleri ---------- */

  var GORUNUR_SEFER = 4;

  // Aynı çift için servisi tekrar tekrar çağırmamak adına oturum boyu saklanır;
  // tarife gün içinde değişmiyor.
  var seferOnbellegi = {};
  var seferIstegi = 0;

  /**
   * Biniş durağından iniş durağına sıradaki trenleri gösterir.
   *
   * Veri İzmir Büyükşehir Belediyesi açık servisinden geliyor. Selçuk
   * uzantısında (Sağlık, Belevi, Selçuk) servis boş liste döndürüyor; uydurma
   * saat basmak yerine durum açıkça yazılır.
   */
  function seferleriGoster(sonuc) {
    var binis = sonuc.binis;
    var inis = sonuc.inis;

    if (typeof seferleriAl !== 'function' || !binis.izbanId || !inis.izbanId) {
      oge.seferKutusu.hidden = true;
      return;
    }

    var anahtar = binis.izbanId + '-' + inis.izbanId;
    var istek = ++seferIstegi;

    oge.seferKutusu.hidden = false;
    oge.seferBaslik.textContent =
      binis.ad + ' → ' + inis.ad + ' · ' + ceviri('siradakiTrenler').toLowerCase();
    oge.seferNot.textContent = '';

    if (seferOnbellegi[anahtar]) {
      seferleriYaz(seferOnbellegi[anahtar]);
      return;
    }

    oge.seferListesi.textContent = '';
    oge.seferNot.textContent = ceviri('seferAliniyor');

    seferleriAl(binis.izbanId, inis.izbanId)
      .then(function (seferler) {
        if (istek !== seferIstegi) return;   // kullanıcı seçimi değiştirdi
        seferOnbellegi[anahtar] = seferler;
        seferleriYaz(seferler);
      })
      .catch(function () {
        if (istek !== seferIstegi) return;
        oge.seferListesi.textContent = '';
        oge.seferNot.textContent = ceviri('seferUlasilamiyor');
      });
  }

  function seferleriYaz(seferler) {
    oge.seferListesi.textContent = '';

    if (!seferler.length) {
      oge.seferNot.textContent = ceviri('seferYok');
      return;
    }

    var siradaki = siradakiSeferler(seferler, GORUNUR_SEFER);
    siradaki.forEach(function (sefer, sira) {
      var satir = document.createElement('li');
      satir.className = 'sefer' + (sira === 0 ? ' sefer--ilk' : '');

      var kalkis = document.createElement('strong');
      kalkis.className = 'sefer-kalkis';
      kalkis.textContent = sefer.kalkis;
      satir.appendChild(kalkis);

      var varis = document.createElement('span');
      varis.className = 'sefer-varis';
      varis.textContent = '→ ' + sefer.varis;
      satir.appendChild(varis);

      var kalan = document.createElement('span');
      kalan.className = 'sefer-kalan';
      kalan.textContent = sefer.ertesiGun
        ? ceviri('yarin')
        : sefer.kalanDk === 0 ? ceviri('simdi') : sefer.kalanDk + ' ' + ceviri('dkSonra');
      satir.appendChild(kalan);

      oge.seferListesi.appendChild(satir);
    });

    oge.seferNot.textContent =
      seferler.length + ' ' + ceviri('sefer') + ' · ' + ceviri('seferKaynak');
  }

  /* ---------- Gezilecek yerler ---------- */

  // Bir durak için gösterilecek en fazla kart. Alsancak Gar'ın çevresinde 32
  // yer var; hepsini basmak kartı sayfa boyu uzatır.
  var GORUNUR_GEZI = 8;

  var GEZI_SIMGELERI = {
    'antik-kent': '🏛', muze: '🖼', cami: '🕌', kilise: '⛪',
    kale: '🏰', anit: '🗿', park: '🌳', 'kultur-varligi': '🏺',
    kule: '🗼', 'tarihi-yapi': '🏚', 'gezi-noktasi': '📍'
  };

  /** Bir durağın çevresindeki yerler, yakından uzağa. */
  function duragaYakinYerler(durakKodu) {
    if (typeof TURISTIK_YERLER === 'undefined') return [];

    return TURISTIK_YERLER
      .map(function (yer) {
        var bag = yer.duraklar.find(function (d) { return d.kod === durakKodu; });
        return bag ? { yer: yer, mesafeM: bag.kusUcusuM } : null;
      })
      .filter(Boolean)
      .sort(function (a, b) { return a.mesafeM - b.mesafeM; });
  }

  /** Tek bir turistik yer kartı: fotoğraf, başlık, kısa tarihçe, yol tarifi. */
  function geziKartiKur(kayit) {
    var yer = kayit.yer;
    var kart = document.createElement('article');
    kart.className = 'gezi-kart';

    if (yer.gorsel) {
      var gorsel = document.createElement('img');
      gorsel.className = 'gezi-gorsel';
      gorsel.src = yer.gorsel.kucukAdres;
      gorsel.alt = yer.ad;
      gorsel.loading = 'lazy';
      // Görsel yüklenmezse (Commons kapalı, ağ yok) kart metinle çalışsın.
      gorsel.addEventListener('error', function () { gorsel.remove(); });
      kart.appendChild(gorsel);
    }

    var govde = document.createElement('div');
    govde.className = 'gezi-govde';

    var baslik = document.createElement('h3');
    baslik.className = 'gezi-baslik';
    baslik.textContent = (GEZI_SIMGELERI[yer.tur] || '📍') + ' ' + yer.ad;
    govde.appendChild(baslik);

    var mesafe = document.createElement('p');
    mesafe.className = 'gezi-mesafe';
    mesafe.textContent = ceviri('duraktan') + ' ' + mesafeBicimle(kayit.mesafeM);
    govde.appendChild(mesafe);

    var ozet = document.createElement('p');
    ozet.className = 'gezi-ozet';
    ozet.textContent = yer.ozet || '';
    govde.appendChild(ozet);

    var dugmeler = document.createElement('div');
    dugmeler.className = 'gezi-dugmeler';

    [
      { kip: 'yuruyus', etiket: '🚶 ' + ceviri('yuruyerek') },
      { kip: 'araba', etiket: '🚗 ' + ceviri('arabayla') }
    ].forEach(function (secim) {
      var dugme = document.createElement('button');
      dugme.type = 'button';
      dugme.className = 'gezi-dugme';
      dugme.textContent = secim.etiket;
      dugme.addEventListener('click', function () { yereYolTarifi(yer, secim.kip); });
      dugmeler.appendChild(dugme);
    });

    var toplu = document.createElement('button');
    toplu.type = 'button';
    toplu.className = 'gezi-dugme';
    toplu.textContent = '🚊 ' + ceviri('topluTasima');
    toplu.addEventListener('click', function () { topluTasimaAnlat(yer); });
    dugmeler.appendChild(toplu);

    govde.appendChild(dugmeler);

    {
      var kaynak = document.createElement('p');
      kaynak.className = 'gezi-lisans';

      if (yer.kaynaklar.wikipedia) {
        var vp = document.createElement('a');
        vp.href = yer.kaynaklar.wikipedia;
        vp.target = '_blank';
        vp.rel = 'noopener noreferrer';
        vp.textContent = 'Vikipedi';
        kaynak.appendChild(vp);
      }

      if (yer.gorsel) {
        if (kaynak.childNodes.length) kaynak.appendChild(document.createTextNode(' · '));
        var foto = document.createElement('a');
        foto.href = yer.gorsel.kaynakSayfa;
        foto.target = '_blank';
        foto.rel = 'noopener noreferrer';
        foto.textContent = 'Foto: ' + yer.gorsel.yazar + ' (' + yer.gorsel.lisans + ')';
        kaynak.appendChild(foto);
      }

      govde.appendChild(kaynak);
    }

    kart.appendChild(govde);
    return kart;
  }

  /** Biniş ve iniş durağı için gezilecek yerleri çizer. */
  function geziYerleriniCiz(sonuc) {
    oge.geziGruplari.textContent = '';

    var gruplar = [
      { baslik: sonuc.binis.ad + ' ' + ceviri('geziCevresi'), kod: sonuc.binis.kod },
      { baslik: sonuc.inis.ad + ' ' + ceviri('geziCevresi'), kod: sonuc.inis.kod }
    ];

    var toplam = 0;
    gruplar.forEach(function (grup) {
      var yerler = duragaYakinYerler(grup.kod);
      if (!yerler.length) return;
      toplam += yerler.length;

      var bolum = document.createElement('div');
      bolum.className = 'gezi-grup';

      var baslik = document.createElement('h3');
      baslik.className = 'gezi-grup-baslik';
      baslik.textContent = grup.baslik + ' · ' + yerler.length + ' ' + ceviri('yer');
      bolum.appendChild(baslik);

      var seritKap = document.createElement('div');
      seritKap.className = 'gezi-serit';
      yerler.slice(0, GORUNUR_GEZI).forEach(function (kayit) {
        seritKap.appendChild(geziKartiKur(kayit));
      });
      bolum.appendChild(seritKap);

      oge.geziGruplari.appendChild(bolum);
    });

    oge.geziKarti.hidden = toplam === 0;
  }

  /**
   * Turistik yere yol tarifi.
   *
   * Rota, kullanıcının konumundan değil **o kipe göre en yakın DURAKTAN**
   * çizilir: kullanıcı oraya İZBAN ile geliyor. En yakın durak da kipin kendi
   * ağıyla seçilir — yürürken yakın olan durak arabayla dolambaçlı olabiliyor.
   */
  function yereYolTarifi(yer, kip) {
    var secilenKip = kip === 'araba' ? 'araba' : 'yuruyus';
    rotaDurumuYaz(secilenKip === 'araba'
      ? 'En yakın durak araç ağına göre seçiliyor…'
      : 'En yakın durak yürüyüş ağına göre seçiliyor…');

    yereEnYakinDurak(yer, secilenKip).then(function (durak) {
      // Haritada o durağı seçili getir.
      oge.binis.value = durak.kod;
      if (oge.inis.value === oge.binis.value) {
        var kodlar = aktifDuraklar.map(function (d) { return d.kod; });
        var indeks = kodlar.indexOf(durak.kod);
        oge.inis.value = indeks < kodlar.length / 2 ? kodlar[kodlar.length - 1] : kodlar[0];
      }
      guncelle();

      sonRotaKip = secilenKip;
      kipDugmeleriniTazele();

      return rotaAl(durak.konum, yer.konum, secilenKip).then(function (rota) {
        if (harita) harita.rotayiCiz(rota.noktalar, rota.kip);
        sonRota = rota;
        sonRotaHedefi = { ad: yer.ad, konum: yer.konum };
        rotaSonucunuYaz(rota, { ad: yer.ad, durakMi: false });
        rotaDurumuYaz('');
        haritayaKaydir();
      });
    }).catch(function (sorun) {
      rotaDurumuYaz(sorun.message || 'Rota alınamadı.', 'hata');
    });
  }

  /**
   * Bir yere kipin ağına göre en yakın durak.
   *
   * Kuş uçuşu YALNIZCA ön eleme için kullanılır (6 aday); karar OSRM'in matris
   * servisinden gelen SÜREYE göre verilir. Araçta uzun ama hızlı çevre yol,
   * kısa ama yavaş şehir içinden iyi olabiliyor.
   */
  function yereEnYakinDurak(yer, kip) {
    var adaylar = enYakinDuraklar(aktifDuraklar, yer.konum, 6);
    if (!adaylar.length) return Promise.reject(new Error('Durak bulunamadı.'));

    if (typeof mesafeleriAl !== 'function') return Promise.resolve(adaylar[0].durak);

    return mesafeleriAl(yer.konum, adaylar.map(function (a) { return a.durak.konum; }), kip)
      .then(function (olcumler) {
        var sirali = adaylar
          .map(function (aday, sira) {
            var olcum = olcumler[sira];
            return {
              durak: aday.durak,
              sureSn: olcum && isFinite(olcum.sureSn) ? olcum.sureSn : Infinity
            };
          })
          .sort(function (a, b) { return a.sureSn - b.sureSn; });

        return sirali[0].durak;
      })
      .catch(function () {
        // Servis yanıt vermezse kuş uçuşu sıralama kalır; akış kesilmez.
        return adaylar[0].durak;
      });
  }

  /**
   * Toplu taşıma: gerçek bir sefer motorumuz yok, aktarma zinciri anlatılır.
   *
   * OSRM'de toplu taşıma profili yok; sefer saati verisi de elimizde yok.
   * Uydurulmuş bir süre yolcuyu yanıltır, o yüzden yalnızca zincir gösterilir.
   */
  function topluTasimaAnlat(yer) {
    var adaylar = enYakinDuraklar(aktifDuraklar, yer.konum, 1);
    if (!adaylar.length) return;

    var durak = adaylar[0].durak;
    var hatlar = (durak.otobusHatlari || []).slice(0, 6).join(', ');
    var aktarmalar = (durak.aktarma || []).join(' · ');

    var satirlar = [
      'İZBAN ile ' + durak.ad + ' durağına gel.',
      aktarmalar ? durak.ad + ' aktarmaları: ' + aktarmalar : null,
      hatlar ? 'ESHOT hatları: ' + hatlar : null,
      'Oradan ' + yer.ad + ' için "Yürüyerek" düğmesini kullan.',
      'Sefer saati veremiyorum: elimizde tarife verisi yok.'
    ].filter(Boolean);

    rotaDurumuYaz(satirlar.join(' · '));
  }

  function aktarmalariCiz(sonuc) {
    oge.aktarmaListesi.textContent = '';
    oge.aktarmaSayisi.textContent = '';
    if (!sonuc.aktarmalar.length) {
      oge.aktarmaKarti.hidden = true;
      return;
    }
    sonuc.aktarmalar.forEach(function (aktarma) {
      var satir = document.createElement('li');

      var ust = document.createElement('div');
      ust.className = 'aktarma-ust';

      var ad = document.createElement('strong');
      ad.textContent = aktarma.ad;
      ust.appendChild(ad);

      var turler = document.createElement('div');
      turler.className = 'aktarma-turler';

      aktarma.hatlar.forEach(function (tur) {
        var nokta = (aktarma.noktalar || []).find(function (n) { return n.tur === tur; });

        // Noktası bilinen aktarma tıklanabilir: kullanıcının konumundan oraya
        // yürüyüş rotası çizilip canlı yönlendirme başlar.
        var oge2 = document.createElement(nokta ? 'button' : 'span');
        oge2.className = 'aktarma-tur aktarma-tur--' + tur.toLowerCase();
        oge2.textContent = AKTARMA_SIMGELERI[tur]
          ? AKTARMA_SIMGELERI[tur] + ' ' + tur
          : tur;

        if (nokta) {
          oge2.type = 'button';
          oge2.title = tur + ' aktarmasına yürüyüş yol tarifi (' +
            mesafeBicimle(nokta.mesafeM) + ')';
          oge2.addEventListener('click', function () {
            aktarmayaYonlendir(nokta, aktarma.ad);
          });

          var mesafe = document.createElement('span');
          mesafe.className = 'aktarma-tur-mesafe';
          mesafe.textContent = mesafeBicimle(nokta.mesafeM);
          oge2.appendChild(mesafe);
        }

        turler.appendChild(oge2);
      });

      ust.appendChild(turler);
      satir.appendChild(ust);

      // "ESHOT" tek başına hangi otobüse binileceğini söylemiyor; hat
      // numaraları ayrı bir satırda listelenir.
      if (aktarma.otobusHatlari && aktarma.otobusHatlari.length) {
        satir.appendChild(otobusHatlariniYaz(aktarma.otobusHatlari));
      }

      oge.aktarmaListesi.appendChild(satir);
    });
    oge.aktarmaKarti.hidden = false;
    aktarmaYuksekliginiAyarla(sonuc.aktarmalar.length);

    oge.aktarmaSayisi.textContent = sonuc.aktarmalar.length > GORUNUR_AKTARMA
      ? sonuc.aktarmalar.length + ' aktarma noktası · listeyi kaydırarak devamını gör'
      : sonuc.aktarmalar.length + ' aktarma noktası';
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

  /** Seçili biniş durağına yol tarifi düğmesini tazeler. */
  function binisYolTarifiniGuncelle(durak) {
    var koordinatVar = durak.konum && (durak.konum.enlem || durak.konum.boylam);
    oge.binisYolTarifi.hidden = !koordinatVar;
    if (koordinatVar) {
      oge.binisYolTarifi.textContent = durak.ad + ' durağına yol tarifi →';
      oge.binisYolTarifi.__durak = durak;
    }
  }

  /* ---------- Yürüyüş rotası ---------- */

  var sonKonum = null;

  function rotaDurumuYaz(metin, tur) {
    oge.rotaDurum.textContent = metin;
    oge.rotaDurum.hidden = !metin;
    oge.rotaDurum.setAttribute('data-tur', tur || 'bilgi');
  }

  function rotayiTemizle() {
    yonlendirmeyiBitir();
    sonRota = null;
    sonRotaHedefi = null;
    oge.rotaSonucu.hidden = true;
    oge.rotaAdimlar.textContent = '';
    oge.rotaAdimSayisi.textContent = '';
    rotaDurumuYaz('');
    if (harita) harita.yuruyusRotasiniTemizle();
  }

  /**
   * Rota çizilince haritayı görünür alana getirir; kullanıcı aşağı kaydırmak
   * zorunda kalmasın. Kart konumu, yeni içerik yerleştikten sonra hesaplanır.
   */
  /**
   * Sayfayı verilen noktaya kaydırır.
   *
   * Tarayıcının kendi yumuşak kaydırması (scrollIntoView / scroll-behavior)
   * bazı ortamlarda sessizce hiçbir şey yapmıyor. Bu yüzden animasyon elle
   * yapılıyor: her yerde çalışır ve hareketi azaltma tercihine uyar.
   */
  function sayfayiKaydir(hedef) {
    hedef = Math.max(0, hedef);

    var azHareket = window.matchMedia &&
      window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    var baslangic = window.scrollY;
    var mesafe = hedef - baslangic;

    if (azHareket || Math.abs(mesafe) < 4) {
      window.scrollTo(0, hedef);
      return;
    }

    var sure = 350;
    var ilkZaman = null;

    function adim(zaman) {
      if (ilkZaman === null) ilkZaman = zaman;
      var oran = Math.min(1, (zaman - ilkZaman) / sure);
      // easeInOutQuad
      var yumusak = oran < 0.5
        ? 2 * oran * oran
        : 1 - Math.pow(-2 * oran + 2, 2) / 2;

      window.scrollTo(0, baslangic + mesafe * yumusak);
      if (oran < 1) requestAnimationFrame(adim);
    }

    requestAnimationFrame(adim);
  }

  function haritayaKaydir() {
    if (!oge.haritaKarti) return;

    // Yeni içerik yerleştikten sonra konum hesaplanmalı. setTimeout kullanılıyor
    // çünkü sekme arka plandayken requestAnimationFrame hiç tetiklenmiyor ve
    // kaydırma sessizce yapılmamış oluyor.
    setTimeout(function () {
      var hedef = Math.max(
        0,
        oge.haritaKarti.getBoundingClientRect().top + window.scrollY - 12
      );
      sayfayiKaydir(hedef);

      // Animasyon rAF'a dayanıyor; sayfa gizliyken çalışmaz. Konumun yine de
      // doğru olması için kısa süre sonra denetlenip gerekirse doğrudan gidilir.
      setTimeout(function () {
        if (Math.abs(window.scrollY - hedef) > 8) window.scrollTo(0, hedef);
      }, 500);
    }, 0);
  }

  // Adım listesinde aynı anda görünecek en fazla adım sayısı. Uzun bir
  // yürüyüşte liste kartı sayfayı metrelerce uzatıyordu; artık kendi içinde
  // kaydırılıyor.
  var GORUNUR_ADIM = 7;

  /**
   * Listenin yüksekliğini tam 7 adıma sabitler.
   *
   * Sabit bir piksel değeri yetmiyor: adım metni sarınca satır iki katına
   * çıkıyor ve ekranda 5 adım kalıyor. 8. adımın üst kenarı ölçülüp yükseklik
   * ondan hesaplanıyor — satırlar sarsa da tam 7 adım görünür.
   */
  function adimYuksekliginiAyarla() {
    var liste = oge.rotaAdimlar;
    liste.style.removeProperty('--adim-yukseklik');

    var satirlar = liste.children;
    if (satirlar.length <= GORUNUR_ADIM) return;

    var ilk = satirlar[0];
    var sonrasi = satirlar[GORUNUR_ADIM];
    var yukseklik = sonrasi.offsetTop - ilk.offsetTop;
    if (yukseklik > 0) liste.style.setProperty('--adim-yukseklik', yukseklik + 'px');
  }

  function rotaSonucunuYaz(rota, hedef) {
    var arabaMi = rota.kip === 'araba';
    // Hedef bir durak olabilir, turistik yer de: "Ayasuluk Camii durağına"
    // demek yanlış olurdu.
    var ad = hedef.durakMi === false ? hedef.ad : hedef.ad + ' durağına';
    oge.rotaBaslik.textContent = ad + ' ' + (arabaMi ? '— araba ile' : '— yürüyüş');
    oge.rotaOlcu.textContent =
      mesafeBicimle(rota.mesafeM) + ' · ' + rotaSuresiBicimle(rota.sureSn);

    oge.rotaAdimlar.textContent = '';
    rota.adimlar.forEach(function (adim) {
      var satir = document.createElement('li');
      satir.textContent = adim.metin;

      var mesafe = document.createElement('span');
      mesafe.className = 'rota-adim-mesafe';
      mesafe.textContent = mesafeBicimle(adim.mesafeM);
      satir.appendChild(mesafe);

      oge.rotaAdimlar.appendChild(satir);
    });

    oge.rotaSonucu.hidden = false;
    adimYuksekliginiAyarla();

    oge.rotaAdimSayisi.textContent = rota.adimlar.length > GORUNUR_ADIM
      ? rota.adimlar.length + ' adım · listeyi kaydırarak devamını gör'
      : rota.adimlar.length + ' adım';
  }

  /** Kullanıcının konumundan verilen durağa yürüyüş rotası çizer. */
  /**
   * Kullanıcının konumundan verilen durağa rota çizer.
   * @param {object} durak
   * @param {string} [kip] 'yuruyus' (varsayılan) veya 'araba'
   */
  function yolTarifiniGoster(durak, kip, secenekler) {
    if (!sonKonum) {
      rotaDurumuYaz('Önce konumunu bulmam gerekiyor.', 'hata');
      return;
    }
    if (typeof rotaAl !== 'function') return;

    var secilenKip = kip === 'araba' ? 'araba' : 'yuruyus';
    sonRotaKip = secilenKip;
    kipDugmeleriniTazele();

    rotaDurumuYaz(secilenKip === 'araba'
      ? 'Araba rotası hesaplanıyor…'
      : 'Yürüyüş rotası hesaplanıyor…');
    oge.rotaSonucu.hidden = true;

    rotaAl(sonKonum, durak.konum, secilenKip)
      .then(function (rota) {
        if (harita) harita.rotayiCiz(rota.noktalar, rota.kip);
        sonRota = rota;
        sonRotaHedefi = durak;
        rotaSonucunuYaz(rota, durak);
        rotaDurumuYaz('');
        haritayaKaydir();

        // Aktarma noktasına tıklandığında kullanıcı doğrudan yönlendirme
        // bekliyor; ayrıca "Başla"ya basması gerekmesin.
        if (secenekler && secenekler.yonlendir) yonlendirmeyiBaslat();
      })
      .catch(function (sorun) {
        rotaDurumuYaz(sorun.message, 'hata');
      });
  }

  /** Kip düğmelerinin basılı durumunu ayarlar. */
  function kipDugmeleriniTazele() {
    var arabaMi = sonRotaKip === 'araba';
    oge.rotaKipYuruyus.setAttribute('aria-pressed', String(!arabaMi));
    oge.rotaKipAraba.setAttribute('aria-pressed', String(arabaMi));
    oge.yonlendirmeToplamEtiket.textContent = arabaMi ? 'toplam sürüş' : 'toplam yürüyüş';
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

    // Tekrar düğmesi iki durumda gerekli: hata varsa, ya da elle girilmiş bir
    // konum kullanılıyorsa (kullanıcı tarayıcı konumuna dönebilmeli).
    oge.konumTekrar.hidden = durum !== 'hata' && !elleKonumuOku();
    oge.konumTekrar.textContent = elleKonumuOku() ? 'Konumumu yeniden bul' : 'Konumumu bul';
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
    oge.yakinDurakMesafe.textContent = enYakin.kip === 'araba'
      ? mesafeBicimle(enYakin.mesafeM) + ' araba ile'
      : enYakin.kip === 'yuruyus'
        ? mesafeBicimle(enYakin.mesafeM) + ' yürüyüş'
        : mesafeBicimle(enYakin.mesafeM);
    oge.yolTarifi.setAttribute(
      'aria-label',
      enYakin.durak.ad + ' durağına yürüyerek yol tarifini haritada göster'
    );

    dogruluguYaz(dogrulukM, kesinMi);
    alternatifleriYaz(adaylar.slice(1));

    konumDurumunuYaz('', 'hazir');
  }

  function dogruluguYaz(dogrulukM, kesinMi) {
    if (dogrulukM === null) {
      // Elle girilen konum: doğruluk kavramı geçerli değil.
      var kayitli = elleKonumuOku();
      oge.konumDogruluk.setAttribute('data-kaba', 'hayir');
      oge.konumDogruluk.textContent = kayitli && kayitli.etiket
        ? 'Konum senin girdiğin yere göre: ' + kayitli.etiket.split(',')[0]
        : 'Konum senin girdiğin yere göre hesaplandı.';
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
    else if (takibiDurdur) metin += ' · canlı takip açık';

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
  var takibiDurdur = null;

  /** Konum işareti kullanıcıyla birlikte hareket etsin diye takibi açar. */
  function takibiBaslat() {
    if (takibiDurdur) takibiDurdur();
    if (typeof konumTakibiBaslat !== 'function') return;

    takibiDurdur = konumTakibiBaslat(function (konum) {
      // Yönlendirme kendi akışını kullanıyor; takip araya girmesin.
      if (yonlendirmeOturumu) return;
      konumuIsle(konum, true);
    });
  }

  function takibiKapat() {
    if (takibiDurdur) takibiDurdur();
    takibiDurdur = null;
  }

  /** Kullanıcının elle girdiği konumu saklar; her açılışta yeniden girilmesin. */
  function elleKonumuKaydet(konum, etiket) {
    try {
      localStorage.setItem(ELLE_KONUM_ANAHTAR, JSON.stringify({
        enlem: konum.enlem,
        boylam: konum.boylam,
        etiket: etiket || ''
      }));
    } catch (sorun) { /* özel mod */ }
  }

  function elleKonumuOku() {
    try {
      var ham = localStorage.getItem(ELLE_KONUM_ANAHTAR);
      if (!ham) return null;
      var kayit = JSON.parse(ham);
      if (typeof kayit.enlem !== 'number' || typeof kayit.boylam !== 'number') return null;
      return kayit;
    } catch (sorun) {
      return null;
    }
  }

  function elleKonumuUnut() {
    try { localStorage.removeItem(ELLE_KONUM_ANAHTAR); } catch (sorun) { /* özel mod */ }
  }

  /**
   * Adayları gerçek yürüme mesafesine göre yeniden sıralar.
   *
   * Kuş uçuşu yanıltıyor: dere, otoyol veya demiryolu araya girdiğinde yakın
   * görünen durak yürüyerek çok daha uzak olabiliyor. Ölçüldü: Çiğli kuş
   * uçuşu daha yakın ama yürüyüşle 2,5 km; Mavişehir 1,4 km.
   */
  function adaylariGercekMesafeyeGoreSirala(konum, adaylar, kip) {
    if (typeof mesafeleriAl !== 'function') return;

    var secilenKip = kip === 'araba' ? 'araba' : 'yuruyus';
    var hedefler = adaylar.map(function (a) { return a.durak.konum; });

    mesafeleriAl(konum, hedefler, secilenKip)
      .then(function (olcumler) {
        // Kullanıcı bu arada kipi değiştirdiyse eski yanıt listeyi bozmasın.
        if (secilenKip !== siralamaKipi) return;

        var yeniSira = adaylar
          .map(function (aday, sira) {
            var olcum = olcumler[sira];
            if (!olcum || !isFinite(olcum.mesafeM)) return aday;
            return {
              durak: aday.durak,
              mesafeM: olcum.mesafeM,
              sureSn: olcum.sureSn,
              kip: secilenKip
            };
          })
          .sort(function (a, b) { return a.mesafeM - b.mesafeM; });

        tumAdaylar = yeniSira;
        yakinDuragiGoster(yeniSira, sonDogruluk.dogrulukM, true);
      })
      .catch(function () {
        // Servise ulaşılamazsa kuş uçuşu sıralama kalır; site çalışmaya devam eder.
      });
  }

  /**
   * Kip seçilince hem liste o kiple sıralanır hem de rota çizilir.
   *
   * Kullanıcı "arabayla" dediğinde sorduğu şey "hangi durağa arabayla daha
   * kısa giderim"; sıralama yürüyüşte kalırsa yanlış durağa yönlendirilir.
   * Sıralama sonucu geldiğinde rota o kipin en yakın durağına çizilir.
   */
  function kipleYolTarifi(kip) {
    var oncekiKip = siralamaKipi;
    siralamaKipiniDegistir(kip);

    // Kip değişmediyse liste zaten doğru; doğrudan rotayı çiz.
    if (oncekiKip === kip || !sonKonum || !tumAdaylar.length) {
      if (yakinDurak) yolTarifiniGoster(yakinDurak, kip);
      return;
    }

    // Sıralama isteği dönene kadar eldeki durakla başla; liste tazelenince
    // en yakın durak değişirse kullanıcı listeden seçebilir.
    if (yakinDurak) yolTarifiniGoster(yakinDurak, kip);
  }

  /**
   * En yakın durak listesini verilen kiple yeniden sıralar.
   *
   * Yürüyerek en yakın durak ile arabayla en yakın durak aynı olmayabiliyor:
   * yaya köprüsünden geçilen durak yürüyerek yakın ama arabayla dolambaçlı.
   */
  function siralamaKipiniDegistir(kip) {
    var secilenKip = kip === 'araba' ? 'araba' : 'yuruyus';
    if (secilenKip === siralamaKipi) return;

    siralamaKipi = secilenKip;
    if (sonKonum && tumAdaylar.length) {
      adaylariGercekMesafeyeGoreSirala(sonKonum, tumAdaylar, secilenKip);
    }
  }

  // Yürüme sıralamasının hesaplandığı konum ve tazeleme eşiği.
  // Takip her ölçümde listeyi kuş uçuşuyla yeniden kurarsa yürüme sıralaması
  // siliniyordu; kullanıcı kayda değer mesafe yürümedikçe liste korunur.
  var sonYuruyusKonumu = null;
  var YURUYUS_TAZELEME_M = 150;

  /** Bir konumdan aday listesini kurup arayüzü tazeler. */
  function konumuIsle(konum, kesinMi) {
    var uzaklik = sonYuruyusKonumu
      ? metreUzaklik(konum, sonYuruyusKonumu)
      : Infinity;

    // Liste yerinde duruyorsa yalnızca konumu ve haritayı tazele.
    if (tumAdaylar.length && uzaklik < YURUYUS_TAZELEME_M) {
      sonKonum = { enlem: konum.enlem, boylam: konum.boylam };
      if (harita) harita.konumuGoster(konum);
      return;
    }

    var adaylar = enYakinDuraklar(aktifDuraklar, konum, 4);
    if (!adaylar.length) {
      konumDurumunuYaz('Duraklarda koordinat bilgisi yok.', 'hata');
      return;
    }
    sonDogruluk = { dogrulukM: konum.dogrulukM, enYakinMesafe: adaylar[0].mesafeM };
    tumAdaylar = adaylar;
    yakinDuragiGoster(adaylar, konum.dogrulukM, kesinMi);

    sonKonum = { enlem: konum.enlem, boylam: konum.boylam };
    if (harita) harita.konumuGoster(konum);

    // Kuş uçuşu sıralama anında gösterilir; yürüme mesafesi gelince düzeltilir.
    //
    // Burada "kesin ölçüm" BEKLENMEZ. Önce yalnızca kesinMi=true iken
    // sıralanıyordu; masaüstünde konum Wi-Fi tabanlı olduğu için ±30 m hedefine
    // hiç inilmiyor ve kesin ölçüm ancak 45 saniyelik izleme süresi dolunca
    // geliyordu — kullanıcı o zamana kadar kuş uçuşu sıralamayı görüyordu.
    // Mobil taraf da ilk ölçümde sıralıyor; iki istemci artık aynı davranıyor.
    // İstek sayısı, aşağıdaki 150 m'lik tazeleme eşiğiyle sınırlı kalıyor.
    if (!yonlendirmeOturumu) {
      sonYuruyusKonumu = { enlem: konum.enlem, boylam: konum.boylam };
      adaylariGercekMesafeyeGoreSirala(sonKonum, adaylar, siralamaKipi);
    }
  }

  /**
   * Açılış akışı: kullanıcı daha önce konumunu elle düzelttiyse ona güvenilir.
   * Masaüstünde tarayıcı konumu Wi-Fi tabanlı olduğu için elle girilen değer
   * neredeyse her zaman daha isabetlidir.
   */
  function konumuBaslat() {
    var kayitli = elleKonumuOku();
    if (kayitli) {
      konumuIsle({ enlem: kayitli.enlem, boylam: kayitli.boylam, dogrulukM: null }, true);
      return;
    }
    konumuBul();
  }

  function konumuBul() {
    if (izlemeyiDurdur) izlemeyiDurdur();
    // Tarayıcı konumu istendiği anda elle girilen değer geçerliliğini yitirir.
    elleKonumuUnut();
    konumDurumunuYaz('Konumun alınıyor…', 'bekliyor');

    izlemeyiDurdur = konumIzle(
      function (konum, kesinMi) {
        // Takip önce başlar: konumuIsle doğruluk satırını çizerken takibin
        // açık olduğunu bilmeli, yoksa "canlı takip açık" ilk ölçümde yazmaz.
        if (kesinMi) takibiBaslat();
        konumuIsle(konum, kesinMi);
      },
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
        takibiKapat();
        konumuIsle({
          enlem: durak.konum.enlem,
          boylam: durak.konum.boylam,
          dogrulukM: null
        }, true);
        elleKonumuKaydet(durak.konum, durak.ad);
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
        takibiKapat();
        konumuIsle({ enlem: yer.enlem, boylam: yer.boylam, dogrulukM: null }, true);
        elleKonumuKaydet(yer, yer.ad);
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

  /* ---------- Yönlendirme ---------- */

  var yonlendirmeOturumu = null;
  var sonRota = null;
  var sonRotaKip = 'yuruyus';
  // En yakın durak listesi hangi kiple sıralandı?
  var siralamaKipi = 'yuruyus';
  var sonRotaHedefi = null;

  // Bilinen son yön. Yeni ölçümde açı hesaplanamazsa (henüz yeterli hareket
  // yok) ok kuzeye sıçramasın diye eski açı korunur.
  var sonYonAcisi = 0;
  var pusulayiDurdur = null;
  var pusulaAcisi = null;

  function yonlendirmeUyarisiYaz(metin) {
    oge.yonlendirmeUyari.textContent = metin;
    oge.yonlendirmeUyari.hidden = !metin;
  }

  function yonlendirmeyiBaslat() {
    if (!sonRota || !sonRotaHedefi) return;
    if (typeof yonlendirmeBaslat !== 'function') return;
    if (yonlendirmeOturumu) yonlendirmeOturumu.durdur();

    oge.yonlendirmePaneli.hidden = false;
    oge.yonlendirmeManevra.textContent = sonRota.adimlar[0]
      ? sonRota.adimlar[0].metin
      : 'Yola çık';
    oge.yonlendirmeMesafe.textContent = '—';
    oge.yonlendirmeKalan.textContent =
      mesafeBicimle(sonRota.mesafeM) + ' · ' + rotaSuresiBicimle(sonRota.sureSn);
    oge.yonlendirmeToplam.textContent = mesafeBicimle(sonRota.mesafeM);
    oge.yonlendirmeYurunen.textContent = '0 m';
    oge.yonlendirmeCubuk.style.width = '0%';
    yonlendirmeUyarisiYaz('');

    // İşareti hemen yön okuna çevir ve haritayı yakınlaştır. Yeni bir konum
    // ölçümü beklenirse kullanıcı hareketsizken hiçbir şey değişmiyor gibi
    // görünüyor — masaüstünde ölçümler seyrek gelir.
    if (harita && sonKonum) {
      // İlk açı: rotanın ilk parçasının yönü. Kullanıcı yürümeye başlayınca
      // gerçek hareket yönüyle değişir.
      var baslangicAcisi = 0;
      if (sonRota.noktalar.length > 1 && typeof yonAcisi === 'function') {
        baslangicAcisi = yonAcisi(
          { enlem: sonRota.noktalar[0][0], boylam: sonRota.noktalar[0][1] },
          { enlem: sonRota.noktalar[1][0], boylam: sonRota.noktalar[1][1] }
        );
      }
      harita.konumuGoster(sonKonum, { yonlendirme: true, aci: baslangicAcisi });
      // Araçta biraz daha geniş bakış: 17 yaya yakınlığı, sürüşte
      // bir sonraki kavşak ekrana girmiyor.
      harita.konumaOdaklan(sonKonum, sonRotaKip === 'araba' ? 16 : 17);
      harita.haritayiYoneCevir(baslangicAcisi);
      sonYonAcisi = baslangicAcisi;
    }

    // Telefon çevrildiğinde harita da dönsün (mobildeki davranış).
    if (typeof pusulayiDinle === 'function') {
      if (pusulayiDurdur) pusulayiDurdur();
      pusulayiDurdur = pusulayiDinle(function (aci) {
        pusulaAcisi = aci;
        if (harita) harita.haritayiYoneCevir(aci);
      });
    }

    yonlendirmeOturumu = yonlendirmeBaslat({
      rota: sonRota,
      sesliMi: oge.yonlendirmeSes.checked,

      durumDegisti: function (durum) {
        var adim = sonRota.adimlar[durum.ilerleme.adimIndeksi];
        oge.yonlendirmeManevra.textContent = adim ? adim.metin : 'Devam et';
        oge.yonlendirmeMesafe.textContent = mesafeBicimle(durum.ilerleme.sonrakiManevraM);
        // Süre, rotanın kendi temposundan: sabit yürüyüş hızı varsaymak yerine
        // servisin o rota için öngördüğü tempo kalan mesafeye uygulanıyor.
        var kalanSaniye = sonRota.mesafeM > 0
          ? sonRota.sureSn * (durum.ilerleme.kalanM / sonRota.mesafeM)
          : 0;

        oge.yonlendirmeKalan.textContent =
          'Kalan: ' + mesafeBicimle(durum.ilerleme.kalanM) +
          ' · ' + rotaSuresiBicimle(kalanSaniye);

        // Toplam yürüyüşün ne kadarı bitti: çubuk ve sayılar.
        var oran = sonRota.mesafeM > 0
          ? Math.min(100, 100 * durum.ilerleme.katEdilenM / sonRota.mesafeM)
          : 0;
        oge.yonlendirmeCubuk.style.width = oran.toFixed(1) + '%';
        oge.yonlendirmeYurunen.textContent = mesafeBicimle(durum.ilerleme.katEdilenM);
        oge.yonlendirmeToplam.textContent = mesafeBicimle(sonRota.mesafeM);

        yonlendirmeUyarisiYaz(
          durum.konum.dogrulukM > 100
            ? 'Konum ±' + Math.round(durum.konum.dogrulukM) + ' m — yönlendirme şaşabilir.'
            : ''
        );

        if (typeof durum.aci === 'number') sonYonAcisi = durum.aci;

        if (harita) {
          // Ok ekranda dik durur; dönen haritadır (mobildeki gibi).
          harita.konumuGoster(durum.konum, { yonlendirme: true, aci: 0 });
          harita.konumaOdaklan(durum.konum, sonRotaKip === 'araba' ? 16 : 17);
          // Pusula varsa telefonun baktığı yön, yoksa hareket yönü.
          harita.haritayiYoneCevir(pusulaAcisi !== null ? pusulaAcisi : sonYonAcisi);
        }
      },

      yenidenHesapla: function (konum) {
        // Rotadan çıkıldı: yeni konumdan aynı hedefe rota istenir.
        yonlendirmeUyarisiYaz('Rotadan çıktın, yeniden hesaplanıyor…');
        sonKonum = { enlem: konum.enlem, boylam: konum.boylam };

        rotaAl(sonKonum, sonRotaHedefi.konum, sonRotaKip)
          .then(function (yeni) {
            sonRota = yeni;
            if (harita) harita.rotayiCiz(yeni.noktalar, yeni.kip);
            rotaSonucunuYaz(yeni, sonRotaHedefi);
            yonlendirmeyiBaslat();
          })
          .catch(function () {
            yonlendirmeUyarisiYaz('Yeni rota alınamadı, yönlendirme durduruldu.');
            yonlendirmeyiBitir();
          });
      },

      bitti: function (sebep) {
        if (sebep === 'varildi') {
          oge.yonlendirmeManevra.textContent = sonRotaHedefi.ad + ' durağına vardın.';
          oge.yonlendirmeMesafe.textContent = '✓';
          oge.yonlendirmeKalan.textContent = 'Yolculuk başlasın.';
          yonlendirmeUyarisiYaz('');
        } else if (sebep === 'hata') {
          yonlendirmeUyarisiYaz('Konum alınamadı, yönlendirme durduruldu.');
        }
        yonlendirmeOturumu = null;
      }
    });
  }

  function yonlendirmeyiBitir() {
    if (yonlendirmeOturumu) yonlendirmeOturumu.durdur();
    yonlendirmeOturumu = null;
    oge.yonlendirmePaneli.hidden = true;
    if (typeof speechSynthesis !== 'undefined') speechSynthesis.cancel();

    if (pusulayiDurdur) pusulayiDurdur();
    pusulayiDurdur = null;
    pusulaAcisi = null;
    if (harita) harita.haritayiKuzeyeAl();

    // İşaret yön okundan sürüklenebilir iğneye geri dönsün.
    if (harita && sonKonum) harita.konumuGoster(sonKonum);

    // Yönlendirme bittiğinde işaret yine canlı kalsın.
    if (!elleKonumuOku()) takibiBaslat();
  }

  /* ---------- Harita ---------- */

  function haritayiKur() {
    if (typeof haritaKur !== 'function' || typeof L === 'undefined') return;

    harita = haritaKur(
      'harita',
      function duragaTiklandi(durak) {
        // Haritadan durak seçmek, biniş listesinden seçmekle aynı şey.
        oge.binis.value = durak.kod;
        if (oge.inis.value === oge.binis.value) {
          var kodlar = aktifDuraklar.map(function (d) { return d.kod; });
          var indeks = kodlar.indexOf(durak.kod);
          oge.inis.value = indeks < kodlar.length / 2 ? kodlar[kodlar.length - 1] : kodlar[0];
        }
        guncelle();
      },
      function konumSuruklendi(konum) {
        // Sürükleme, masaüstünde şaşan tarayıcı konumunu düzeltmenin en doğrudan yolu.
        if (izlemeyiDurdur) izlemeyiDurdur();
        takibiKapat();
        konumuIsle({ enlem: konum.enlem, boylam: konum.boylam, dogrulukM: null }, true);
        elleKonumuKaydet(konum, 'haritadan seçtiğin nokta');
      }
    );

    harita.duraklariCiz(aktifDuraklar);
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
    if (harita) harita.guzergahiVurgula(sonuc);
    seferleriGoster(sonuc);
    geziYerleriniCiz(sonuc);
  }

  /**
   * Açılış ekranını kapatır.
   *
   * Sayfa arkada zaten hazırlanıyor; ekran yalnızca marka animasyonu için
   * duruyor. Dokunmak, tuşa basmak veya süre dolması kapatır. Hareket
   * azaltma isteyen kullanıcıda süre kısalır.
   */
  function acilisiKur() {
    var ekran = document.getElementById('acilisEkrani');
    if (!ekran) return;

    document.body.classList.add('acilis-acik');

    var azHareket = window.matchMedia &&
      window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    var sure = azHareket ? 700 : 2000;
    var sayac = null;

    function kapat() {
      if (!ekran) return;
      clearTimeout(sayac);
      ekran.classList.add('acilis--kapali');
      document.body.classList.remove('acilis-acik');
      document.removeEventListener('keydown', kapat);

      var gidecek = ekran;
      ekran = null;
      // Geçiş bitince DOM'dan tamamen kalksın: üstünde duran kaplama,
      // haritanın dokunma olaylarını yutuyordu.
      setTimeout(function () { gidecek.remove(); }, 600);
    }

    sayac = setTimeout(kapat, sure);
    ekran.addEventListener('click', kapat);
    document.addEventListener('keydown', kapat);
  }

  function baslat() {
    acilisiKur();
    temayiBaslat();
    oge.dil.addEventListener('click', dilDegistir);
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

    oge.yolTarifi.addEventListener('click', function () {
      if (yakinDurak) kipleYolTarifi('yuruyus');
    });

    oge.arabaTarifi.addEventListener('click', function () {
      if (yakinDurak) kipleYolTarifi('araba');
    });

    // Kip düğmeleri aynı hedefe farklı kiple yeniden rota ister.
    oge.rotaKipYuruyus.addEventListener('click', function () {
      siralamaKipiniDegistir('yuruyus');
      if (sonRotaHedefi) yolTarifiniGoster(sonRotaHedefi, 'yuruyus');
    });
    oge.rotaKipAraba.addEventListener('click', function () {
      siralamaKipiniDegistir('araba');
      if (sonRotaHedefi) yolTarifiniGoster(sonRotaHedefi, 'araba');
    });

    oge.binisYolTarifi.addEventListener('click', function () {
      if (oge.binisYolTarifi.__durak) yolTarifiniGoster(oge.binisYolTarifi.__durak);
    });

    oge.rotaTemizle.addEventListener('click', rotayiTemizle);
    oge.yonlendirmeBaslat.addEventListener('click', yonlendirmeyiBaslat);
    oge.yonlendirmeBitir.addEventListener('click', yonlendirmeyiBitir);

    aramayiBagla();

    haritayiKur();
    diliUygula();   // guncelle() bunun içinde çağrılıyor
    firestoreDanTazele();
    konumuBaslat();
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
          if (harita) harita.duraklariCiz(aktifDuraklar);

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
