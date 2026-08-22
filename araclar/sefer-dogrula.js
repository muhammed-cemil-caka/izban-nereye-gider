#!/usr/bin/env node
/**
 * Sefer motorunu CANLI servise karşı doğrular.
 *
 *   node araclar/sefer-dogrula.js            # örnek çiftler
 *   node araclar/sefer-dogrula.js --tam      # 41 durağın tamamı (uzun sürer)
 *
 * test-hesap.js motoru sentetik veriyle sınıyor: mantık doğru mu? Bu araç
 * başka bir soruyu soruyor: ÜRETTİĞİMİZ SAATLER GERÇEK Mİ? Her yolculuğun her
 * bacağı servisin kendi yanıtında birebir var mı, aktarmalar tutarlı zincir
 * kuruyor mu, aktarmasız çiftte listemiz servisin listesiyle aynı mı.
 *
 * Ağa çıktığı için test paketinin dışında: `npm test` onsuz da çalışmalı.
 */
const path = require('path');
const vm = require('vm');
const fs = require('fs');

const kok = path.join(__dirname, '..');
const { DURAKLAR } = require(path.join(kok, 'frontend', 'js', 'duraklar.js'));

// sefer.js klasik script: tarayıcıdaki gibi küresel kapsamda çalıştırılır.
const kapsam = {
  fetch, console, Date, Promise, Object, Math, Number, String, Array,
  Infinity, isFinite, setTimeout
};
vm.createContext(kapsam);
vm.runInContext(fs.readFileSync(path.join(kok, 'frontend', 'js', 'sefer.js'), 'utf8'), kapsam);

const GUN_DK = 24 * 60;
const dk = (s) => Number(s.slice(0, 2)) * 60 + Number(s.slice(3, 5));
const durak = (kod) => DURAKLAR.find((d) => d.kod === kod);

let sorunlu = 0;
let denenen = 0;

function sorun(baslik, ayrinti) {
  sorunlu++;
  console.log(`  ✗ ${baslik}`);
  if (ayrinti) console.log(`      ${ayrinti}`);
}

/** Ham servis yanıtı — bacakların gerçekliğini buradan denetliyoruz. */
const hamOnbellek = new Map();
async function hamSeferler(a, b) {
  const anahtar = `${a}-${b}`;
  if (!hamOnbellek.has(anahtar)) {
    const yanit = await fetch(
      `https://openapi.izmir.bel.tr/api/izban/sefersaatleri/${a}/${b}`,
      { signal: AbortSignal.timeout(30000) }
    );
    if (!yanit.ok) throw new Error(`servis ${yanit.status}`);
    const liste = await yanit.json();
    hamOnbellek.set(anahtar, (Array.isArray(liste) ? liste : []).map((s) => ({
      kalkis: s.HareketSaati.slice(0, 5),
      varis: s.VarisSaati.slice(0, 5)
    })));
  }
  return hamOnbellek.get(anahtar);
}

/** Bir bacak servisin listesinde birebir var mı? */
function bacakVarMi(liste, kalkis, varis) {
  return liste.some((s) => s.kalkis === kalkis && s.varis === varis);
}

