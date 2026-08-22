#!/usr/bin/env node
// Bağımlılıksız doğrulama: node araclar/test-hesap.js
//
// Mantık testleri sentetik veriyle çalışır — gerçek durak listesi değiştiğinde
// kırılmasınlar diye. Gerçek dosya ayrıca bütünlük açısından denetlenir.
const assert = require('assert');
// Sözlük ilk yüklenmeli: hesap.js ve rota.js metinlerini buradan alıyor,
// klasik script olarak yüklendiklerinde küresel oluyorlar.
require('../frontend/js/diller.js');
const { HAT_VERISI, DURAKLAR } = require('../frontend/js/duraklar.js');
const {
  yolculukHesapla, sureBicimle,
  metreUzaklik, mesafeBicimle, enYakinDurak, enYakinDuraklar,
  durakAra, aramaIcinSadelestir
} = require('../frontend/js/hesap.js');
const { manevrayiTurkcelestir, yolAdiniCevir, rotaSuresiBicimle } = require('../frontend/js/rota.js');
const {
  seferZinciri, zincirYollari, ilkBaglanti, yolculuguKur,
  baskinOlanlar, siradakiSeferler
} = require('../frontend/js/sefer.js');
const {
  rotayaIzdusur, adimSinirlariniKur, rotaIlerlemesi, yonAcisi
} = require('../frontend/js/yonlendirme.js');

let sayac = 0;
function dogrula(baslik, fn) { fn(); sayac++; console.log('  ✓ ' + baslik); }

const ORNEK = [
  { kod: 'a', ad: 'A', ilce: 'İl', dakika: 0, aktarma: [] },
  { kod: 'b', ad: 'B', ilce: 'İl', dakika: 10, aktarma: ['Metro'] },
  { kod: 'c', ad: 'C', ilce: 'İl', dakika: 25, aktarma: [] },
  { kod: 'd', ad: 'D', ilce: 'İl', dakika: 70, aktarma: ['Vapur'] }
];

console.log('\nYolculuk hesabı');

dogrula('güneye yolculuk yönü ve durak sayısı', () => {
  const s = yolculukHesapla(ORNEK, 'a', 'c');
  assert.strictEqual(s.gecerli, true);
  assert.strictEqual(s.yon, 'guney');
  assert.strictEqual(s.durakSayisi, 2);
  assert.strictEqual(s.dakika, 25);
  assert.strictEqual(s.guzergah[0].kod, 'a');
  assert.strictEqual(s.guzergah.at(-1).kod, 'c');
});

dogrula('kuzeye yolculukta güzergâh ters sırada', () => {
  const s = yolculukHesapla(ORNEK, 'd', 'b');
  assert.strictEqual(s.yon, 'kuzey');
  assert.strictEqual(s.guzergah[0].kod, 'd');
  assert.strictEqual(s.guzergah.at(-1).kod, 'b');
});

dogrula('süre iki yönde de aynı', () => {
  assert.strictEqual(
    yolculukHesapla(ORNEK, 'a', 'd').dakika,
    yolculukHesapla(ORNEK, 'd', 'a').dakika
  );
});

dogrula('aynı durak seçilemez', () => {
  assert.strictEqual(yolculukHesapla(ORNEK, 'b', 'b').gecerli, false);
});

dogrula('bilinmeyen durak kodu reddedilir', () => {
  assert.strictEqual(yolculukHesapla(ORNEK, 'b', 'yokboyle').gecerli, false);
});

dogrula('aktarmalar güzergâh içinden süzülür', () => {
  const s = yolculukHesapla(ORNEK, 'a', 'c');
  assert.deepStrictEqual(s.aktarmalar.map((x) => x.ad), ['B']);
});

dogrula('süre biçimlendirme', () => {
  assert.strictEqual(sureBicimle(45), '45 dk');
  assert.strictEqual(sureBicimle(60), '1 sa');
  assert.strictEqual(sureBicimle(140), '2 sa 20 dk');
});

console.log('\nKonum ve en yakın durak');

// Gerçek koordinatlar: Halkapınar, Alsancak Gar, Selçuk
const KONUMLU = [
  { kod: 'halkapinar', ad: 'Halkapınar', konum: { enlem: 38.435190, boylam: 27.168837 } },
  { kod: 'alsancak-gar', ad: 'Alsancak Gar', konum: { enlem: 38.438597, boylam: 27.148762 } },
  { kod: 'selcuk', ad: 'Selçuk', konum: { enlem: 37.950734, boylam: 27.373029 } }
];

