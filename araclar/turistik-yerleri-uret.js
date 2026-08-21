#!/usr/bin/env node
/**
 * backend/veri/turistik-yerler.json dosyasını Wikidata'dan üretir.
 *
 *   node araclar/turistik-yerleri-uret.js
 *
 * Kaynaklar (üçü de anahtarsız):
 *   - Wikidata SPARQL  : İzmir kutusundaki tarihi/turistik ögeler + koordinat + görsel
 *   - Wikipedia REST   : Türkçe özet metin (CC BY-SA)
 *   - Commons API      : görselin yazarı ve lisansı (toplu, 50'şerli)
 *
 * Yer–durak eşleşmesi YERELDE yapılır: kutu sorgusu tek istek, 41 ayrı sorgu
 * değil (Overpass'ta öğrenilen ders).
 *
 * Turistik veri duraklar.json'a KONMAZ: o dosya OSM'den her üretimde yeniden
 * yazılıyor, içine konan veri kaybolur.
 */
const fs = require('fs');
const path = require('path');

const SPARQL = 'https://query.wikidata.org/sparql';
const WIKIPEDIA = 'https://tr.wikipedia.org/api/rest_v1/page/summary/';
const COMMONS = 'https://commons.wikimedia.org/w/api.php';
const KIMLIK = 'izban-nereye-gider/1.0 (https://github.com/muhammed-cemil-caka/izban-nereye-gider)';

// Durağa bu kadar yakın yerler o duraktan gidilebilir sayılır. Aktarma
// yarıçapından (600 m) bilinçli olarak büyük: aktarma "hemen yanında olmalı",
// turistik yer "o duraktan gidilebilir" demek.
const YAKINLIK_M = 1500;

// İzmir ve çevresi — İZBAN hattının tamamını kapsar.
const KUTU = { guney: 37.90, bati: 26.90, kuzey: 38.85, dogu: 27.60 };

const bekle = (ms) => new Promise((c) => setTimeout(c, ms));

/** Wikidata sınıfları → bizim tür etiketlerimiz. */
const TURLER = {
  Q839954: 'antik-kent',      // arkeolojik alan
  Q33506: 'muze',
  Q32815: 'cami',
  Q16970: 'kilise',
  Q23413: 'kale',
  Q4989906: 'anit',
  Q22698: 'park',
  Q570116: 'gezi-noktasi',
  Q2065736: 'kultur-varligi',
  Q12518: 'kule',
  Q11908265: 'tarihi-yapi'
};

