#!/usr/bin/env node
/**
 * duraklar.json'daki aktarma bilgisini OpenStreetMap'e karşı DOĞRULAR.
 *
 *   node araclar/aktarmalari-dogrula.js
 *
 * Dosyayı değiştirmez; yalnızca karşılaştırır. Üç şeyi arar:
 *   - EKSİK: OSM'de aktarma var, dosyada yok
 *   - FAZLA: dosyada aktarma var, OSM'de yok
 *   - hat numaralarının hâlâ tutup tutmadığı
 *
 * Veri üretimiyle AYNI ölçütleri kullanır (aynı modüller), ama sorguyu
 * bağımsız kurar: üretim betiğindeki bir sorgu hatası burada da tekrarlanmasın
 * diye tür tür ayrı ayrı sorulur.
 *
 * Çıkış kodu: eksik/fazla varsa 1, temizse 0.
 */
const fs = require('fs');
const path = require('path');
const { calistir } = require('./overpass.js');
const {
  metreUzaklik,
  eshotDuragiMi,
  eshotSayilirMi,
  hatNumarasi,
  hatSirala,
  OTOBUS_YAKINLIK_M,
  OTOBUS_DURAK_YAKINLIK_M
} = require('./eshot-hatlari.js');

const RAYLI_YAKINLIK_M = 600;

function yapimAsamasinda(etiket) {
  return Boolean(
    etiket.construction || etiket['railway:construction'] ||
    etiket.proposed || etiket['railway:proposed'] ||
    etiket.railway === 'construction' || etiket.railway === 'proposed'
  );
}