dogrula('mesafe hesabı bilinen aralıkta', () => {
  // Halkapınar ile Alsancak Gar arası kuş uçuşu yaklaşık 1,8 km
  const m = metreUzaklik(KONUMLU[0].konum, KONUMLU[1].konum);
  assert.ok(m > 1500 && m < 2100, `beklenmedik mesafe: ${Math.round(m)} m`);
});

dogrula('aynı noktanın mesafesi sıfır', () => {
  assert.strictEqual(Math.round(metreUzaklik(KONUMLU[0].konum, KONUMLU[0].konum)), 0);
});

dogrula('mesafe biçimlendirme', () => {
  assert.strictEqual(mesafeBicimle(450), '450 m');
  assert.strictEqual(mesafeBicimle(999), '999 m');
  assert.strictEqual(mesafeBicimle(2300), '2,3 km');
});

dogrula('en yakın durak doğru seçiliyor', () => {
  // Halkapınar'ın hemen yanındaki bir nokta
  const sonuc = enYakinDurak(KONUMLU, { enlem: 38.4360, boylam: 27.1690 });
  assert.strictEqual(sonuc.durak.kod, 'halkapinar');
  assert.ok(sonuc.mesafeM < 500);
});

dogrula('uzak konumda da en yakın olan bulunuyor', () => {
  const sonuc = enYakinDurak(KONUMLU, { enlem: 37.96, boylam: 27.37 });
  assert.strictEqual(sonuc.durak.kod, 'selcuk');
});

dogrula('koordinatsız duraklar atlanıyor', () => {
  const karisik = [
    { kod: 'yok', ad: 'Koordinatsız', konum: { enlem: 0, boylam: 0 } },
    KONUMLU[0]
  ];
  assert.strictEqual(enYakinDurak(karisik, { enlem: 38.44, boylam: 27.17 }).durak.kod, 'halkapinar');
});

dogrula('hiç aday yoksa null döner', () => {
  assert.strictEqual(enYakinDurak([], { enlem: 38.4, boylam: 27.1 }), null);
});

dogrula('en yakın duraklar mesafeye göre sıralı', () => {
  const liste = enYakinDuraklar(KONUMLU, { enlem: 38.4360, boylam: 27.1690 }, 3);
  assert.strictEqual(liste.length, 3);
  assert.strictEqual(liste[0].durak.kod, 'halkapinar');
  for (let i = 1; i < liste.length; i++) {
    assert.ok(liste[i].mesafeM >= liste[i - 1].mesafeM, 'mesafeler artan olmalı');
  }
});

dogrula('istenen adetten fazla durak döndürülmüyor', () => {
  assert.strictEqual(enYakinDuraklar(DURAKLAR, DURAKLAR[0].konum, 4).length, 4);
  assert.strictEqual(enYakinDuraklar(KONUMLU, KONUMLU[0].konum, 10).length, 3);
});

dogrula('Mavişehir yakınından bakınca Mavişehir birinci sırada', () => {
  // Mavişehir İZBAN istasyonunun ~400 m batısı
  const liste = enYakinDuraklar(DURAKLAR, { enlem: 38.4822, boylam: 27.0784 }, 3);
  assert.strictEqual(liste[0].durak.ad, 'Mavişehir', `birinci: ${liste[0].durak.ad}`);
});

dogrula('Çiğli yakınından bakınca Çiğli birinci sırada', () => {
  const liste = enYakinDuraklar(DURAKLAR, { enlem: 38.4916, boylam: 27.0640 }, 3);
  assert.strictEqual(liste[0].durak.ad, 'Çiğli', `birinci: ${liste[0].durak.ad}`);
});

dogrula('gerçek veride her durak en yakın aday olabiliyor', () => {
  // Her durağın kendi koordinatı verildiğinde kendisi bulunmalı.
  DURAKLAR.forEach((d) => {
    assert.strictEqual(enYakinDurak(DURAKLAR, d.konum).durak.kod, d.kod, `${d.ad} kendini bulmalı`);
  });
});

console.log('\nYürüyüş rotası');

