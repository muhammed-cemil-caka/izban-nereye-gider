# Turistik yerler modülü — tasarım

Kullanıcının biniş ve iniş durağı çevresindeki tarihi/turistik yerleri kart
olarak göstermek, oraya üç kiple (yürüyüş, toplu taşıma, araba) rota çizmek ve
kip değişince en yakın durağı **o kipin ağına göre** yeniden seçmek.

Bu belge veri şemasını, harita entegrasyonunu ve durak seçim algoritmasını
tanımlar. Halihazırda kurulu olan parçalar ayrıca işaretlendi.

---

## 0. Neyin hazır olduğu

| Madde | Durum |
| --- | --- |
| Kipe göre en yakın durak (yürüyüş/araba matrisi) | **Hazır** — `mesafeleriAl` (web) · `RotaServisi.mesafeler` (mobil) |
| Araba rotası (OSRM `routed-car`) | **Hazır** — `RotaKipi.araba` |
| Araba rotası kesintisiz mavi şerit | **Hazır** — web `rotayiCiz`, mobil `_arabaRengi` + `StrokePattern.solid` |
| Aktarma noktalarına canlı yönlendirme | **Hazır** — `aktarmaNoktalari` + `RotaHedefi.aktarma` |
| Turistik yer verisi (foto/başlık/tarihçe) | **Yok** — bu belgenin konusu |
| Toplu taşıma rotası | **Yok** — bkz. §5, gerçek bir kısıt var |

---

## 1. Veri şeması

Turistik yerler durak verisinden **ayrı** bir dosyada tutulur; durak listesi
(`backend/veri/duraklar.json`) OSM'den üretiliyor ve her üretimde yeniden
yazılıyor, turistik veri onun içinde kaybolur.

`backend/veri/turistik-yerler.json`:

```json
{
  "surum": "1.0.0",
  "guncellemeTarihi": "2026-08-21",
  "kaynak": {
    "yer": "Wikidata — durağa 1500 m'den yakın turizm/tarih ögeleri",
    "metin": "Wikipedia (tr) özet — CC BY-SA 4.0",
    "gorsel": "Wikimedia Commons — her görselin kendi lisansı",
    "lisansUyarisi": "Metin ve görsellerde kaynak gösterimi zorunludur"
  },
  "yerler": [
    {
      "kod": "efes-antik-kenti",
      "ad": "Efes Antik Kenti",
      "tur": "antik-kent",
      "konum": { "enlem": 37.939722, "boylam": 27.340833 },
      "ozet": "Antik Yunan ve Roma döneminin en büyük liman kentlerinden biri...",
      "tarihce": "MÖ 10. yüzyılda İonlar tarafından kurulan kent, Roma döneminde...",
      "gorsel": {
        "adres": "https://upload.wikimedia.org/.../Ephesus_Library_of_Celsus.jpg",
        "kucukAdres": "https://upload.wikimedia.org/.../640px-....jpg",
        "yazar": "Benh LIEU SONG",
        "lisans": "CC BY-SA 3.0",
        "kaynakSayfa": "https://commons.wikimedia.org/wiki/File:..."
      },
      "kaynaklar": {
        "wikidata": "Q47611",
        "wikipedia": "https://tr.wikipedia.org/wiki/Efes"
      },
      "duraklar": [
        { "kod": "selcuk", "kusUcusuM": 2870 }
      ]
    }
  ]
}
```

### Alan kararları

- **`duraklar` listesi yerde tutulur, durakta değil.** Bir yer birden çok
  durağa yakın olabiliyor (Alsancak Gar ve Halkapınar ikisi de Kültürpark'a
  yakın). Ters kurgu aynı yeri iki kez yazdırırdı.
- **`kusUcusuM` üretim zamanında hesaplanır**, gerçek yürüme/sürüş mesafesi
  ise çalışma anında istenir. Sebep: yürüme/sürüş matrisi kullanıcının
  konumuna göre değişiyor, önceden hesaplanamaz.
- **Görsel iki boyutta saklanır**: kart için `kucukAdres` (640 px), tam ekran
  için `adres`. Commons dosyaları 4000 px olabiliyor; kartta indirilmesi
  ziyaret başına megabaytlar demek.
- **`tur`** filtreleme için: `antik-kent`, `muze`, `cami`, `kilise`, `kale`,
  `anit`, `park`, `carsi`, `plaj`.