function metreUzaklik(a, b) {
  const R = 6371000;
  const p = Math.PI / 180;
  const dEnlem = (b.enlem - a.enlem) * p;
  const dBoylam = (b.boylam - a.boylam) * p;
  const h = Math.sin(dEnlem / 2) ** 2 +
    Math.cos(a.enlem * p) * Math.cos(b.enlem * p) * Math.sin(dBoylam / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}

async function getir(adres, secenekler = {}, deneme = 0) {
  try {
    const yanit = await fetch(adres, {
      ...secenekler,
      headers: { 'User-Agent': KIMLIK, ...(secenekler.headers || {}) },
      signal: AbortSignal.timeout(60000)
    });
    if (yanit.ok) return yanit;
    console.log(`    ${yanit.status}`);
  } catch (sorun) {
    console.log(`    ${sorun.message}`);
  }

  if (deneme < 4) {
    await bekle(3000 * (deneme + 1));
    return getir(adres, secenekler, deneme + 1);
  }
  return null;
}

/** Wikidata: kutu içindeki turistik ögeler. Tek istek. */
async function yerleriGetir() {
  const turSatiri = Object.keys(TURLER).map((k) => `wd:${k}`).join(' ');
  const sorgu = `
    SELECT ?yer ?yerLabel ?koord ?tur ?gorsel ?makale ?aciklama WHERE {
      SERVICE wikibase:box {
        ?yer wdt:P625 ?koord .
        bd:serviceParam wikibase:cornerSouthWest "Point(${KUTU.bati} ${KUTU.guney})"^^geo:wktLiteral .
        bd:serviceParam wikibase:cornerNorthEast "Point(${KUTU.dogu} ${KUTU.kuzey})"^^geo:wktLiteral .
      }
      ?yer wdt:P31/wdt:P279* ?tur .
      VALUES ?tur { ${turSatiri} }
      OPTIONAL { ?yer wdt:P18 ?gorsel . }
      OPTIONAL { ?yer schema:description ?aciklama . FILTER(LANG(?aciklama) = "tr") }
      OPTIONAL {
        ?makale schema:about ?yer ;
                schema:isPartOf <https://tr.wikipedia.org/> .
      }
      SERVICE wikibase:label { bd:serviceParam wikibase:language "tr,en". }
    }
  `;

  console.log('Wikidata sorgulanıyor...');
  const yanit = await getir(SPARQL + '?query=' + encodeURIComponent(sorgu), {
    headers: { Accept: 'application/sparql-results+json' }
  });
  if (!yanit) return null;

  const veri = await yanit.json();
  return veri.results.bindings;
}

/** "Point(27.34 37.94)" → {enlem, boylam} */
function koordinatCoz(metin) {
  const e = /Point\(([-\d.]+) ([-\d.]+)\)/.exec(metin || '');
  return e ? { boylam: Number(e[1]), enlem: Number(e[2]) } : null;
}

function kodUret(ad) {
  return ad.toLowerCase()
    .replace(/ı/g, 'i').replace(/ğ/g, 'g').replace(/ü/g, 'u')
    .replace(/ş/g, 's').replace(/ö/g, 'o').replace(/ç/g, 'c')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '')
    .slice(0, 48);
}

/** Wikipedia özeti (varsa). */
async function ozetGetir(makaleAdresi) {
  const baslik = decodeURIComponent(makaleAdresi.split('/wiki/')[1] || '');
  if (!baslik) return null;

  const yanit = await getir(WIKIPEDIA + encodeURIComponent(baslik));
  if (!yanit) return null;

  const veri = await yanit.json();
  return {
    ozet: (veri.extract || '').trim(),
    baslik: veri.title || baslik,
    adres: veri.content_urls?.desktop?.page || makaleAdresi,
    // Wikidata'da P18 yoksa makalenin kendi görseli kullanılır: 73 yerin
    // 5'inde P18 yoktu, çoğunun makalesinde fotoğraf var.
    gorsel: veri.thumbnail?.source
      ? {
          adres: veri.originalimage?.source || veri.thumbnail.source,
          kucukAdres: veri.thumbnail.source,
          yazar: 'Vikipedi katkıcıları',
          lisans: 'bkz. dosya sayfası',
          kaynakSayfa: veri.content_urls?.desktop?.page || makaleAdresi
        }
      : null
  };
}

/**
 * Son çare: Commons'ta ad araması.
 *
 * Wikidata'da P18, makalede de görsel yoksa dosya adıyla aranır. YANLIŞ
 * fotoğraf, fotoğrafsızdan kötüdür: bulunan dosyanın adı, yerin adındaki
 * anlamlı kelimelerden en az ikisini içermiyorsa kabul edilmez.
 */
