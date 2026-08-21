#!/usr/bin/env node
/**
 * Duraklar arası mesafeleri GERÇEK RAY GEOMETRİSİ üzerinden ölçer.
 *
 *   node araclar/mesafeleri-guncelle.js [--yaz]
 *
 * Önceki değerler kuş uçuşu mesafenin 1.08 ile çarpımıydı (RAY_KATSAYISI):
 * hattın kıvrımlarını kaba bir katsayıyla tahmin ediyordu. Burada İZBAN rota
 * ilişkilerinin yol geometrisi indirilip tek bir çizgiye diziliyor, her durak
 * bu çizgiye izdüşürülüyor ve iki durak arasındaki mesafe çizgi ÜZERİNDEN
 * ölçülüyor.
 *
 * --yaz verilmezse yalnızca karşılaştırma tablosu basar, dosyaya dokunmaz.
 *
 * Süreler aynı modelle (ortalama hız + durak beklemesi) yeni mesafelerden
 * yeniden hesaplanır. Süre hâlâ TAHMİNDİR, resmî tarife değildir.
 *
 * Veri ODbL lisanslıdır.
 */
const fs = require('fs');
const path = require('path');
const { calistir } = require('./overpass.js');

const ANA_HAT = 15423228;   // İZBAN: Aliağa → Tepeköy
const UZANTI = 16191185;    // İZBAN: Selçuk → Tepeköy (ters çevrilir)

// Süre modeli — duraklari-osm-den-uret.js ile aynı.
const ORTALAMA_HIZ_KMS = 65;
const DURAK_BEKLEME_DK = 0.6;

