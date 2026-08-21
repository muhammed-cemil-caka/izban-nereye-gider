#!/usr/bin/env node
/**
 * duraklar.json'a İZBAN resmî istasyon kimliklerini ekler.
 *
 *   node araclar/izban-kimlik-ekle.js
 *
 * Kimlikler sefer saatleri servisinde kullanılıyor:
 *   https://openapi.izmir.bel.tr/api/izban/sefersaatleri/{kalkis}/{varis}
 *
 * Kaynak: İzmir Büyükşehir Belediyesi açık veri portalı (openapi.izmir.bel.tr).
 * Servis CORS'a açık (access-control-allow-origin: *), istemciden doğrudan
 * çağrılabiliyor.
 *
 * Eklenen alan: izbanId
 */
const fs = require('fs');
const path = require('path');

const ISTASYONLAR = 'https://openapi.izmir.bel.tr/api/izban/istasyonlar';

// Bizdeki ad ile resmî ad birebir tutmuyor.
const TAKMA_ADLAR = {
  'alsancak gar': 'alsancak',
  'havalimani': 'adnan menderes havalimani'
};

const normalle = (s) => s.toLowerCase()
  .replace(/ı/g, 'i').replace(/ğ/g, 'g').replace(/ü/g, 'u')
  .replace(/ş/g, 's').replace(/ö/g, 'o').replace(/ç/g, 'c')
  .replace(/\s+/g, ' ').trim();

(async () => {
  const yanit = await fetch(ISTASYONLAR, { signal: AbortSignal.timeout(30000) });
  if (!yanit.ok) {
    console.error('İstasyon servisi yanıtı:', yanit.status);
    process.exit(1);
  }

  const istasyonlar = await yanit.json();
  const harita = new Map(istasyonlar.map((i) => [normalle(i.IstasyonAdi), i]));

  const hedefYolu = path.join(__dirname, '..', 'backend', 'veri', 'duraklar.json');
  const veri = JSON.parse(fs.readFileSync(hedefYolu, 'utf8'));

  let eslesen = 0;
  const eksik = [];

  for (const durak of veri.duraklar) {
    const ad = normalle(durak.ad);
    const istasyon = harita.get(ad) || harita.get(TAKMA_ADLAR[ad] || '');

    if (istasyon) {
      durak.izbanId = istasyon.IstasyonId;
      eslesen++;
    } else {
      delete durak.izbanId;
      eksik.push(durak.ad);
    }
  }

  const parca = String(veri.surum).split('.').map(Number);
  veri.surum = `${parca[0]}.${parca[1] + 1}.0`;
  veri.guncellemeTarihi = new Date().toISOString().slice(0, 10);
  veri.kaynak = veri.kaynak || {};
  veri.kaynak.seferSaatleri =
    'İzmir Büyükşehir Belediyesi açık veri — openapi.izmir.bel.tr/api/izban';

  fs.writeFileSync(hedefYolu, JSON.stringify(veri, null, 2) + '\n');

  console.log(`${eslesen}/${veri.duraklar.length} durak eşleşti.`);
  if (eksik.length) console.log('Eşleşmeyen:', eksik.join(', '));
  console.log(`Sürüm ${veri.surum} yazıldı.`);
})();
