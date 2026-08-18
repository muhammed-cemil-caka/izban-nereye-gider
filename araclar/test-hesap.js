#!/usr/bin/env node
// Bağımlılıksız küçük doğrulama: node araclar/test-hesap.js
const assert = require('assert');
const { DURAKLAR } = require('../frontend/js/duraklar.js');
const { yolculukHesapla, sureBicimle } = require('../frontend/js/hesap.js');

let sayac = 0;
function dogrula(baslik, fn) { fn(); sayac++; console.log('  ✓ ' + baslik); }

dogrula('güneye yolculuk yönü ve durak sayısı', () => {
  const s = yolculukHesapla(DURAKLAR, 'halkapinar', 'sirinyer');
  assert.strictEqual(s.gecerli, true);
  assert.strictEqual(s.yon, 'guney');
  assert.strictEqual(s.durakSayisi, 3);
  assert.strictEqual(s.guzergah[0].kod, 'halkapinar');
  assert.strictEqual(s.guzergah[s.guzergah.length - 1].kod, 'sirinyer');
});

dogrula('kuzeye yolculukta güzergâh ters sırada', () => {
  const s = yolculukHesapla(DURAKLAR, 'selcuk', 'aliaga');
  assert.strictEqual(s.yon, 'kuzey');
  assert.strictEqual(s.guzergah[0].kod, 'selcuk');
  assert.strictEqual(s.guzergah[s.guzergah.length - 1].kod, 'aliaga');
  assert.strictEqual(s.durakSayisi, DURAKLAR.length - 1);
});

dogrula('süre iki yönde de aynı', () => {
  const a = yolculukHesapla(DURAKLAR, 'karsiyaka', 'gaziemir').dakika;
  const b = yolculukHesapla(DURAKLAR, 'gaziemir', 'karsiyaka').dakika;
  assert.strictEqual(a, b);
});

dogrula('aynı durak seçilemez', () => {
  assert.strictEqual(yolculukHesapla(DURAKLAR, 'kemer', 'kemer').gecerli, false);
});

dogrula('bilinmeyen durak kodu reddedilir', () => {
  assert.strictEqual(yolculukHesapla(DURAKLAR, 'kemer', 'yokboyle').gecerli, false);
});

dogrula('süre biçimlendirme', () => {
  assert.strictEqual(sureBicimle(45), '45 dk');
  assert.strictEqual(sureBicimle(60), '1 sa');
  assert.strictEqual(sureBicimle(140), '2 sa 20 dk');
});

dogrula('aktarmalar güzergâh içinden geliyor', () => {
  const s = yolculukHesapla(DURAKLAR, 'mavisehir', 'alsancak');
  const adlar = s.aktarmalar.map((a) => a.ad);
  assert.ok(adlar.includes('Halkapınar'));
  assert.ok(!adlar.includes('Adnan Menderes Havalimanı'));
});

console.log('\n' + sayac + ' test geçti.');