/** İki nokta arası kuş uçuşu mesafe (metre). */
function metreUzaklik(a, b) {
  const R = 6371000;
  const p = Math.PI / 180;
  const dEnlem = (b.enlem - a.enlem) * p;
  const dBoylam = (b.boylam - a.boylam) * p;
  const h = Math.sin(dEnlem / 2) ** 2 +
    Math.cos(a.enlem * p) * Math.cos(b.enlem * p) * Math.sin(dBoylam / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}

/**
 * Rota ilişkisinin yollarını ÜYE SIRASINA göre uç uca ekleyip tek çizgi yapar.
 *
 * Yolları Overpass'ın döndürdüğü sırayla (id sırası) eklemek çizgiyi şehrin
 * içinde ileri geri zıplatıyor ve uzunluğu 2000 km'ye çıkarıyordu; sıra
 * ilişkinin üye listesinden gelmeli.
 */
function cizgiyeDiz(iliski, geometriler) {
  const cizgi = [];

  for (const uye of iliski.members || []) {
    if (uye.type !== 'way') continue;

    const geometri = geometriler.get(uye.ref);
    if (!geometri || geometri.length < 2) continue;

    if (!cizgi.length) {
      cizgi.push(...geometri);
      continue;
    }

    // Yol ters yönde tanımlanmış olabilir: hangi ucu öncekine yakınsa
    // oradan bağlanır.
    const son = cizgi.at(-1);
    const bastan = metreUzaklik(son, geometri[0]);
    const sondan = metreUzaklik(son, geometri.at(-1));
    const parca = sondan < bastan ? [...geometri].reverse() : geometri;

    // Aynı düğüm iki kez sayılmasın.
    cizgi.push(...parca.slice(1));
  }

  return cizgi;
}

/** Çizgi üzerindeki kümülatif mesafeler (metre). */
function kilometreTasi(cizgi) {
  const toplam = [0];
  for (let i = 1; i < cizgi.length; i++) {
    toplam.push(toplam[i - 1] + metreUzaklik(cizgi[i - 1], cizgi[i]));
  }
  return toplam;
}

/** Durağın çizgiye en yakın noktasındaki kilometre değeri (metre). */
function zincirleme(durak, cizgi, tas) {
  let enIyi = { mesafe: Infinity, km: 0 };
  for (let i = 0; i < cizgi.length; i++) {
    const mesafe = metreUzaklik(durak, cizgi[i]);
    if (mesafe < enIyi.mesafe) enIyi = { mesafe, km: tas[i] };
  }
  return enIyi;
}

(async () => {
  const yaz = process.argv.includes('--yaz');
  const hedefYolu = path.join(__dirname, '..', 'backend', 'veri', 'duraklar.json');
  const veri = JSON.parse(fs.readFileSync(hedefYolu, 'utf8'));

  console.log('Ray geometrisi indiriliyor...');
  const yanit = await calistir(`
    [out:json][timeout:300];
    rel(${ANA_HAT})->.ana;
    rel(${UZANTI})->.uzanti;
    (.ana; .uzanti;)->.hatlar;
    .hatlar out body;
    way(r.hatlar);
    out geom;
  `);

  if (!yanit) {
    console.error('Overpass yanıt vermedi. Veri DEĞİŞTİRİLMEDİ.');
    process.exit(1);
  }

  const geometriler = new Map();
  for (const oge of yanit.elements) {
    if (oge.type === 'way' && Array.isArray(oge.geometry)) {
      geometriler.set(oge.id, oge.geometry.map((n) => ({ enlem: n.lat, boylam: n.lon })));
    }
  }

  const iliskiler = new Map(
    yanit.elements.filter((e) => e.type === 'relation').map((e) => [e.id, e])
  );

  const anaCizgi = cizgiyeDiz(iliskiler.get(ANA_HAT), geometriler);
  // Uzantı Selçuk → Tepeköy yönünde tanımlı; kuzeyden güneye çevriliyor.
  const uzantiCizgi = cizgiyeDiz(iliskiler.get(UZANTI), geometriler).reverse();

  // İki hattı Tepeköy'de birleştir: uzantının ana hatta değen ucu atlanır.
  const cizgi = [...anaCizgi];
  if (uzantiCizgi.length) {
    const son = cizgi.at(-1);
    const bastan = metreUzaklik(son, uzantiCizgi[0]);
    const sondan = metreUzaklik(son, uzantiCizgi.at(-1));
    const parca = sondan < bastan ? [...uzantiCizgi].reverse() : uzantiCizgi;
    cizgi.push(...parca.slice(1));
  }

  const tas = kilometreTasi(cizgi);
  console.log(`ana hat ${anaCizgi.length} nokta · uzantı ${uzantiCizgi.length} nokta`);
  console.log(`toplam ${cizgi.length} nokta · çizgi uzunluğu ${(tas.at(-1) / 1000).toFixed(1)} km\n`);

  // Her durağın çizgi üzerindeki yeri.
  const yerler = veri.duraklar.map((d) => {
    const yer = zincirleme(d.konum, cizgi, tas);
    return { durak: d, km: yer.km / 1000, sapmaM: yer.mesafe };
  });

  // Çizgi Aliağa'dan mı başlıyor? Değilse ters çevir.
  if (yerler[0].km > yerler.at(-1).km) {
    const uzunluk = tas.at(-1) / 1000;
    for (const y of yerler) y.km = uzunluk - y.km;
  }

  const baslangic = yerler[0].km;
  console.log('durak            eski km   yeni km    fark |  eski dk  yeni dk | çizgiye uzaklık');
  console.log('-'.repeat(88));

  let enBuyukFark = 0;
  let sapanDurak = 0;

  for (let i = 0; i < yerler.length; i++) {
    const y = yerler[i];
    const yeniKm = Math.round((y.km - baslangic) * 100) / 100;
    const eskiKm = y.durak.mesafeKm;

    const yeniDk = Math.round(
      (yeniKm / ORTALAMA_HIZ_KMS) * 60 + i * DURAK_BEKLEME_DK
    );

    const fark = yeniKm - eskiKm;
    if (Math.abs(fark) > Math.abs(enBuyukFark)) enBuyukFark = fark;
    if (y.sapmaM > 120) sapanDurak++;

    console.log(
      `${y.durak.ad.padEnd(14)} ${String(eskiKm).padStart(8)} ${String(yeniKm).padStart(9)} ` +
      `${(fark >= 0 ? '+' : '') + fark.toFixed(2).padStart(6)} | ` +
      `${String(y.durak.dakika).padStart(7)} ${String(yeniDk).padStart(8)} | ` +
      `${Math.round(y.sapmaM).toString().padStart(6)} m`
    );

    if (yaz) {
      y.durak.mesafeKm = yeniKm;
      y.durak.dakika = yeniDk;
    }
  }

  console.log(`\nEn büyük fark: ${enBuyukFark.toFixed(2)} km`);
  console.log(`Çizgiye 120 m'den uzak durak: ${sapanDurak}`);

  if (!yaz) {
    console.log('\n(Yalnızca karşılaştırma. Yazmak için: --yaz)');
    return;
  }

  const parca = String(veri.surum).split('.').map(Number);
  veri.surum = `${parca[0]}.${parca[1] + 1}.0`;
  veri.guncellemeTarihi = new Date().toISOString().slice(0, 10);
  veri.kaynak.sureModeli =
    `${ORTALAMA_HIZ_KMS} km/sa ortalama hız, durak başına ${DURAK_BEKLEME_DK} dk bekleme; `
    + 'mesafeler gerçek ray geometrisi üzerinden ölçülür';

  fs.writeFileSync(hedefYolu, JSON.stringify(veri, null, 2) + '\n');
  console.log(`\nSürüm ${veri.surum} yazıldı. Şimdi: node araclar/veri-dagit.js`);
})();
