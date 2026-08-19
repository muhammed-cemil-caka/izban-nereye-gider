#!/usr/bin/env node
/**
 * backend/veri/duraklar.json dosyasını OpenStreetMap verisinden yeniden üretir.
 *
 *   node araclar/duraklari-osm-den-uret.js
 *
 * Kaynaklar:
 *   - Durak sırası ve koordinatlar: OSM rota ilişkileri (İZBAN operatörlü)
 *   - Aktarmalar: duraklara 400 m'den yakın tramvay/metro/vapur noktaları
 *   - İlçe: Nominatim ters coğrafi kodlama (saniyede 1 istek kuralına uyulur)
 *
 * Not: Süreler hâlâ TAHMİNİDİR — gerçek mesafeden hesaplanır, resmî tarife değildir.
 * OSM verisi ODbL lisanslıdır, yayında kaynak belirtmek gerekir.
 */
const fs = require('fs');
const path = require('path');

const ANA_HAT = 15423228;   // İZBAN: Aliağa → Tepeköy
const UZANTI = 16191185;    // İZBAN: Selçuk → Tepeköy (kuzeye doğru, ters çevrilir)

const OVERPASS = 'https://overpass-api.de/api/interpreter';
const NOMINATIM = 'https://nominatim.openstreetmap.org/reverse';
// HTTP başlıkları yalnızca ASCII taşıyabilir; burada Türkçe karakter kullanılamaz.
const KIMLIK = 'izban-nereye-gider/1.0 (data setup script)';

// Süre modeli: gerçek mesafeden tahmin. Hat kıvrımları için düz mesafe
// RAY_KATSAYISI ile çarpılır; her durakta bekleme süresi eklenir.
const ORTALAMA_HIZ_KMS = 65;
const RAY_KATSAYISI = 1.08;
const DURAK_BEKLEME_DK = 0.6;
const YAKINLIK_M = 600; // yaklaşık 7-8 dakikalık yürüyüş

const bekle = (ms) => new Promise((c) => setTimeout(c, ms));

// Overpass halka açık ve sık sık meşgul (504/429 döner). İstekler sıralı
// gönderilir ve geçici hatalarda artan beklemeyle yeniden denenir.
async function overpass(sorgu, deneme = 1) {
  const yanit = await fetch(OVERPASS, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'User-Agent': KIMLIK },
    body: 'data=' + encodeURIComponent(sorgu)
  });

  if (yanit.ok) return yanit.json();

  const gecici = [429, 502, 503, 504].includes(yanit.status);
  if (gecici && deneme < 5) {
    const saniye = deneme * 15;
    console.log(`  Overpass ${yanit.status} — ${saniye} sn sonra tekrar (${deneme}/4)`);
    await bekle(saniye * 1000);
    return overpass(sorgu, deneme + 1);
  }

  throw new Error(`Overpass ${yanit.status}`);
}

/** İki nokta arası kuş uçuşu mesafe (km). */
function haversineKm(a, b) {
  const R = 6371;
  const dLat = (b.enlem - a.enlem) * Math.PI / 180;
  const dLon = (b.boylam - a.boylam) * Math.PI / 180;
  const l1 = a.enlem * Math.PI / 180;
  const l2 = b.enlem * Math.PI / 180;
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(l1) * Math.cos(l2) * Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}

/** Bir rota ilişkisinin duraklarını üye sırasına göre döndürür. */
async function rotayiOku(iliskiKimligi) {
  const iliski = await overpass(`[out:json][timeout:120];rel(${iliskiKimligi});out body;`);
  await bekle(2000);
  const dugumler = await overpass(`[out:json][timeout:120];rel(${iliskiKimligi});node(r);out body;`);

  const koordinat = new Map();
  for (const d of dugumler.elements) {
    if (d.tags && d.tags.name) {
      koordinat.set(d.id, { ad: d.tags.name, enlem: d.lat, boylam: d.lon });
    }
  }

  return iliski.elements[0].members
    .filter((u) => u.type === 'node' && /stop/.test(u.role) && koordinat.has(u.ref))
    .map((u) => koordinat.get(u.ref));
}