### Yer–durak eşleşmesi

Yarıçap **1500 m** (İZBAN durağından yürünebilir turistik uzaklık). Bu,
aktarma yarıçapından (600 m) bilinçli olarak büyük: aktarma "hemen yanında
olmalı", turistik yer "o duraktan gidilebilir" demek.

---

## 2. Veri kaynağı ve üretim

`araclar/turistik-yerleri-uret.js` (yeni):

1. **Wikidata SPARQL** — her durak için 1500 m yarıçapta turizm/tarih ögeleri:

   ```sparql
   SELECT ?yer ?yerLabel ?koordinat ?tur WHERE {
     SERVICE wikibase:around {
       ?yer wdt:P625 ?koordinat .
       bd:serviceParam wikibase:center "Point(27.34 37.94)"^^geo:wktLiteral .
       bd:serviceParam wikibase:radius "1.5" .
     }
     ?yer wdt:P31/wdt:P279* ?tur .
     VALUES ?tur { wd:Q839954 wd:Q33506 wd:Q32815 wd:Q16970 wd:Q23413 }
     SERVICE wikibase:label { bd:serviceParam wikibase:language "tr,en". }
   }
   ```

2. **Wikipedia REST** — özet metin:
   `https://tr.wikipedia.org/api/rest_v1/page/summary/<baslik>`

3. **Commons** — görsel ve lisans:
   `https://commons.wikimedia.org/w/api.php?action=query&prop=imageinfo&iiprop=url|extmetadata`

Üçü de anahtarsız ve ücretsiz. Overpass'ta öğrendiğimiz dersler burada da
geçerli: tek sunucu, boş yanıt asla geçerli sayılmaz, çözülemeyen kayıtta eski
değer korunur.

**Lisans:** Wikipedia metni CC BY-SA, Commons görselleri dosya bazında farklı.
Kartta yazar + lisans + kaynak bağlantısı gösterilmesi zorunlu.

---

## 3. Harita entegrasyonu

### Rota çizimi (kipe göre)

| Kip | Renk | Desen | Kalınlık |
| --- | --- | --- | --- |
| Yürüyüş | `#B3541E` turuncu | noktalı | 5 |
| Araba | `#0C4CA3` mavi | **kesintisiz** | 6 |
| Toplu taşıma | yürüyüş bacakları noktalı, hat bacağı kesintisiz `#ED1B24` | karma | 5–6 |

**Web (Leaflet)** — mevcut `rotayiCiz` genişletilir:

```js
function rotayiCiz(noktalar, kip) {
  yuruyusRotasiniTemizle();
  var arabaMi = kip === 'araba';
  yuruyusCizgisi = L.polyline(noktalar, {
    color: arabaMi ? ARABA_RENGI : YURUYUS_RENGI,
    weight: arabaMi ? 6 : 5,
    dashArray: arabaMi ? null : '1 9',
    lineCap: 'round'
  }).addTo(harita);
  sinirlaraOturt(yuruyusCizgisi.getBounds(), [40, 40]);
}
```

**Mobil (flutter_map)** — `Polyline.pattern`:

```dart
final arabaMi = rota.kip == RotaKipi.araba;
Polyline(
  points: noktalar,
  color: arabaMi ? _arabaRengi : _yuruyusRengi,
  strokeWidth: arabaMi ? 6 : 5,
  pattern: arabaMi ? const StrokePattern.solid() : StrokePattern.dotted(),
)
```

> Not: `dashArray: null` ve `StrokePattern.solid()` şart. Araç rotasının
> noktalı çizilmesi hem sürerken okunmuyor hem de iki kip haritada birbirinden
> ayırt edilemiyor.

### Turistik yer işaretleri

Durak işaretlerinden ayrı bir katman: farklı simge (☘/🏛), farklı renk,
tıklanınca kart açılır. Katman durak katmanının **altında** durur — durak
seçimi turistik yer işaretiyle bloklanmasın.

---

## 4. Durak seçim optimizasyonu (kritik mantık)

Kuş uçuşu mesafe **kullanılmaz**. Her kip kendi ağını sorar. Bu mantık
halihazırda kurulu; turistik yer için hedef değişir (durak yerine turistik
nokta).

