#!/usr/bin/env node
/**
 * Aktarma noktalarının KOORDİNATLARINI duraklar.json'a ekler.
 *
 *   node araclar/aktarma-noktalarini-ekle.js
 *
 * Daha önce aktarma bilgisi yalnızca etiketti ("Metro", "Tramvay"). Kullanıcı
 * "metroya nasıl giderim" diye sorduğunda gidilecek bir nokta yoktu. Artık her
 * aktarma için gerçek durak noktası da saklanıyor; uygulama oradan yürüyüş
 * rotası çizip canlı yönlendirme başlatabiliyor.
 *
 * Eklenen alan:
 *   aktarmaNoktalari: [{ tur: "Metro", ad: "Halkapınar", konum: {...}, mesafeM: 120 }]
 *
 * Tek Overpass isteği atılır: yalnızca İZBAN duraklarının çevresi sorulur.
 * Veri ODbL lisanslıdır.
 */
const fs = require('fs');
const path = require('path');
const { calistir } = require('./overpass.js');
const {
  metreUzaklik,
  eshotDuragiMi,
  OTOBUS_DURAK_YAKINLIK_M
} = require('./eshot-hatlari.js');

// Raylı/vapur aktarmaları için kullanılan mesafe (duraklar.json'daki
// aktarma etiketleri de bu yarıçapla üretilmişti).
const RAYLI_YAKINLIK_M = 600;

/** Tek sorgu: durakların çevresindeki aktarma noktaları. */
function sorguKur(duraklar) {
  const cevre = (tanim, yaricap) => duraklar
    .map((d) => `${tanim.replace('AROUND', `around:${yaricap},${d.enlem},${d.boylam}`)}`)
    .join('\n      ');

  return `
    [out:json][timeout:300];
    (
      ${cevre('node(AROUND)["railway"="tram_stop"];', RAYLI_YAKINLIK_M)}
      ${cevre('node(AROUND)["station"="subway"];', RAYLI_YAKINLIK_M)}
      ${cevre('node(AROUND)["amenity"="ferry_terminal"];', RAYLI_YAKINLIK_M)}
      ${cevre('way(AROUND)["amenity"="ferry_terminal"];', RAYLI_YAKINLIK_M)}
      ${cevre('node(AROUND)["highway"="bus_stop"];', OTOBUS_DURAK_YAKINLIK_M)}
      ${cevre('node(AROUND)["public_transport"="platform"]["bus"="yes"];', OTOBUS_DURAK_YAKINLIK_M)}
      ${cevre('node(AROUND)["amenity"="bus_station"];', OTOBUS_DURAK_YAKINLIK_M)}
    );
    out center tags;
  `;
}

/** Yapım aşamasındaki hatlar aktarma sayılmaz (ör. Buca metrosu). */
function yapimAsamasinda(etiket) {
  return Boolean(
    etiket.construction ||
    etiket['railway:construction'] ||
    etiket.proposed ||
    etiket['railway:proposed'] ||
    etiket.railway === 'construction' ||
    etiket.railway === 'proposed'
  );
}

function turunuBul(etiket) {
  if (etiket.railway === 'tram_stop') return 'Tramvay';
  if (etiket.station === 'subway') return 'Metro';
  if (etiket.amenity === 'ferry_terminal') return 'Vapur';

  const otobus = etiket.highway === 'bus_stop' ||
    etiket.amenity === 'bus_station' ||
    (etiket.public_transport === 'platform' && etiket.bus === 'yes');
  // Özel servis/minibüs durakları ESHOT sayılmaz.
  if (otobus) return eshotDuragiMi(etiket) ? 'ESHOT' : null;

  return null;
}

(async () => {
  const hedefYolu = path.join(__dirname, '..', 'backend', 'veri', 'duraklar.json');
  const veri = JSON.parse(fs.readFileSync(hedefYolu, 'utf8'));

  console.log('Aktarma noktaları indiriliyor (tek istek)...');
  const yanit = await calistir(sorguKur(veri.duraklar.map((d) => d.konum)));

  if (!yanit) {
    console.error('\nOverpass yanıt vermedi. Veri DEĞİŞTİRİLMEDİ.');
    process.exit(1);
  }

  const noktalar = [];
  for (const oge of yanit.elements) {
    const etiket = oge.tags || {};
    if (yapimAsamasinda(etiket)) continue;

    const tur = turunuBul(etiket);
    if (!tur) continue;

    const enlem = oge.lat ?? oge.center?.lat;
    const boylam = oge.lon ?? oge.center?.lon;
    if (enlem === undefined || boylam === undefined) continue;

    noktalar.push({ tur, ad: (etiket.name || '').trim(), enlem, boylam });
  }
  console.log(`${noktalar.length} aday nokta çözüldü.\n`);

  let noktaliDurak = 0;
  for (const durak of veri.duraklar) {
    const yakinlik = (tur) =>
      tur === 'ESHOT' ? OTOBUS_DURAK_YAKINLIK_M : RAYLI_YAKINLIK_M;

    // Her tür için EN YAKIN nokta yeter: kullanıcı "metroya nasıl giderim"
    // diye soruyor, aynı türden beş kapıyı listelemenin faydası yok.
    const enYakin = new Map();
    for (const nokta of noktalar) {
      const mesafe = metreUzaklik(durak.konum, nokta);
      if (mesafe > yakinlik(nokta.tur)) continue;

      const eski = enYakin.get(nokta.tur);
      if (!eski || mesafe < eski.mesafeM) {
        enYakin.set(nokta.tur, {
          tur: nokta.tur,
          ad: nokta.ad || durak.ad,
          konum: { enlem: nokta.enlem, boylam: nokta.boylam },
          mesafeM: Math.round(mesafe)
        });
      }
    }

    // Yalnızca aktarma listesinde YAZAN türler alınır: liste ayrı ölçütlerle
    // (ör. ESHOT hat ilişkisi) üretiliyor, ikisi çelişmesin.
    const beklenen = new Set(durak.aktarma || []);
    const secilen = [...enYakin.values()]
      .filter((n) => beklenen.has(n.tur))
      .sort((a, b) => a.tur.localeCompare(b.tur, 'tr'));

    if (secilen.length) {
      durak.aktarmaNoktalari = secilen;
      noktaliDurak++;
    } else {
      delete durak.aktarmaNoktalari;
    }

    if (beklenen.size) {
      console.log(`  ${durak.ad.padEnd(14)} ` +
        secilen.map((n) => `${n.tur}(${n.mesafeM} m)`).join(' · ') || '—');
    }
  }

  const parca = String(veri.surum).split('.').map(Number);
  veri.surum = `${parca[0]}.${parca[1] + 1}.0`;
  veri.guncellemeTarihi = new Date().toISOString().slice(0, 10);
  veri.kaynak = veri.kaynak || {};
  veri.kaynak.aktarmaNoktalari =
    'OpenStreetMap — her aktarma türünün durağa en yakın noktası '
    + `(raylı/vapur ${RAYLI_YAKINLIK_M} m, otobüs ${OTOBUS_DURAK_YAKINLIK_M} m)`;

  fs.writeFileSync(hedefYolu, JSON.stringify(veri, null, 2) + '\n');
  console.log(`\n${noktaliDurak} durakta aktarma noktası var.`);
  console.log(`Sürüm ${veri.surum} yazıldı. Şimdi: node araclar/veri-dagit.js`);
})();