async function commonsAra(ad) {
  const adres = COMMONS + '?action=query&format=json&origin=*'
    + '&generator=search&gsrnamespace=6&gsrlimit=5'
    + '&gsrsearch=' + encodeURIComponent(ad)
    + '&prop=imageinfo&iiprop=extmetadata|url&iiurlwidth=640';

  const yanit = await getir(adres);
  if (!yanit) return null;

  const veri = await yanit.json();
  const sayfalar = Object.values(veri.query?.pages || {});
  if (!sayfalar.length) return null;

  const anahtar = ad.toLowerCase()
    .replace(/[(),]/g, ' ')
    .split(/\s+/)
    .filter((k) => k.length > 3);
  if (anahtar.length < 2) return null;

  for (const sayfa of sayfalar) {
    const dosyaAdi = (sayfa.title || '').toLowerCase();
    const tutan = anahtar.filter((k) => dosyaAdi.includes(k)).length;
    if (tutan < 2) continue;

    const ii = sayfa.imageinfo?.[0];
    if (!ii) continue;
    const ek = ii.extmetadata || {};
    const temizle = (m) => (m || '').replace(/<[^>]*>/g, '').trim();

    return {
      adres: ii.url,
      kucukAdres: ii.thumburl || ii.url,
      yazar: temizle(ek.Artist?.value) || 'bilinmiyor',
      lisans: temizle(ek.LicenseShortName?.value) || 'bilinmiyor',
      kaynakSayfa: ii.descriptionurl
    };
  }

  return null;
}

/** Commons: görsellerin yazar ve lisansı — 50'şerli toplu istek. */
async function gorselBilgileri(dosyalar) {
  const bilgi = new Map();

  for (let i = 0; i < dosyalar.length; i += 50) {
    const parca = dosyalar.slice(i, i + 50);
    const adres = COMMONS + '?action=query&format=json&origin=*'
      + '&prop=imageinfo&iiprop=extmetadata|url&iiurlwidth=640'
      + '&titles=' + encodeURIComponent(parca.map((d) => 'File:' + d).join('|'));

    const yanit = await getir(adres);
    if (!yanit) continue;

    const veri = await yanit.json();
    for (const sayfa of Object.values(veri.query?.pages || {})) {
      const ii = sayfa.imageinfo?.[0];
      if (!ii) continue;
      const ek = ii.extmetadata || {};
      const temizle = (m) => (m || '').replace(/<[^>]*>/g, '').trim();

      bilgi.set(sayfa.title.replace(/^File:/, ''), {
        adres: ii.url,
        kucukAdres: ii.thumburl || ii.url,
        yazar: temizle(ek.Artist?.value) || 'bilinmiyor',
        lisans: temizle(ek.LicenseShortName?.value) || 'bilinmiyor',
        kaynakSayfa: ii.descriptionurl
      });
    }

    await bekle(1000);
  }

  return bilgi;
}