dogrula('manevralar Türkçeleştiriliyor', () => {
  assert.strictEqual(
    manevrayiTurkcelestir({ type: 'depart', modifier: 'left' }, '8294. Sokak'),
    'Yola çık — 8294. Sokak'
  );
  assert.strictEqual(
    manevrayiTurkcelestir({ type: 'turn', modifier: 'left' }, '6525. Sokak'),
    'Sola dön — 6525. Sokak'
  );
  assert.strictEqual(
    manevrayiTurkcelestir({ type: 'turn', modifier: 'slight right' }, ''),
    'Hafif sağa dön'
  );
  assert.strictEqual(
    manevrayiTurkcelestir({ type: 'end of road', modifier: 'right' }, 'Atatürk Cd.'),
    'Yolun sonunda sağa dön — Atatürk Cd.'
  );
  assert.strictEqual(manevrayiTurkcelestir({ type: 'arrive' }, ''), 'Vardın');
});

dogrula('bilinmeyen manevra makul bir metne düşüyor', () => {
  assert.strictEqual(manevrayiTurkcelestir({ type: 'notify' }, ''), 'Devam et');
});

dogrula('yol adı Türkçede olduğu gibi kalıyor', () => {
  assert.strictEqual(yolAdiniCevir('6525. Sokak'), '6525. Sokak');
  assert.strictEqual(yolAdiniCevir('İzmir Çevre Yolu'), 'İzmir Çevre Yolu');
});

dogrula('İngilizcede yol türü çevriliyor, özel isim kalıyor', () => {
  dilAyarla('en');
  assert.strictEqual(yolAdiniCevir('Namık Kemal Caddesi'), 'Namık Kemal Avenue');
  assert.strictEqual(yolAdiniCevir('Atatürk Bulvarı'), 'Atatürk Boulevard');
  assert.strictEqual(yolAdiniCevir('Cumhuriyet Meydanı'), 'Cumhuriyet Square');
  // "Çevre Yolu" daha genel "Yolu"dan önce denenmeli.
  assert.strictEqual(yolAdiniCevir('İzmir Çevre Yolu'), 'İzmir Ring Road');
  // İngilizcede numara türden sonra gelir.
  assert.strictEqual(yolAdiniCevir('6525. Sokak'), 'Street 6525');
  // Tanınmayan ad dokunulmadan geçer.
  assert.strictEqual(yolAdiniCevir('Kordon'), 'Kordon');
  dilAyarla('tr');
});

dogrula('adım metni okunduğu anda çevriliyor', () => {
  // Rota nesnesi Türkçe kurulup dil değişince adımlar da değişmeli: sesli
  // yönlendirme eski dilde okumasın.
  var adim = {
    tur: 'turn', yonKodu: 'left', yolAdi: '6525. Sokak', mesafeM: 40,
    get metin() {
      return manevrayiTurkcelestir({ type: this.tur, modifier: this.yonKodu }, this.yolAdi);
    }
  };
  assert.strictEqual(adim.metin, 'Sola dön — 6525. Sokak');
  dilAyarla('en');
  assert.strictEqual(adim.metin, 'Turn left — Street 6525');
  dilAyarla('tr');
});

dogrula('yürüyüş süresi biçimlendirme', () => {
  assert.strictEqual(rotaSuresiBicimle(1140), '19 dk');
  assert.strictEqual(rotaSuresiBicimle(20), '1 dk');
  assert.strictEqual(rotaSuresiBicimle(3600), '1 sa');
  assert.strictEqual(rotaSuresiBicimle(4500), '1 sa 15 dk');
});

console.log('\nYönlendirme geometrisi');

// Doğu yönünde uzanan düz bir rota: 38.4800 enleminde, ~1 km.
// 27.0000 → 27.0115 boylamı, 38.48'de yaklaşık 1000 m eder.
const DUZ_ROTA = {
  noktalar: [[38.48, 27.0], [38.48, 27.00575], [38.48, 27.0115]],
  mesafeM: 1000,
  adimlar: [
    { metin: 'Yola çık', mesafeM: 500 },
    { metin: 'Sağa dön', mesafeM: 400 },
    { metin: 'Vardın', mesafeM: 100 }
  ]
};
const DUZ_SINIRLAR = adimSinirlariniKur(DUZ_ROTA.adimlar);