(async () => {
  const hedefYolu = path.join(__dirname, '..', 'backend', 'veri', 'duraklar.json');
  const veri = JSON.parse(fs.readFileSync(hedefYolu, 'utf8'));
  const duraklar = veri.duraklar;

  const cevre = (tanim, yaricap) => duraklar
    .map((d) => tanim.replace('AROUND', `around:${yaricap},${d.konum.enlem},${d.konum.boylam}`))
    .join('\n      ');

  console.log('OSM verisi indiriliyor (raylı + vapur + otobüs)...');
  const raylı = await calistir(`
    [out:json][timeout:300];
    (
      ${cevre('node(AROUND)["railway"="tram_stop"];', RAYLI_YAKINLIK_M)}
      ${cevre('node(AROUND)["station"="subway"];', RAYLI_YAKINLIK_M)}
      ${cevre('node(AROUND)["amenity"="ferry_terminal"];', RAYLI_YAKINLIK_M)}
      ${cevre('way(AROUND)["amenity"="ferry_terminal"];', RAYLI_YAKINLIK_M)}
    );
    out center tags;
  `);
  if (!raylı) { console.error('Overpass yanıt vermedi.'); process.exit(2); }

  console.log('otobüs durakları ve hatları indiriliyor...');
  const otobus = await calistir(`
    [out:json][timeout:300];
    (
      ${cevre('node(AROUND)["highway"="bus_stop"];', OTOBUS_DURAK_YAKINLIK_M)}
      ${cevre('node(AROUND)["public_transport"="platform"]["bus"="yes"];', OTOBUS_DURAK_YAKINLIK_M)}
      ${cevre('node(AROUND)["amenity"="bus_station"];', OTOBUS_DURAK_YAKINLIK_M)}
    )->.duraklar;
    rel(bn.duraklar)["type"="route"]["route"="bus"]->.hatlar;
    .hatlar out body;
    .duraklar out body qt;
  `);
  if (!otobus) { console.error('Overpass yanıt vermedi.'); process.exit(2); }

  // --- Raylı/vapur noktaları ---
  const raylıNoktalar = [];
  for (const oge of raylı.elements) {
    const etiket = oge.tags || {};
    if (yapimAsamasinda(etiket)) continue;
    const enlem = oge.lat ?? oge.center?.lat;
    const boylam = oge.lon ?? oge.center?.lon;
    if (enlem === undefined) continue;

    let tur = null;
    if (etiket.railway === 'tram_stop') tur = 'Tramvay';
    else if (etiket.station === 'subway') tur = 'Metro';
    else if (etiket.amenity === 'ferry_terminal') tur = 'Vapur';
    if (tur) raylıNoktalar.push({ tur, ad: etiket.name || '', enlem, boylam });
  }

  // --- Otobüs durakları ve hatları ---
  const dugumler = new Map();
  const otobusDuraklari = [];
  for (const oge of otobus.elements) {
    if (oge.type !== 'node' || oge.lat === undefined) continue;
    const etiket = oge.tags || {};
    const otobusDuragi = etiket.highway === 'bus_stop' ||
      etiket.amenity === 'bus_station' ||
      (etiket.public_transport === 'platform' && etiket.bus === 'yes');
    if (!otobusDuragi) continue;

    const nokta = { ad: etiket.name || '', eshot: eshotDuragiMi(etiket), enlem: oge.lat, boylam: oge.lon };
    dugumler.set(oge.id, nokta);
    otobusDuraklari.push(nokta);
  }

  const hatlar = [];
  for (const oge of otobus.elements) {
    if (oge.type !== 'relation') continue;
    const etiket = oge.tags || {};
    if (!eshotSayilirMi(etiket)) continue;
    const numara = hatNumarasi(etiket);
    if (!numara) continue;
    const noktalar = (oge.members || [])
      .filter((u) => u.type === 'node')
      .map((u) => dugumler.get(u.ref))
      .filter(Boolean);
    if (noktalar.length) hatlar.push({ numara, noktalar });
  }

  console.log(`${raylıNoktalar.length} raylı/vapur noktası · ${otobusDuraklari.length} otobüs durağı · ${hatlar.length} hat\n`);

  let eksik = 0;
  let fazla = 0;
  let hatFarki = 0;

  console.log('durak            dosyada                     OSM\'de                      sonuç');
  console.log('-'.repeat(94));

  for (const durak of duraklar) {
    const beklenen = new Set();

    for (const n of raylıNoktalar) {
      if (metreUzaklik(durak.konum, n) <= RAYLI_YAKINLIK_M) beklenen.add(n.tur);
    }
    for (const n of otobusDuraklari) {
      if (n.eshot && metreUzaklik(durak.konum, n) <= OTOBUS_DURAK_YAKINLIK_M) beklenen.add('ESHOT');
    }

    const dosyada = new Set(durak.aktarma || []);
    const eksikler = [...beklenen].filter((t) => !dosyada.has(t));
    const fazlalar = [...dosyada].filter((t) => !beklenen.has(t));

    // Hat numaraları
    const osmHatlar = new Set();
    for (const hat of hatlar) {
      for (const n of hat.noktalar) {
        if (metreUzaklik(durak.konum, n) <= OTOBUS_YAKINLIK_M) { osmHatlar.add(hat.numara); break; }
      }
    }
    const dosyaHatlar = new Set(durak.otobusHatlari || []);
    const hatEksik = [...osmHatlar].filter((h) => !dosyaHatlar.has(h));
    const hatFazla = [...dosyaHatlar].filter((h) => !osmHatlar.has(h));

    const sorun = [];
    if (eksikler.length) { sorun.push('EKSİK: ' + eksikler.join(',')); eksik++; }
    if (fazlalar.length) { sorun.push('FAZLA: ' + fazlalar.join(',')); fazla++; }
    if (hatEksik.length || hatFazla.length) {
      sorun.push(`hat ±(${hatEksik.length}/${hatFazla.length})`);
      hatFarki++;
    }

    console.log(
      durak.ad.padEnd(15),
      ([...dosyada].join(',') || '—').padEnd(27),
      ([...beklenen].join(',') || '—').padEnd(27),
      sorun.length ? sorun.join(' · ') : 'tamam'
    );
  }

  console.log(`\n${eksik} durakta eksik aktarma, ${fazla} durakta fazla aktarma, `
    + `${hatFarki} durakta hat numarası farkı.`);
  process.exit(eksik || fazla ? 1 : 0);
})();
