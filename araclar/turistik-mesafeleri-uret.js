#!/usr/bin/env node
/**
 * Turistik yerlere EN YAKIN DURAĞI önceden hesaplar.
 *
 *   node araclar/turistik-mesafeleri-uret.js [--yaz]
 *
 * Neden: uygulama "Yürüyerek" ya da "Toplu taşıma" düğmesine basıldığında
 * ARDIŞIK İKİ OSRM çağrısı yapıyordu — önce en yakın durağı bulmak için mesafe
 * matrisi, sonra rotanın kendisi. İkisi de FOSSGIS'in gönüllü sunucusuna
 * gidiyor; gecikme toplanıyor ve iki isteğin herhangi biri düşünce kullanıcı
 * "rotası alınamadı" görüyordu.
 *
 * Oysa durak da yer de kıpırdamıyor: bu mesafeler SABİT. Burada bir kez
 * hesaplanıp veriye yazılıyor, uygulama yerel okumayla anında seçiyor. Geriye
 * yalnızca rotanın kendisi canlı kalıyor — çağrı sayısı yarıya iniyor.
 *
 * Yazılan alan (her yer için):
 *   "enYakin": {
 *     "yuruyus": { "kod": "selcuk", "mesafeM": 168, "sureSn": 124 },
 *     "araba":   { "kod": "selcuk", "mesafeM": 420, "sureSn": 70 }
 *   }
 *
 * --yaz verilmezse yalnızca özet basar, dosyaya dokunmaz.
 *
 * Veri ODbL lisanslıdır; rota servisi FOSSGIS'in OSRM örneği.
 */
const fs = require('fs');
const path = require('path');

const KOK = path.join(__dirname, '..');
const TURISTIK = path.join(KOK, 'backend', 'veri', 'turistik-yerler.json');
const DURAKLAR = path.join(KOK, 'backend', 'veri', 'duraklar.json');

const TABAN = {
  yuruyus: 'https://routing.openstreetmap.de/routed-foot/table/v1/foot',
  araba: 'https://routing.openstreetmap.de/routed-car/table/v1/driving'
};

// Uygulamanın kendi ön elemesiyle aynı: kuş uçuşu en yakın 6 durak aday olur,
// karar OSRM süresine göre verilir.
const ADAY_SAYISI = 6;

// Gönüllü sunucu. 400 ms ile denendi: ~190 isteklik seri sırasında sunucu
// bağlantı kabul etmez oldu (curl HTTP 000) ve araç yeniden deneme
// döngüsünde takıldı. 1.5 sn ile sorunsuz geçiyor — toplam ~5 dakika.
const BEKLEME_MS = 1500;

const bekle = (ms) => new Promise((c) => setTimeout(c, ms));