dogrula('adım sınırları kümülatif', () => {
  assert.deepStrictEqual(DUZ_SINIRLAR, [500, 900, 1000]);
});

dogrula('rota üzerindeki nokta sıfıra yakın sapma veriyor', () => {
  const iz = rotayaIzdusur({ enlem: 38.48, boylam: 27.00575 }, DUZ_ROTA.noktalar);
  assert.ok(iz.sapmaM < 1, `sapma: ${iz.sapmaM.toFixed(2)} m`);
  // Rotanın ortası: ~500 m kat edilmiş olmalı
  assert.ok(Math.abs(iz.katEdilenM - 500) < 25, `kat edilen: ${iz.katEdilenM.toFixed(0)} m`);
});

dogrula('rotadan uzaklaşan nokta sapma veriyor', () => {
  // Kuzeye ~100 m kayık
  const iz = rotayaIzdusur({ enlem: 38.4809, boylam: 27.00575 }, DUZ_ROTA.noktalar);
  assert.ok(iz.sapmaM > 80 && iz.sapmaM < 120, `sapma: ${iz.sapmaM.toFixed(0)} m`);
});

dogrula('rota başındaki nokta sıfır ilerleme veriyor', () => {
  const iz = rotayaIzdusur({ enlem: 38.48, boylam: 27.0 }, DUZ_ROTA.noktalar);
  assert.ok(iz.katEdilenM < 5, `kat edilen: ${iz.katEdilenM.toFixed(1)} m`);
});

dogrula('ilk adımdayken doğru adım ve manevra mesafesi', () => {
  // ~250 m ilerlemiş
  const i = rotaIlerlemesi({ enlem: 38.48, boylam: 27.002875 }, DUZ_ROTA, DUZ_SINIRLAR);
  assert.strictEqual(i.adimIndeksi, 0);
  assert.ok(Math.abs(i.sonrakiManevraM - 250) < 30, `manevraya: ${i.sonrakiManevraM.toFixed(0)} m`);
  assert.strictEqual(i.vardiMi, false);
});

dogrula('ikinci adıma geçiş algılanıyor', () => {
  // ~700 m ilerlemiş → ikinci adım (500-900 arası)
  const i = rotaIlerlemesi({ enlem: 38.48, boylam: 27.008 }, DUZ_ROTA, DUZ_SINIRLAR);
  assert.strictEqual(i.adimIndeksi, 1, `adım: ${i.adimIndeksi}, kat edilen: ${i.katEdilenM.toFixed(0)}`);
});

dogrula('hedefe yaklaşınca varış algılanıyor', () => {
  const i = rotaIlerlemesi({ enlem: 38.48, boylam: 27.0115 }, DUZ_ROTA, DUZ_SINIRLAR);
  assert.strictEqual(i.vardiMi, true);
  assert.ok(i.kalanM < 25);
});

dogrula('kalan mesafe ilerledikçe azalıyor', () => {
  const bas = rotaIlerlemesi({ enlem: 38.48, boylam: 27.0 }, DUZ_ROTA, DUZ_SINIRLAR);
  const orta = rotaIlerlemesi({ enlem: 38.48, boylam: 27.00575 }, DUZ_ROTA, DUZ_SINIRLAR);
  assert.ok(orta.kalanM < bas.kalanM, 'ortada kalan mesafe daha az olmalı');
});

dogrula('yön açısı ana yönlerde doğru', () => {
  var merkez = { enlem: 38.48, boylam: 27.0 };
  // Kuzey 0°, doğu 90°, güney 180°, batı 270°
  assert.ok(Math.abs(yonAcisi(merkez, { enlem: 38.49, boylam: 27.0 }) - 0) < 1, 'kuzey');
  assert.ok(Math.abs(yonAcisi(merkez, { enlem: 38.48, boylam: 27.01 }) - 90) < 1, 'doğu');
  assert.ok(Math.abs(yonAcisi(merkez, { enlem: 38.47, boylam: 27.0 }) - 180) < 1, 'güney');
  assert.ok(Math.abs(yonAcisi(merkez, { enlem: 38.48, boylam: 26.99 }) - 270) < 1, 'batı');
});

dogrula('yön açısı 0-360 aralığında kalıyor', () => {
  var merkez = { enlem: 38.48, boylam: 27.0 };
  [[38.49, 26.99], [38.47, 27.01], [38.485, 27.005]].forEach(function (n) {
    var aci = yonAcisi(merkez, { enlem: n[0], boylam: n[1] });
    assert.ok(aci >= 0 && aci < 360, `aralık dışı: ${aci}`);
  });
});