/** Duraklara yakın tramvay/metro/vapur noktalarını bulur. */
async function aktarmalariBul(duraklar) {
  const veri = await overpass(`
    [out:json][timeout:120];
    (
      node["railway"="tram_stop"](37.90,26.90,38.85,27.60);
      node["station"="subway"](37.90,26.90,38.85,27.60);
      node["amenity"="ferry_terminal"](37.90,26.90,38.85,27.60);
      way["amenity"="ferry_terminal"](37.90,26.90,38.85,27.60);
    );
    out center tags;
  `);

  const noktalar = veri.elements.map((e) => {
    const etiket = e.tags || {};

    // Yapım aşamasındaki veya önerilmiş hatlar aktarma sayılmaz — OSM'de Buca
    // metrosunun istasyonları böyle işaretli ve bunlar henüz kullanılamıyor.
    const yapimAsamasinda = Boolean(
      etiket.construction ||
      etiket['railway:construction'] ||
      etiket.proposed ||
      etiket['railway:proposed'] ||
      etiket.railway === 'construction' ||
      etiket.railway === 'proposed'
    );
    if (yapimAsamasinda) return null;

    let tur = null;
    if (etiket.railway === 'tram_stop') tur = 'Tramvay';
    else if (etiket.station === 'subway') tur = 'Metro';
    else if (etiket.amenity === 'ferry_terminal') tur = 'Vapur';

    return {
      tur,
      enlem: e.lat ?? e.center?.lat,
      boylam: e.lon ?? e.center?.lon
    };
  }).filter((n) => n && n.tur && n.enlem);

  return duraklar.map((durak) => {
    const bulunan = new Set();
    for (const nokta of noktalar) {
      if (haversineKm(durak, nokta) * 1000 <= YAKINLIK_M) bulunan.add(nokta.tur);
    }
    return [...bulunan].sort();
  });
}

/** Nominatim ile ilçe adını çeker (saniyede 1 istek). */
async function ilceyiBul(durak) {
  const adres = `${NOMINATIM}?format=jsonv2&lat=${durak.enlem}&lon=${durak.boylam}&zoom=10`;
  const yanit = await fetch(adres, { headers: { 'User-Agent': KIMLIK } });
  if (!yanit.ok) return '—';
  const veri = await yanit.json();
  const a = veri.address || {};
  return a.town || a.city_district || a.county || a.province || a.city || '—';
}