function metreUzaklik(a, b) {
  const R = 6371000;
  const p = Math.PI / 180;
  const dEnlem = (b.enlem - a.enlem) * p;
  const dBoylam = (b.boylam - a.boylam) * p;
  const h = Math.sin(dEnlem / 2) ** 2 +
    Math.cos(a.enlem * p) * Math.cos(b.enlem * p) * Math.sin(dBoylam / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}

async function getir(adres, deneme = 0) {
  try {
    const yanit = await fetch(adres, { signal: AbortSignal.timeout(30000) });
    if (yanit.ok) return await yanit.json();
    console.log(`    ${yanit.status}`);
  } catch (sorun) {
    console.log(`    ${sorun.message}`);
  }
  if (deneme < 3) {
    await bekle(2000 * (deneme + 1));
    return getir(adres, deneme + 1);
  }
  return null;
}

/** Bir yer için verilen kipte en yakın durak. */
async function enYakinDurak(yer, adaylar, kip) {
  const noktalar = [yer.konum, ...adaylar.map((a) => a.konum)]
    .map((n) => `${n.boylam},${n.enlem}`)
    .join(';');

  const veri = await getir(
    `${TABAN[kip]}/${noktalar}?sources=0&annotations=distance,duration`
  );
  if (!veri || veri.code !== 'Ok') return null;

  const mesafeler = veri.distances?.[0] || [];
  const sureler = veri.durations?.[0] || [];

  let enIyi = null;
  adaylar.forEach((durak, sira) => {
    const mesafeM = mesafeler[sira + 1];
    const sureSn = sureler[sira + 1];
    if (mesafeM == null || sureSn == null) return;
    if (!enIyi || sureSn < enIyi.sureSn) {
      enIyi = { kod: durak.kod, mesafeM: Math.round(mesafeM), sureSn: Math.round(sureSn) };
    }
  });
  return enIyi;
}

(async () => {
  const yaz = process.argv.includes('--yaz');
  // --bastan verilmezse zaten ölçülmüş yerler atlanır: araç yarıda kalırsa
  // kaldığı yerden devam edebilsin.
  const bastan = process.argv.includes('--bastan');
  const turistik = JSON.parse(fs.readFileSync(TURISTIK, 'utf8'));
  const duraklar = JSON.parse(fs.readFileSync(DURAKLAR, 'utf8')).duraklar
    .filter((d) => d.konum && (d.konum.enlem || d.konum.boylam));

  console.log(`\n${turistik.yerler.length} yer × 2 kip hesaplanıyor...\n`);

  let basarili = 0;
  const degisen = [];

  for (const yer of turistik.yerler) {
    if (!bastan && yer.enYakin && yer.enYakin.yuruyus && yer.enYakin.araba) {
      basarili++;
      continue;
    }

    const adaylar = duraklar
      .map((d) => ({ ...d, uzaklik: metreUzaklik(yer.konum, d.konum) }))
      .sort((a, b) => a.uzaklik - b.uzaklik)
      .slice(0, ADAY_SAYISI);

    const enYakin = {};
    for (const kip of ['yuruyus', 'araba']) {
      const sonuc = await enYakinDurak(yer, adaylar, kip);
      if (sonuc) enYakin[kip] = sonuc;
      await bekle(BEKLEME_MS);
    }

    if (enYakin.yuruyus || enYakin.araba) {
      basarili++;
      // Kuş uçuşu en yakın ile yürüyüş en yakın farklıysa not düş: bu, canlı
      // hesabın neden gerektiğini gösteren örnek.
      if (enYakin.yuruyus && enYakin.yuruyus.kod !== adaylar[0].kod) {
        degisen.push(`${yer.ad}: kuş uçuşu ${adaylar[0].kod} → yürüyüş ${enYakin.yuruyus.kod}`);
      }
      yer.enYakin = enYakin;
    } else {
      console.log(`  ! ${yer.ad}: hesaplanamadı`);
    }

    // Her yerden sonra yazılır: araç yarıda kalırsa emek çöpe gitmesin.
    if (yaz) fs.writeFileSync(TURISTIK, JSON.stringify(turistik, null, 2) + '\n');
    console.log(`  ${String(basarili).padStart(3)}/${turistik.yerler.length}  ${yer.ad}`);
  }

  console.log(`\n\n${basarili}/${turistik.yerler.length} yer için en yakın durak yazıldı.`);
  if (degisen.length) {
    console.log(`\nKuş uçuşundan FARKLI çıkanlar (${degisen.length}):`);
    degisen.forEach((s) => console.log('  ' + s));
  }

  if (!yaz) {
    console.log('\n--yaz verilmedi, dosyaya dokunulmadı.\n');
    return;
  }

  const parca = String(turistik.surum).split('.').map(Number);
  turistik.surum = `${parca[0]}.${parca[1] + 1}.0`;
  turistik.guncellemeTarihi = new Date().toISOString().slice(0, 10);
  turistik.kaynak = turistik.kaynak || {};
  turistik.kaynak.mesafe =
    'OSRM (FOSSGIS) — yere en yakın durak, yürüyüş ve araç ağında ölçüldü';

  fs.writeFileSync(TURISTIK, JSON.stringify(turistik, null, 2) + '\n');
  console.log(`\nSürüm ${turistik.surum} yazıldı: backend/veri/turistik-yerler.json`);
  console.log('Dağıtmak için: node araclar/veri-dagit.js\n');
})();
