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

// "Durak var mı" sorusu için daha geniş yarıçap — raylı aktarmalarla aynı.
// Hat NUMARALARI 400 m'den toplanır (600 m'de liste gürültüleniyor), ama
// aktarmanın var olup olmadığı 600 m'de sorulur: Havalimanı'nda ESHOT durağı
// terminal tarafında, İZBAN istasyonundan 400 m'den uzakta.
const OTOBUS_DURAK_YAKINLIK_M = 600;



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

/**
 * Bir otobüs DURAĞI ESHOT sayılır mı?
 *
 * Hat ilişkisi haritalanmamış duraklar için gerekli: İzmir'in dışında OSM'de
 * çoğu durak hiçbir route=bus ilişkisine üye değil. Yalnızca ilişkilere bakmak
 * Torbalı, Pancar, Cumaovası, Gaziemir gibi gerçek ESHOT aktarmalarını
 * "aktarma yok" gösteriyordu.
 *
 * Kural: operator ESHOT diyorsa ya da ad "Aktarma Merkezi" ise kesin ESHOT.
 * Etiketsiz duraklar da ESHOT sayılır (İzmir'de belediye otobüslerini ESHOT
 * işletiyor). Açıkça BAŞKA bir taşıyıcı olanlar elenir: minibüs/dolmuş
 * kooperatifleri, havalimanı servisi (HAVAŞ), turistik seferler.
 */
function eshotDuragiMi(etiket) {
  const ad = (etiket.name || '').toLowerCase();
  const isletmeci = [etiket.operator, etiket.network, etiket.brand]
    .filter(Boolean).join(' ').toLowerCase();

  if (/eshot/.test(isletmeci)) return true;
  if (/aktarma merkezi/.test(ad)) return true;

  // Başka taşıyıcılar: minibüs/dolmuş kooperatifleri, havalimanı servisleri
  // (HAVAŞ, "İzmir Transfer"), turistik seferler.
  const baskasi =
    /minib[üu]s|dolmu[şs]|tesk|hava[şs]|shuttle|servis|transfer|bus to|ephesus/;
  if (baskasi.test(ad) || baskasi.test(isletmeci)) return false;

  // İşletmecisi yazmayan durak: İzmir'de ESHOT.
  return !isletmeci;
}

/** Overpass yanıtındaki otobüs duraklarını (etiketleriyle) döndürür. */
function otobusDuraklariniCoz(veri) {
  const duraklar = [];

  for (const oge of (veri && veri.elements) || []) {
    if (oge.type !== 'node' || oge.lat === undefined) continue;
    const etiket = oge.tags || {};

    const otobusDuragi = etiket.highway === 'bus_stop' ||
      etiket.amenity === 'bus_station' ||
      (etiket.public_transport === 'platform' && etiket.bus === 'yes');
    if (!otobusDuragi) continue;

    duraklar.push({
      ad: (etiket.name || '').trim(),
      eshot: eshotDuragiMi(etiket),
      enlem: oge.lat,
      boylam: oge.lon
    });
  }

  return duraklar;
}

/** Durağa [yakinlikM] içindeki en yakın ESHOT otobüs durağı (yoksa null). */
function duragaYakinOtobusDuragi(
  durak,
  otobusDuraklari,
  yakinlikM = OTOBUS_DURAK_YAKINLIK_M
) {
  let enYakin = null;

  for (const nokta of otobusDuraklari) {
    if (!nokta.eshot) continue;
    const mesafe = metreUzaklik(durak, nokta);
    if (mesafe > yakinlikM) continue;
    if (!enYakin || mesafe < enYakin.mesafeM) {
      enYakin = { ad: nokta.ad, konum: { enlem: nokta.enlem, boylam: nokta.boylam }, mesafeM: mesafe };
    }
  }

  return enYakin;
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

/**
 * Tek sorgu: İZBAN duraklarının çevresindeki otobüs durakları ve onlara
 * uğrayan hat ilişkileri.
 *
 * Bütün İzmir'in hatlarını üye düğümleriyle indirmek ağır kalıyor (aynalar
 * zaman aşımına uğruyor). Burada yalnızca 41 durağın çevresi soruluyor:
 * birkaç yüz düğüm, birkaç yüz ilişki.
 *
 * @param {Array<{enlem: number, boylam: number}>} duraklar
 */
function sorguKur(duraklar, yakinlikM = OTOBUS_DURAK_YAKINLIK_M) {
  // Otobüs durağı OSM'de iki türlü etiketleniyor: highway=bus_stop (yaygın) ve
  // public_transport=platform + bus=yes. Yalnızca ilkini sormak Cumaovası gibi
  // ikinci biçimde çizilmiş durakları kaçırıyordu.
  const cevreler = duraklar
    .map((d) => {
      const cevre = `around:${yakinlikM},${d.enlem},${d.boylam}`;
      return `node(${cevre})["highway"="bus_stop"];\n` +
        `      node(${cevre})["public_transport"="platform"]["bus"="yes"];\n` +
        `      node(${cevre})["amenity"="bus_station"];`;
    })
    .join('\n      ');

  return `
    [out:json][timeout:300];
    (
      ${cevreler}
    )->.duraklar;
    rel(bn.duraklar)["type"="route"]["route"="bus"]->.hatlar;
    .hatlar out body;
    .duraklar out body qt;
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
  OTOBUS_DURAK_YAKINLIK_M,
  eshotSayilirMi,
  eshotDuragiMi,
  otobusDuraklariniCoz,
  duragaYakinOtobusDuragi,
  hatNumarasi,
  hatlariCoz,
  duragaYakinHatlar,
  hatSirala,
  sorguKur,
  metreUzaklik,
  OTOBUS_YAKINLIK_M
};