dogrula('bozuk rota çökmüyor', () => {
  const bos = rotayaIzdusur({ enlem: 38.48, boylam: 27.0 }, []);
  assert.strictEqual(bos.sapmaM, 0);
  const tek = rotayaIzdusur({ enlem: 38.48, boylam: 27.0 }, [[38.48, 27.0]]);
  assert.strictEqual(tek.katEdilenM, 0);
});

dogrula('üst üste binen noktalar sıfıra bölmeye yol açmıyor', () => {
  const iz = rotayaIzdusur(
    { enlem: 38.48, boylam: 27.002 },
    [[38.48, 27.0], [38.48, 27.0], [38.48, 27.0115]]
  );
  assert.ok(Number.isFinite(iz.sapmaM), 'sapma sayı olmalı');
  assert.ok(Number.isFinite(iz.katEdilenM), 'kat edilen sayı olmalı');
});

console.log('\nDurak arama');

dogrula('Türkçe karakter sadeleştirmesi', () => {
  assert.strictEqual(aramaIcinSadelestir('Şirinyer'), 'sirinyer');
  assert.strictEqual(aramaIcinSadelestir('ÇİĞLİ'), 'cigli');
  assert.strictEqual(aramaIcinSadelestir('  Halkapınar '), 'halkapinar');
});

dogrula('Türkçe karakter yazmadan durak bulunuyor', () => {
  const sonuc = durakAra(DURAKLAR, 'mavisehir');
  assert.strictEqual(sonuc.length, 1);
  assert.strictEqual(sonuc[0].ad, 'Mavişehir');
});

dogrula('büyük/küçük harf ayrımı yok', () => {
  assert.strictEqual(durakAra(DURAKLAR, 'SELÇUK').length, durakAra(DURAKLAR, 'selcuk').length);
});

dogrula('parça eşleşmesi çalışıyor', () => {
  const sonuc = durakAra(DURAKLAR, 'kent');
  const adlar = sonuc.map((d) => d.ad);
  assert.ok(adlar.includes('Egekent'), 'Egekent bulunmalı');
  assert.ok(adlar.includes('Ulukent'), 'Ulukent bulunmalı');
});

dogrula('ilçeye göre de arama yapılıyor', () => {
  const sonuc = durakAra(DURAKLAR, 'gaziemir');
  assert.ok(sonuc.length >= 3, `Gaziemir ilçesinde en az 3 durak olmalı, bulunan: ${sonuc.length}`);
});

dogrula('çok kısa sorgu sonuç döndürmüyor', () => {
  assert.strictEqual(durakAra(DURAKLAR, 'a').length, 0);
  assert.strictEqual(durakAra(DURAKLAR, '').length, 0);
});

dogrula('eşleşmeyen sorgu boş dönüyor', () => {
  assert.strictEqual(durakAra(DURAKLAR, 'ankaragucu').length, 0);
});

console.log('\nGerçek durak verisi');

dogrula('sürüm ve hat bilgisi var', () => {
  assert.ok(/^\d+\.\d+\.\d+$/.test(HAT_VERISI.surum), 'sürüm x.y.z olmalı');
  assert.ok(HAT_VERISI.hat.kuzeyUcu && HAT_VERISI.hat.guneyUcu);
});

dogrula('durak kodları benzersiz ve boş değil', () => {
  const kodlar = DURAKLAR.map((d) => d.kod);
  kodlar.forEach((k, i) => {
    assert.ok(k && k.length >= 3, `${DURAKLAR[i].ad} için geçersiz kod: "${k}"`);
    assert.ok(/^[a-z0-9-]+$/.test(k), `kod ASCII slug olmalı: "${k}"`);
  });
  assert.strictEqual(new Set(kodlar).size, kodlar.length, 'kodlar benzersiz olmalı');
});

dogrula('süreler ve mesafeler kesin artan', () => {
  for (let i = 1; i < DURAKLAR.length; i++) {
    assert.ok(
      DURAKLAR[i].dakika > DURAKLAR[i - 1].dakika,
      `${DURAKLAR[i].ad} süresi önceki duraktan büyük olmalı`
    );
    assert.ok(
      DURAKLAR[i].mesafeKm > DURAKLAR[i - 1].mesafeKm,
      `${DURAKLAR[i].ad} mesafesi önceki duraktan büyük olmalı`
    );
  }
});

