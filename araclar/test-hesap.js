#!/usr/bin/env node
// Bağımlılıksız doğrulama: node araclar/test-hesap.js
//
// Mantık testleri sentetik veriyle çalışır — gerçek durak listesi değiştiğinde
// kırılmasınlar diye. Gerçek dosya ayrıca bütünlük açısından denetlenir.
const assert = require('assert');
const { HAT_VERISI, DURAKLAR } = require('../frontend/js/duraklar.js');
const {
  yolculukHesapla, sureBicimle,
  metreUzaklik, mesafeBicimle, enYakinDurak, yolTarifiAdresi
} = require('../frontend/js/hesap.js');

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

dogrula('yol tarifi adresi yürüyüş modunda ve doğru hedefte', () => {
  const adres = yolTarifiAdresi(KONUMLU[0]);
  assert.ok(adres.startsWith('https://www.google.com/maps/dir/?api=1'));
  assert.ok(adres.includes('destination=38.43519,27.168837'));
  assert.ok(adres.includes('travelmode=walking'));
});

dogrula('gerçek veride her durak en yakın aday olabiliyor', () => {
  // Her durağın kendi koordinatı verildiğinde kendisi bulunmalı.
  DURAKLAR.forEach((d) => {
    assert.strictEqual(enYakinDurak(DURAKLAR, d.konum).durak.kod, d.kod, `${d.ad} kendini bulmalı`);
  });
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

console.log(`\n${sayac} test geçti.\n`);
