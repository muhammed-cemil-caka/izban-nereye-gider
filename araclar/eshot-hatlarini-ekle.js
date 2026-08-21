#!/usr/bin/env node
/**
 * Var olan backend/veri/duraklar.json dosyasına ESHOT otobüs aktarmalarını ekler.
 *
 *   node araclar/eshot-hatlarini-ekle.js
 *
 * Tam üretim (duraklari-osm-den-uret.js) durak sırasını, ilçeleri ve süreleri de
 * yeniden hesaplar; yalnızca otobüs verisini tazelemek için bu betik var.
 *
 * TEK Overpass isteği atılır: İzmir çevresindeki bütün otobüs hattı ilişkileri
 * ve üye düğümleri bir kerede indirilir, durak eşleştirmesi yerelde yapılır.
 * Durak başına ayrı sorgu (41 istek) Overpass'ı 429'a, sonunda da bağlantıyı
 * tamamen kesmeye götürüyordu.
 *
 * Eklenen alanlar:
 *   otobusHatlari: ["53", "102", ...]   durağa 400 m'den yakın ESHOT hatları
 *   aktarma:       [..., "ESHOT"]       hat varsa listeye eklenir
 *
 * Veri ODbL lisanslıdır; yayında "© OpenStreetMap katkıcıları" bulunmalıdır.
 */
const fs = require('fs');
const path = require('path');
const {
  sorguKur,
  hatlariCoz,
  duragaYakinHatlar,
  OTOBUS_YAKINLIK_M
} = require('./eshot-hatlari.js');

// Overpass sunucuları sırayla denenir. Ana sunucu (overpass-api.de) yoğun
// dönemlerde bağlantıyı tamamen kesiyor; diğerleri OSM wiki'de listelenen
// halka açık aynalar.
//
// DİKKAT: her ayna dünya verisini tutmuyor. overpass.osm.ch yalnızca İsviçre
// çıkartmasıyla çalışıyor ve Türkiye sorgularına 200 + BOŞ sonuç dönüyor —
// yani "hat yok" gibi görünüp veriyi siliyor. Bu yüzden her sunucu, veri
// çekilmeden önce SONDA sorgusuyla sınanıyor.
const SUNUCULAR = [
  'https://overpass-api.de/api/interpreter',
  'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
  'https://overpass.kumi.systems/api/interpreter',
  'https://overpass.private.coffee/api/interpreter'
];

// Halkapınar çevresinde otobüs hattı olduğu biliniyor; boş dönen sunucu
// Türkiye verisi tutmuyor demektir.
const SONDA_SORGUSU = `
  [out:json][timeout:60];
  node(around:400,38.43519,27.168837)["highway"="bus_stop"];
  rel(bn)["type"="route"]["route"="bus"];
  out tags;
`;

const KIMLIK = 'izban-nereye-gider/1.0 (data setup script)';
const DENEME_SAYISI = 3;

const bekle = (ms) => new Promise((c) => setTimeout(c, ms));

/** Tek sorguyu verilen sunucuda çalıştırır; sorun varsa null döner. */
async function sorgula(adres, sorgu, zamanAsimiMs = 300000) {
  try {
    const yanit = await fetch(adres, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'User-Agent': KIMLIK
      },
      body: 'data=' + encodeURIComponent(sorgu),
      signal: AbortSignal.timeout(zamanAsimiMs)
    });

    if (!yanit.ok) {
      console.log(`    ${yanit.status}`);
      return null;
    }

    const veri = await yanit.json();

    // Tuzak: Overpass zaman aşımında da 200 döndürüyor, hata gövdedeki
    // "remark" alanında yazıyor. Böyle yanıtı geçerli saymak veriyi
    // sessizce siliyordu.
    if (veri && typeof veri.remark === 'string' &&
        /error|timed out|out of memory/i.test(veri.remark)) {
      console.log(`    uyarı: ${veri.remark.slice(0, 70)}`);
      return null;
    }
    if (!veri || !Array.isArray(veri.elements) || !veri.elements.length) {
      console.log('    boş yanıt');
      return null;
    }

    return veri;
  } catch (sorun) {
    console.log(`    ${sorun.message}`);
    return null;
  }
}