dogrula('her durakta İzmir sınırları içinde koordinat var', () => {
  DURAKLAR.forEach((d) => {
    assert.ok(d.konum, `${d.ad} için konum yok`);
    assert.ok(d.konum.enlem > 37.8 && d.konum.enlem < 39.0, `${d.ad} enlem aralık dışı`);
    assert.ok(d.konum.boylam > 26.8 && d.konum.boylam < 27.7, `${d.ad} boylam aralık dışı`);
  });
});

dogrula('ardışık duraklar birbirinden ayrı ve makul yakınlıkta', () => {
  const R = 6371;
  for (let i = 1; i < DURAKLAR.length; i++) {
    const a = DURAKLAR[i - 1].konum;
    const b = DURAKLAR[i].konum;
    const p = Math.PI / 180;
    const h = Math.sin((b.enlem - a.enlem) * p / 2) ** 2 +
      Math.cos(a.enlem * p) * Math.cos(b.enlem * p) *
      Math.sin((b.boylam - a.boylam) * p / 2) ** 2;
    const km = 2 * R * Math.asin(Math.sqrt(h));
    assert.ok(km > 0.3, `${DURAKLAR[i].ad} bir öncekiyle neredeyse aynı yerde (${km.toFixed(2)} km)`);
    assert.ok(km < 25, `${DURAKLAR[i].ad} bir öncekinden çok uzak (${km.toFixed(1)} km)`);
  }
});

dogrula('uçtan uca yolculuk tutarlı', () => {
  const s = yolculukHesapla(DURAKLAR, DURAKLAR[0].kod, DURAKLAR.at(-1).kod);
  assert.strictEqual(s.gecerli, true);
  assert.strictEqual(s.durakSayisi, DURAKLAR.length - 1);
  assert.strictEqual(s.yon, 'guney');
});

/* ---------- ESHOT otobüs hatları ---------- */

const {
  eshotSayilirMi, hatlariCoz, duragaYakinHatlar, hatSirala
} = require('./eshot-hatlari.js');

dogrula('ESHOT işletmecisi tanınıyor, başkası elenir', () => {
  assert.strictEqual(eshotSayilirMi({ operator: 'ESHOT' }), true);
  assert.strictEqual(eshotSayilirMi({ operator: 'Eshot' }), true);
  assert.strictEqual(eshotSayilirMi({ network: 'ESHOT Genel Müdürlüğü' }), true);
  // İşletmecisi yazmayan İzmir hatları ESHOT sayılır (ör. 535, 912).
  assert.strictEqual(eshotSayilirMi({}), true);
  // Özel halk otobüsü kooperatifi ESHOT değildir.
  assert.strictEqual(
    eshotSayilirMi({ operator: '34 no.lu Menemen Özel Halk Otobüsleri kooperatifi' }),
    false
  );
});

// Halkapınar'ın ~100 m kuzeyinde bir otobüs durağı, bir de kilometrelerce uzakta.
const OSM_YANITI = {
  elements: [
    { type: 'node', id: 1, lat: 38.4361, lon: 27.1688 },
    { type: 'node', id: 2, lat: 38.4800, lon: 27.1000 },
    { type: 'relation', id: 10, tags: { ref: '445', operator: 'ESHOT' },
      members: [{ type: 'node', ref: 1 }] },
    { type: 'relation', id: 11, tags: { ref: '800', operator: '34 no.lu Menemen Ozel Halk Otobusleri kooperatifi' },
      members: [{ type: 'node', ref: 1 }] },
    { type: 'relation', id: 12, tags: { name: '912 Egekent Aktarma Merkezi-Alsancak Gar' },
      members: [{ type: 'node', ref: 1 }] },
    { type: 'relation', id: 13, tags: { ref: '53', operator: 'Eshot' },
      members: [{ type: 'node', ref: 2 }] },
    { type: 'relation', id: 14, tags: { ref: '99', operator: 'ESHOT' },
      members: [{ type: 'way', ref: 500 }] }
  ]
};