```
FONKSIYON kipDegisti(yeniKip, hedefNokta):
    # hedefNokta: turistik yerin koordinatı
    # 1) Adayları daralt — kuş uçuşu YALNIZCA ön eleme için
    adaylar = enYakinDuraklar(tumDuraklar, hedefNokta, adet=6)

    # 2) Gerçek mesafe: tek istekte matris, kipin kendi profilinden
    profil = (yeniKip == "yuruyus") ? "routed-foot/table/v1/foot"
                                    : "routed-car/table/v1/driving"
    olcumler = OSRM_MATRIS(kaynak=hedefNokta, hedefler=adaylar, profil)

    # 3) Süreye göre sırala (mesafe değil!)
    #    Araçta 4 km'lik çevre yol, 2 km'lik şehir içinden hızlı olabiliyor.
    sirali = SIRALA(adaylar, anahtar=olcumler.sureSn)

    # 4) Servis yanıt vermezse kuş uçuşu sıralama korunur, uygulama çalışır
    EĞER olcumler BOŞ İSE: sirali = adaylar

    # 5) Kullanıcı bu arada kipi değiştirdiyse geç gelen yanıtı YOK SAY
    EĞER yeniKip != guncelKip: ÇIK

    # 6) Ana durağı güncelle, haritada seçili getir, rotayı yeniden çiz
    anaDurak = sirali[0]
    haritaSecimiGuncelle(anaDurak)
    rotaCiz(baslangic=kullaniciKonumu, bitis=anaDurak, kip=yeniKip)
    kartiTazele(anaDurak, olcumler[anaDurak])
```

### Neden mesafe değil süre

Ölçüldü (Halkapınar civarı): yürüyerek Halkapınar **606 m** ile birinci,
arabayla Hilal **4,4 km** ile birinci çıkıyor — tek yönler ve bölünmüş yollar
sıralamayı tamamen değiştiriyor. Araçta ayrıca uzun ama hızlı yol, kısa ama
yavaş yoldan iyi olabiliyor; bu yüzden sıralama anahtarı **süre**.

### Kaç aday sorulmalı

6. Matris isteği aday sayısıyla değil, **istek sayısıyla** pahalı; 6 aday tek
istekte geliyor. 4 aday, uçtaki durakları kaçırabiliyor.

### Yarış koşulu

Kullanıcı hızlı hızlı kip değiştirirse yanıtlar sırasız dönebilir. Her yanıt
uygulanmadan önce "hâlâ bu kipteyiz mi" diye bakılır — mevcut kodda
`siralamaKipi` / `_siralamaKipi` bunu yapıyor.

---

## 5. Toplu taşıma kipi — dürüst kısıt

OSRM'de toplu taşıma profili **yok**. Gerçek bir "toplu taşıma rotası" için
GTFS beslemesi + OpenTripPlanner benzeri bir motor gerekir; İzmir'in açık GTFS
yayını doğrulanmadı.

Motor kurulmadan verilebilecek dürüst çıktı, elimizdeki veriyle kurulan
**aktarma zinciri**:

```
Kullanıcı konumu
  → (yürüyüş) en yakın İZBAN durağı        ← OSRM foot
  → (İZBAN)   hedefe en yakın İZBAN durağı ← duraklar.json sırası + süre
  → (yürüyüş) turistik yer                 ← OSRM foot
```

Durakta ESHOT/Metro/Tramvay varsa alternatif olarak yazılır (`aktarma` ve
`otobusHatlari` alanları). **Sefer saati ve bekleme süresi verilmez** — o veri
elimizde yok, uydurulması yolcuyu yanıltır.

Gerçek toplu taşıma yönlendirmesi istenirse iş sırası: GTFS kaynağını bulmak →
OTP kurmak → süreleri oradan almak.

---

## 6. Uygulama sırası

1. `turistik-yerler.json` şeması + üretim betiği (Wikidata/Wikipedia/Commons)
2. Veri dağıtımı (`veri-dagit.js`'e ekle) ve doğrulama betiği
3. Kart bileşeni (foto + başlık + tarihçe + lisans satırı) — web ve mobil
4. Haritada turistik yer katmanı
5. Üç kipli rota seçici (yürüyüş/araba hazır, toplu taşıma §5'e göre)
6. Kip değişince durak yeniden seçimi — mevcut algoritmanın hedefini turistik
   noktaya çevir