(async () => {
  console.log('Rota ilişkileri okunuyor...');
  const anaHat = await rotayiOku(ANA_HAT);
  await bekle(1000);
  const uzanti = await rotayiOku(UZANTI);

  // Uzantı Selçuk → Tepeköy yönünde geliyor; kuzeyden güneye çevirip
  // ana hatta zaten bulunan Tepeköy'ü atıyoruz.
  const guneyUzanti = uzanti.slice().reverse()
    .filter((d) => !anaHat.some((a) => a.ad === d.ad));

  const duraklar = [...anaHat, ...guneyUzanti];
  console.log(`${duraklar.length} durak sıralandı: ${duraklar[0].ad} → ${duraklar.at(-1).ad}`);

  console.log('Aktarmalar hesaplanıyor...');
  const aktarmalar = await aktarmalariBul(duraklar);

  // Nominatim ücretsiz ve gönüllü bir servis; daha önce çözülmüş ilçeleri
  // yeniden sormamak için eldeki dosyadan okuyoruz.
  const hedefYolu = path.join(__dirname, '..', 'backend', 'veri', 'duraklar.json');
  const onceki = new Map();
  if (fs.existsSync(hedefYolu)) {
    for (const d of JSON.parse(fs.readFileSync(hedefYolu, 'utf8')).duraklar || []) {
      if (d.ilce && d.ilce !== '—') onceki.set(d.ad, d.ilce);
    }
  }

  console.log('İlçeler belirleniyor...');
  const ilceler = [];
  for (const [i, durak] of duraklar.entries()) {
    if (onceki.has(durak.ad)) {
      ilceler.push(onceki.get(durak.ad));
      continue;
    }
    ilceler.push(await ilceyiBul(durak));
    process.stdout.write(`\r  Nominatim: ${i + 1}/${duraklar.length}`);
    await bekle(1100);
  }
  console.log(`  ${duraklar.length - onceki.size} durak için sorgu yapıldı`);

  // Kümülatif mesafe ve tahmini süre
  let mesafe = 0;
  const kayitlar = duraklar.map((durak, i) => {
    if (i > 0) mesafe += haversineKm(duraklar[i - 1], durak) * RAY_KATSAYISI;
    const dakika = Math.round((mesafe / ORTALAMA_HIZ_KMS) * 60 + i * DURAK_BEKLEME_DK);

    return {
      kod: kodUret(durak.ad),
      ad: durak.ad,
      ilce: ilceler[i],
      dakika,
      mesafeKm: Number(mesafe.toFixed(2)),
      konum: {
        enlem: Number(durak.enlem.toFixed(6)),
        boylam: Number(durak.boylam.toFixed(6))
      },
      aktarma: aktarmalar[i]
    };
  });

  // Süreler kesin artan olmalı; aynı değere düşen olursa bir dakika ittir.
  for (let i = 1; i < kayitlar.length; i++) {
    if (kayitlar[i].dakika <= kayitlar[i - 1].dakika) {
      kayitlar[i].dakika = kayitlar[i - 1].dakika + 1;
    }
  }

  const cikti = {
    surum: '2.0.0',
    guncellemeTarihi: new Date().toISOString().slice(0, 10),
    uyari: 'Durak sırası, koordinatlar ve aktarmalar OpenStreetMap verisinden üretilmiştir. ' +
           'SÜRELER TAHMİNİDİR: gerçek mesafeden hesaplanır, resmî tarife değildir. ' +
           'Gerçek varış saatleri için izban.com.tr tarifesi kullanılmalıdır.',
    kaynak: {
      duraklar: `OpenStreetMap rota ilişkileri ${ANA_HAT} ve ${UZANTI}`,
      lisans: 'ODbL — © OpenStreetMap katkıcıları',
      ilce: 'Nominatim ters coğrafi kodlama',
      sureModeli: `${ORTALAMA_HIZ_KMS} km/sa ortalama hız, ${RAY_KATSAYISI}× ray katsayısı, ` +
                  `durak başına ${DURAK_BEKLEME_DK} dk bekleme`
    },
    hat: {
      ad: 'İZBAN Banliyö Hattı',
      kuzeyUcu: duraklar[0].ad,
      guneyUcu: duraklar.at(-1).ad
    },
    duraklar: kayitlar
  };

  fs.writeFileSync(hedefYolu, JSON.stringify(cikti, null, 2) + '\n', 'utf8');
  console.log(`\nYazıldı: ${hedefYolu}`);
  console.log(`${kayitlar.length} durak · ${mesafe.toFixed(1)} km · ~${kayitlar.at(-1).dakika} dk`);
})().catch((sorun) => { console.error('HATA:', sorun.message); process.exit(1); });

/** "Alsancak Gar" → "alsancak-gar", "Çiğli" → "cigli" */
function kodUret(ad) {
  // Büyük harfler de haritada olmalı: toLowerCase Türkçe harfleri ASCII'ye
  // çevirmez, sonraki temizlik adımı da onları tamamen silerdi.
  const harita = {
    ç: 'c', Ç: 'c', ğ: 'g', Ğ: 'g', ı: 'i', I: 'i', İ: 'i',
    ö: 'o', Ö: 'o', ş: 's', Ş: 's', ü: 'u', Ü: 'u'
  };
  return ad
    .replace(/[çÇğĞıIİöÖşŞüÜ]/g, (h) => harita[h])
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '');
}