(async () => {
  const kok = path.join(__dirname, '..');
  const duraklar = JSON.parse(
    fs.readFileSync(path.join(kok, 'backend', 'veri', 'duraklar.json'), 'utf8')
  ).duraklar;

  const satirlar = await yerleriGetir();
  if (!satirlar) {
    console.error('Wikidata yanıt vermedi. Veri DEĞİŞTİRİLMEDİ.');
    process.exit(1);
  }
  console.log(`${satirlar.length} aday öge geldi.\n`);

  // Aynı öge birden çok türle geliyor; tekilleştir.
  const adaylar = new Map();
  for (const satir of satirlar) {
    const kimlik = satir.yer.value.split('/').pop();
    const konum = koordinatCoz(satir.koord?.value);
    const ad = satir.yerLabel?.value || '';
    if (!konum || !ad || /^Q\d+$/.test(ad)) continue;

    const tur = TURLER[satir.tur.value.split('/').pop()] || 'gezi-noktasi';
    const onceki = adaylar.get(kimlik);
    if (onceki) {
      // Daha belirgin tür kazanır (gezi-noktasi en genel).
      if (onceki.tur === 'gezi-noktasi') onceki.tur = tur;
      continue;
    }

    adaylar.set(kimlik, {
      kimlik,
      ad,
      tur,
      konum,
      gorselDosya: satir.gorsel ? decodeURIComponent(satir.gorsel.value.split('/').pop()) : null,
      makale: satir.makale?.value || null,
      aciklama: (satir.aciklama?.value || '').trim()
    });
  }

  // Duraklara eşle — 1500 m.
  const yerler = [];
  for (const aday of adaylar.values()) {
    const yakinDuraklar = duraklar
      .map((d) => ({ kod: d.kod, kusUcusuM: Math.round(metreUzaklik(aday.konum, d.konum)) }))
      .filter((d) => d.kusUcusuM <= YAKINLIK_M)
      .sort((a, b) => a.kusUcusuM - b.kusUcusuM);

    if (yakinDuraklar.length) yerler.push({ ...aday, duraklar: yakinDuraklar });
  }
  console.log(`${yerler.length} yer İZBAN duraklarına ${YAKINLIK_M} m'den yakın.\n`);

  // Görsel bilgileri (toplu)
  const dosyalar = [...new Set(yerler.map((y) => y.gorselDosya).filter(Boolean))];
  console.log(`${dosyalar.length} görselin lisans bilgisi alınıyor...`);
  const gorseller = await gorselBilgileri(dosyalar);

  // Wikipedia özetleri
  console.log('Wikipedia özetleri alınıyor...');
  const cikti = [];
  for (const yer of yerler) {
    let metin = null;
    if (yer.makale) {
      metin = await ozetGetir(yer.makale);
      await bekle(400);
    }

    // Görsel önceliği: Wikidata P18 (lisansı Commons'tan geliyor) → makale
    // görseli. Özet: Wikipedia metni → Wikidata açıklaması.
    let gorsel = (yer.gorselDosya ? gorseller.get(yer.gorselDosya) : null)
      || metin?.gorsel
      || null;

    // Hiçbiri yoksa Commons'ta adıyla aranır.
    if (!gorsel) {
      gorsel = await commonsAra(yer.ad);
      await bekle(400);
    }

    cikti.push({
      kod: kodUret(yer.ad),
      ad: yer.ad,
      tur: yer.tur,
      konum: { enlem: +yer.konum.enlem.toFixed(6), boylam: +yer.konum.boylam.toFixed(6) },
      ozet: metin?.ozet || yer.aciklama || '',
      gorsel,
      kaynaklar: {
        wikidata: yer.kimlik,
        wikipedia: metin?.adres || null
      },
      duraklar: yer.duraklar
    });

    process.stdout.write(`  ${cikti.length}/${yerler.length} ${yer.ad}\r`);
  }

  // Kart ölçütü: fotoğrafı olan her yer girer. Fotoğrafsızlar ancak
  // Vikipedi makalesi varsa (yani kayda değerse) kalır — yoksa liste
  // fotoğrafsız çeşme/türbe kayıtlarıyla doluyor ve kartlar boş görünüyor.
  const kullanilabilir = cikti.filter(
    (y) => y.gorsel || (y.ozet && y.kaynaklar.wikipedia)
  );

  const veri = {
    surum: '1.0.0',
    guncellemeTarihi: new Date().toISOString().slice(0, 10),
    kaynak: {
      yer: `Wikidata — İZBAN durağına ${YAKINLIK_M} m'den yakın tarihi/turistik ögeler`,
      metin: 'Wikipedia (tr) özet — CC BY-SA 4.0',
      gorsel: 'Wikimedia Commons — her görselin kendi lisansı',
      lisansUyarisi: 'Metin ve görsellerde kaynak gösterimi zorunludur'
    },
    yerler: kullanilabilir.sort((a, b) => a.ad.localeCompare(b.ad, 'tr'))
  };

  const hedef = path.join(kok, 'backend', 'veri', 'turistik-yerler.json');
  fs.writeFileSync(hedef, JSON.stringify(veri, null, 2) + '\n');

  console.log(`\n\n${kullanilabilir.length} yer yazıldı (${cikti.length - kullanilabilir.length} tanesi metinsiz/görselsiz elendi).`);
  const gorselli = kullanilabilir.filter((y) => y.gorsel).length;
  console.log(`${gorselli} tanesinde görsel var.`);
  console.log('backend/veri/turistik-yerler.json');
})();
