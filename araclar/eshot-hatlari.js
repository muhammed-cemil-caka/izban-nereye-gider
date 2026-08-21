/**
 * İZBAN duraklarına yakın ESHOT otobüs hatlarını OpenStreetMap'ten bulur.
 *
 * TEK Overpass isteği atılır: İzmir çevresindeki bütün otobüs hattı ilişkileri
 * ve bu ilişkilerin üye düğümleri bir kerede indirilir, durak eşleştirmesi
 * yerelde yapılır. Önce durak başına ayrı sorgu atılıyordu (41 istek); Overpass
 * gönüllü bir servis ve bu tempoyu 429 ile karşılıyor, sonunda bağlantıyı
 * tamamen kesiyordu.
 *
 * Yakınlık neden 400 m: otobüs durakları şehirde çok sık. Raylı aktarmalar için
 * kullanılan 600 m ile neredeyse her İZBAN durağı düzinelerce hat topluyor ve
 * bilgi anlamını yitiriyor. 400 m ~5 dakikalık yürüyüş.
 *
 * Veri ODbL lisanslıdır.
 */
const OTOBUS_YAKINLIK_M = 400;

// İzmir ve çevresi (İZBAN hattının tamamını kapsar).
const SINIR = { guney: 37.90, bati: 26.90, kuzey: 38.85, dogu: 27.60 };

/**
 * Bir otobüs rotası ESHOT sayılır mı?
 *
 * OSM'de İzmir hatlarının bir kısmında operator "ESHOT"/"Eshot" yazıyor, bir
 * kısmında ise operator etiketi hiç yok (ör. "535 Bayraklı Şehir Hastanesi -
 * Egekent Aktarma Merkezi"). Etiketsizleri elemek gerçek hatları kaybettiriyor;
 * İzmir'de belediye otobüslerini ESHOT işlettiği için etiketsizler ESHOT
 * sayılıyor. Açıkça BAŞKA bir işletmeci yazanlar (özel halk otobüsü
 * kooperatifleri gibi) elenir.
 */
function eshotSayilirMi(etiket) {
  const isletmeci = [etiket.operator, etiket.network, etiket.brand]
    .filter(Boolean)
    .join(' ')
    .trim();

  if (!isletmeci) return true;           // etiketsiz: İzmir'de ESHOT
  return /eshot/i.test(isletmeci);       // adı geçiyorsa ESHOT
}

/** Hat numarası: ref alanı, yoksa adın başındaki numara ("912 Egekent - ..."). */
function hatNumarasi(etiket) {
  const ref = (etiket.ref || '').trim();
  if (ref) return ref;
  const eslesme = (etiket.name || '').trim().match(/^([0-9]+[A-Za-z]?)\b/);
  return eslesme ? eslesme[1] : null;
}

/** "53" < "154" < "C10": sayılar sayıca, gerisi alfabetik sıralanır. */
function hatSirala(a, b) {
  const sa = Number(a);
  const sb = Number(b);
  if (Number.isFinite(sa) && Number.isFinite(sb)) return sa - sb;
  if (Number.isFinite(sa)) return -1;
  if (Number.isFinite(sb)) return 1;
  return a.localeCompare(b, 'tr');
}

/** Tek sorgu: hat ilişkileri + üye düğümleri. */
function sorguKur(sinir = SINIR) {
  const kutu = `${sinir.guney},${sinir.bati},${sinir.kuzey},${sinir.dogu}`;
  return `
    [out:json][timeout:600];
    rel["type"="route"]["route"="bus"](${kutu})->.hatlar;
    .hatlar out body;
    node(r.hatlar)->.duraklar;
    .duraklar out skel qt;
  `;
}

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
 * Overpass yanıtını "hat → durak noktaları" listesine çevirir.
 * @returns {Array<{numara: string, noktalar: Array<{enlem: number, boylam: number}>}>}
 */
function hatlariCoz(veri) {
  const dugumler = new Map();
  const iliskiler = [];

  for (const oge of (veri && veri.elements) || []) {
    if (oge.type === 'node' && oge.lat !== undefined) {
      dugumler.set(oge.id, { enlem: oge.lat, boylam: oge.lon });
    } else if (oge.type === 'relation') {
      iliskiler.push(oge);
    }
  }

  const hatlar = [];
  for (const iliski of iliskiler) {
    const etiket = iliski.tags || {};
    if (!eshotSayilirMi(etiket)) continue;

    const numara = hatNumarasi(etiket);
    if (!numara) continue;

    const noktalar = [];
    for (const uye of iliski.members || []) {
      if (uye.type !== 'node') continue;
      const nokta = dugumler.get(uye.ref);
      if (nokta) noktalar.push(nokta);
    }
    if (noktalar.length) hatlar.push({ numara, noktalar });
  }

  return hatlar;
}

/**
 * Bir durağa [yakinlikM] içinde uğrayan hat numaraları.
 * @param {{enlem: number, boylam: number}} durak
 * @param {Array} hatlar hatlariCoz çıktısı
 */
function duragaYakinHatlar(durak, hatlar, yakinlikM = OTOBUS_YAKINLIK_M) {
  const bulunan = new Set();

  for (const hat of hatlar) {
    for (const nokta of hat.noktalar) {
      if (metreUzaklik(durak, nokta) <= yakinlikM) {
        bulunan.add(hat.numara);
        break;
      }
    }
  }

  return [...bulunan].sort(hatSirala);
}

module.exports = {
  eshotSayilirMi,
  hatNumarasi,
  hatlariCoz,
  duragaYakinHatlar,
  hatSirala,
  sorguKur,
  metreUzaklik,
  OTOBUS_YAKINLIK_M,
  SINIR
};