/** Tek bir durak çiftini denetler. */
async function ciftiDenetle(binisKod, inisKod) {
  denenen++;
  const binis = durak(binisKod);
  const inis = durak(inisKod);
  const etiket = `${binis.ad} → ${inis.ad}`;

  const yolculuklar = await kapsam.yolculukSeferleriAl(DURAKLAR, binisKod, inisKod);

  if (!yolculuklar.length) {
    sorun(`${etiket}: hiç yolculuk üretilmedi`);
    return;
  }

  const direkt = await hamSeferler(binis.izbanId, inis.izbanId);

  // 1) Aktarmasız çiftte listemiz servisin listesiyle birebir aynı olmalı.
  if (direkt.length) {
    const bizim = yolculuklar
      .filter((y) => !y.aktarmalar.length)
      .map((y) => `${y.kalkis}→${y.varis}`)
      .sort();
    const servis = direkt.map((s) => `${s.kalkis}→${s.varis}`).sort();

    const eksik = servis.filter((s) => !bizim.includes(s));
    const fazla = bizim.filter((s) => !servis.includes(s));
    if (fazla.length) {
      sorun(`${etiket}: serviste olmayan aktarmasız sefer`, fazla.slice(0, 3).join(', '));
    }
    // Eksik olması normal: baskın olmayan seferler eleniyor. Ama aktarmasız
    // bir sefer, kendisinden daha geç kalkıp daha erken varan biri yoksa
    // elenmemeli.
    for (const metin of eksik) {
      const [kalkis, varis] = metin.split('→');
      const k = dk(kalkis);
      const v = k + ((dk(varis) - k) % GUN_DK + GUN_DK) % GUN_DK;
      const baskin = yolculuklar.some((y) => y.kalkisDk >= k && y.varisDk <= v &&
        !(y.kalkisDk === k && y.varisDk === v));
      if (!baskin) {
        sorun(`${etiket}: ${metin} baskınlanmadan elenmiş`);
        break;
      }
    }
  }

  // 2) Her yolculuğun her bacağı serviste gerçekten var mı, zincir tutuyor mu?
  for (const y of yolculuklar) {
    const zincir = kapsam.seferZinciri(DURAKLAR, binisKod, inisKod);
    const ugranan = [zincir[0], ...y.aktarmalar.map(
      (a) => zincir.find((d) => d.ad === a.durak)
    ), zincir[zincir.length - 1]];

    let kalkis = y.kalkis;
    for (let i = 0; i < ugranan.length - 1; i++) {
      const varis = i < y.aktarmalar.length ? y.aktarmalar[i].inis : y.varis;
      const liste = await hamSeferler(ugranan[i].izbanId, ugranan[i + 1].izbanId);

      if (!bacakVarMi(liste, kalkis, varis)) {
        sorun(`${etiket}: uydurma bacak`,
          `${ugranan[i].ad} ${kalkis} → ${ugranan[i + 1].ad} ${varis}`);
        break;
      }

      if (i < y.aktarmalar.length) {
        const a = y.aktarmalar[i];
        const bekleme = ((dk(a.binis) - dk(a.inis)) % GUN_DK + GUN_DK) % GUN_DK;
        if (bekleme !== a.beklemeDk) {
          sorun(`${etiket}: bekleme süresi tutmuyor`,
            `${a.durak} ${a.inis}→${a.binis} yazılan ${a.beklemeDk} dk, gerçek ${bekleme} dk`);
        }
        if (bekleme < kapsam.EN_AZ_AKTARMA_DK) {
          sorun(`${etiket}: yetişilemeyecek aktarma`, `${a.durak} ${bekleme} dk`);
        }
        kalkis = a.binis;
      }
    }
  }

  // 3) Kalkışlar artan sırada mı?
  for (let i = 1; i < yolculuklar.length; i++) {
    if (yolculuklar[i].kalkisDk < yolculuklar[i - 1].kalkisDk) {
      sorun(`${etiket}: kalkışlar sıralı değil`);
      break;
    }
  }

  // 4) Gün sonuna kadar gösteriliyor mu? Sabah 06:00'da bakan kullanıcı
  //    günün son seferini de görmeli.
  const sonKalkis = yolculuklar[yolculuklar.length - 1].kalkisDk;
  const sabah = kapsam.siradakiSeferler(yolculuklar, 6 * 60);
  const sonGosterilen = sabah.length ? dk(sabah[sabah.length - 1].kalkis) : -1;
  if (sonGosterilen !== sonKalkis) {
    sorun(`${etiket}: gün sonuna kadar gösterilmiyor`,
      `son sefer ${yolculuklar[yolculuklar.length - 1].kalkis}, listenin sonu ` +
      (sabah.length ? sabah[sabah.length - 1].kalkis : '—'));
  }

  // 5) Geçmiş sefer listelenmemeli.
  const gece = kapsam.siradakiSeferler(yolculuklar, 22 * 60);
  const gecmis = gece.filter((s) => !s.ertesiGun && dk(s.kalkis) < 22 * 60);
  if (gecmis.length) {
    sorun(`${etiket}: geçmiş sefer listede`, gecmis.map((s) => s.kalkis).join(', '));
  }

  console.log(`  ✓ ${etiket.padEnd(34)} ${String(yolculuklar.length).padStart(3)} yolculuk` +
    `  ${yolculuklar[0].kalkis}–${yolculuklar[yolculuklar.length - 1].kalkis}` +
    `  en çok ${Math.max(...yolculuklar.map((y) => y.aktarmalar.length))} aktarma`);
}

// Örnek küme: aktarmasız, tek aktarmalı, çift aktarmalı ve iki uç.
const ORNEK = [
  ['halkapinar', 'havalimani'], ['aliaga', 'bicerova'], ['saglik', 'belevi'],
  ['tepekoy', 'selcuk'], ['halkapinar', 'selcuk'], ['inkilap', 'selcuk'],
  ['selcuk', 'halkapinar'], ['aliaga', 'selcuk'], ['selcuk', 'aliaga'],
  ['aliaga', 'torbali'], ['belevi', 'menemen'], ['alsancak-gar', 'tepekoy']
];

(async () => {
  const tam = process.argv.includes('--tam');
  const ciftler = tam
    ? DURAKLAR.flatMap((a) => DURAKLAR.filter((b) => b.kod !== a.kod).map((b) => [a.kod, b.kod]))
    : ORNEK;

  console.log(`\n${ciftler.length} durak çifti denetleniyor...\n`);

  for (const [a, b] of ciftler) {
    try {
      await ciftiDenetle(a, b);
    } catch (hata) {
      sorun(`${a} → ${b}: ${hata.message}`);
    }
  }

  console.log(`\n${denenen} çift denendi, ${sorunlu} sorun bulundu.\n`);
  process.exit(sorunlu ? 1 : 0);
})();