dogrula('hat numaraları ref veya ad başından çıkarılır', () => {
  const hatlar = hatlariCoz(OSM_YANITI).map((h) => h.numara).sort(hatSirala);
  // 800 kooperatif olduğu için elenir; 99'un durak düğümü yok.
  assert.deepStrictEqual(hatlar, ['53', '445', '912']);
});

dogrula('yalnızca durağa yakın hatlar sayılır', () => {
  const hatlar = hatlariCoz(OSM_YANITI);
  const halkapinar = { enlem: 38.43519, boylam: 27.168837 };
  assert.deepStrictEqual(duragaYakinHatlar(halkapinar, hatlar), ['445', '912']);

  // Uzaktaki hat, yarıçap büyütülünce listeye girer.
  assert.deepStrictEqual(duragaYakinHatlar(halkapinar, hatlar, 10000), ['53', '445', '912']);
});

dogrula('hat sıralaması sayıca yapılır', () => {
  assert.deepStrictEqual(['154', '53', 'C10', '9'].sort(hatSirala), ['9', '53', '154', 'C10']);
});

console.log('\nSefer saatleri');

// Sentetik hat: aktarma durakları gerçek kodlarıyla, aralara dolgu duraklar.
const SEFER_HATTI = [
  { kod: 'kuzey', ad: 'Kuzey', izbanId: 1 },
  { kod: 'cumaovasi', ad: 'Cumaovası', izbanId: 2 },
  { kod: 'orta', ad: 'Orta', izbanId: 3 },
  { kod: 'tepekoy', ad: 'Tepeköy', izbanId: 4 },
  { kod: 'guney', ad: 'Güney', izbanId: 5 }
];

const sefer = (kalkis, varis) => ({
  kalkis,
  varis,
  kalkisDk: Number(kalkis.slice(0, 2)) * 60 + Number(kalkis.slice(3, 5))
});

const yolculuk = (kalkisDk, varisDk) => ({
  kalkis: '00:00', varis: '00:00', kalkisDk, varisDk, aktarmalar: []
});

dogrula('aradaki aktarma durakları zincire giriyor', () => {
  assert.deepStrictEqual(
    seferZinciri(SEFER_HATTI, 'kuzey', 'guney').map((d) => d.kod),
    ['kuzey', 'cumaovasi', 'tepekoy', 'guney']
  );
});

dogrula('yolculuğun dışındaki aktarma durağı zincire girmiyor', () => {
  assert.deepStrictEqual(
    seferZinciri(SEFER_HATTI, 'orta', 'guney').map((d) => d.kod),
    ['orta', 'tepekoy', 'guney']
  );
});

dogrula('ters yönde zincir yolculuk sırasında', () => {
  assert.deepStrictEqual(
    seferZinciri(SEFER_HATTI, 'guney', 'kuzey').map((d) => d.kod),
    ['guney', 'tepekoy', 'cumaovasi', 'kuzey']
  );
});

dogrula('geçersiz çift zincir üretmiyor', () => {
  assert.strictEqual(seferZinciri(SEFER_HATTI, 'orta', 'orta'), null);
  assert.strictEqual(seferZinciri(SEFER_HATTI, 'orta', 'yokboyle'), null);
  const kimliksiz = [{ kod: 'a', ad: 'A' }].concat(SEFER_HATTI);
  assert.strictEqual(seferZinciri(kimliksiz, 'a', 'guney'), null);
});

dogrula('dört düğümde dört yol çıkıyor', () => {
  const yollar = zincirYollari(4).map((y) => y.join('-')).sort();
  assert.deepStrictEqual(yollar, ['0-1-2-3', '0-1-3', '0-2-3', '0-3']);
});

dogrula('bağlantı en az bekleteni seçiyor', () => {
  const liste = [sefer('08:00', '08:20'), sefer('09:00', '09:20')];
  const b = ilkBaglanti(liste, 7 * 60 + 30);
  assert.strictEqual(b.sefer.kalkis, '08:00');
  assert.strictEqual(b.beklemeDk, 30);
});

dogrula('yetişilemeyecek bağlantı atlanıyor', () => {
  const liste = [sefer('08:00', '08:20'), sefer('09:00', '09:20')];
  // 07:59'da hazır: 08:00'a 1 dk var, en az aktarma süresi 3 dk.
  const b = ilkBaglanti(liste, 7 * 60 + 59);
  assert.strictEqual(b.sefer.kalkis, '09:00');
  assert.strictEqual(b.beklemeDk, 61);
});