/**
 * Çalışan ve Türkiye verisi tutan bir sunucu bulup büyük sorguyu orada
 * çalıştırır. Sunucular sırayla denenir; her tur arasında beklenir.
 */
async function overpass(sorgu) {
  for (let tur = 0; tur < DENEME_SAYISI; tur++) {
    if (tur > 0) {
      const saniye = 30 * tur;
      console.log(`  ${saniye} sn bekleniyor, sonra ${tur + 1}. tur...`);
      await bekle(saniye * 1000);
    }

    for (const adres of SUNUCULAR) {
      console.log(`  ${new URL(adres).host} sınanıyor...`);
      if (!(await sorgula(adres, SONDA_SORGUSU, 60000))) continue;

      console.log(`  ${new URL(adres).host} uygun, veri indiriliyor...`);
      const veri = await sorgula(adres, sorgu);
      if (veri) return veri;
    }
  }

  return null;
}

/** Sürüm numarasının ara basamağını artırır: 2.0.0 → 2.1.0 */
function surumuArtir(surum) {
  const parca = String(surum).split('.').map(Number);
  if (parca.length !== 3 || parca.some(Number.isNaN)) return '2.1.0';
  return `${parca[0]}.${parca[1] + 1}.0`;
}

(async () => {
  const hedefYolu = path.join(__dirname, '..', 'backend', 'veri', 'duraklar.json');
  const veri = JSON.parse(fs.readFileSync(hedefYolu, 'utf8'));

  console.log('İzmir çevresindeki otobüs hatları indiriliyor (tek istek)...');
  const yanit = await overpass(sorguKur(veri.duraklar.map((d) => d.konum)));

  if (!yanit) {
    console.error('\nOverpass yanıt vermedi. Veri DEĞİŞTİRİLMEDİ; '
      + 'servis rahatlayınca betiği yeniden çalıştırın.');
    process.exit(1);
  }

  const hatlar = hatlariCoz(yanit);
  console.log(`${hatlar.length} ESHOT hattı çözüldü.\n`);

  let hatliDurak = 0;
  let toplamHat = 0;

  for (const durak of veri.duraklar) {
    const yakinHatlar = duragaYakinHatlar(durak.konum, hatlar);
    const aktarma = new Set((durak.aktarma || []).filter((a) => a !== 'ESHOT'));

    if (yakinHatlar.length) {
      durak.otobusHatlari = yakinHatlar;
      aktarma.add('ESHOT');
      hatliDurak++;
      toplamHat += yakinHatlar.length;
    } else {
      delete durak.otobusHatlari;
    }

    if (aktarma.size) durak.aktarma = [...aktarma].sort((a, b) => a.localeCompare(b, 'tr'));
    else delete durak.aktarma;

    console.log(`  ${durak.ad.padEnd(14)} ${yakinHatlar.length ? yakinHatlar.join(', ') : '—'}`);
  }

  veri.surum = surumuArtir(veri.surum);
  veri.guncellemeTarihi = new Date().toISOString().slice(0, 10);
  veri.kaynak = veri.kaynak || {};
  veri.kaynak.otobus = `OpenStreetMap — durağa ${OTOBUS_YAKINLIK_M} m'den yakın `
    + 'ESHOT otobüs hatları (type=route, route=bus ilişkileri)';

  fs.writeFileSync(hedefYolu, JSON.stringify(veri, null, 2) + '\n');

  console.log(`\n${hatliDurak}/${veri.duraklar.length} durakta ESHOT hattı var `
    + `(toplam ${toplamHat} hat kaydı).`);
  console.log(`Sürüm ${veri.surum} yazıldı. Şimdi: node araclar/veri-dagit.js`);
})();