dogrula('gece yarısını aşan bekleme doğru', () => {
  const liste = [sefer('08:00', '08:20')];
  assert.strictEqual(ilkBaglanti(liste, 23 * 60 + 30).beklemeDk, 510);
});

dogrula('aktarmasız yolculuk doğrudan kuruluyor', () => {
  const zincir = seferZinciri(SEFER_HATTI, 'kuzey', 'guney');
  const kenarlar = { '0-3': [sefer('08:00', '09:30')] };
  const y = yolculuguKur([0, 3], zincir, kenarlar, kenarlar['0-3'][0]);
  assert.strictEqual(y.kalkis, '08:00');
  assert.strictEqual(y.varis, '09:30');
  assert.strictEqual(y.varisDk, 9 * 60 + 30);
  assert.deepStrictEqual(y.aktarmalar, []);
});

dogrula('iki aktarmalı yolculuk zincirleniyor', () => {
  const zincir = seferZinciri(SEFER_HATTI, 'kuzey', 'guney');
  const kenarlar = {
    '0-1': [sefer('08:00', '08:30')],
    '1-2': [sefer('08:40', '09:10')],
    '2-3': [sefer('09:20', '09:50')]
  };
  const y = yolculuguKur([0, 1, 2, 3], zincir, kenarlar, kenarlar['0-1'][0]);
  assert.strictEqual(y.varis, '09:50');
  assert.deepStrictEqual(y.aktarmalar.map((a) => a.durak), ['Cumaovası', 'Tepeköy']);
  assert.deepStrictEqual(y.aktarmalar.map((a) => a.beklemeDk), [10, 10]);
});

dogrula('çok uzun bekleten bağlantı eleniyor', () => {
  const zincir = seferZinciri(SEFER_HATTI, 'kuzey', 'guney');
  const kenarlar = {
    '0-1': [sefer('08:00', '08:30')],
    // Tek bağlantı ertesi sabah: 3 saatlik sınırın çok üstünde.
    '1-3': [sefer('06:00', '07:00')]
  };
  assert.strictEqual(
    yolculuguKur([0, 1, 3], zincir, kenarlar, kenarlar['0-1'][0]),
    null
  );
});

dogrula('gece yarısını aşan sefer süresi doğru', () => {
  const zincir = seferZinciri(SEFER_HATTI, 'kuzey', 'guney');
  const kenarlar = { '0-3': [sefer('23:40', '00:20')] };
  const y = yolculuguKur([0, 3], zincir, kenarlar, kenarlar['0-3'][0]);
  assert.strictEqual(y.varisDk, 23 * 60 + 40 + 40);
});

dogrula('baskın olmayan yolculuk eleniyor', () => {
  // 06:05 ve 06:57 aynı Selçuk trenine bindiriyor; erkeni beklemeye yarıyor.
  const kalanlar = baskinOlanlar([
    yolculuk(365, 496), yolculuk(417, 496), yolculuk(444, 556)
  ]);
  assert.deepStrictEqual(kalanlar.map((y) => y.kalkisDk), [417, 444]);
});

dogrula('yolculuklar kalkışa göre sıralı dönüyor', () => {
  const kalanlar = baskinOlanlar([
    yolculuk(600, 700), yolculuk(400, 500), yolculuk(500, 600)
  ]);
  assert.deepStrictEqual(kalanlar.map((y) => y.kalkisDk), [400, 500, 600]);
});

dogrula('sıradaki seferler kalan süreyle dönüyor', () => {
  const liste = [yolculuk(480, 540), yolculuk(600, 660), yolculuk(720, 780)];
  const s = siradakiSeferler(liste, 2, 540);
  assert.strictEqual(s.length, 2);
  assert.strictEqual(s[0].kalanDk, 60);
  assert.strictEqual(s[0].ertesiGun, false);
});

dogrula('gün bitince ertesi güne sarılıyor', () => {
  const liste = [yolculuk(480, 540), yolculuk(600, 660)];
  const s = siradakiSeferler(liste, 2, 23 * 60);
  assert.ok(s.every((x) => x.ertesiGun));
  assert.strictEqual(s[0].kalanDk, null);
});

console.log(`\n${sayac} test geçti.\n`);
