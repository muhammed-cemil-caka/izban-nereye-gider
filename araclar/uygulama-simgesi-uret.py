#!/usr/bin/env python3
"""
Android başlatıcı simgesini üretir.

    python3 araclar/uygulama-simgesi-uret.py

Flutter'ın varsayılan mavi simgesi duruyordu; Play Console kendi simgeni
ister ve varsayılanla yayımlanan uygulama amatör görünür.

Simge, logonun SADELEŞTİRİLMİŞ hâli: iki yay ve "İZBAN". Alt yazı
("İZMİR BANLİYÖ SİSTEMİ") 48 px'te okunmuyor, çıkarıldı — başlatıcı simgesi
markanın küçültülmüşü değil, tanınacak kadarıdır.

Geometri araclar/logo-uret.py ile aynı kaynaktan; SVG çizici bulunmadığı için
(cairosvg/rsvg/inkscape yok) yaylar burada doğrudan çizilir.

Yazılan dosyalar:
    mobile/android/app/src/main/res/mipmap-*/ic_launcher.png   (48…192)
    mobile/android/app/src/main/ic_launcher-playstore.png       (512)
"""
import math
import pathlib

from PIL import Image, ImageDraw, ImageFont

KOK = pathlib.Path(__file__).resolve().parent.parent

# logo-uret.py ile aynı ölçüler (200'lük kare).
OLCEK = 200 / 240
MERKEZ = 100.0
YARICAP = 79.0
KIRMIZI_YAY = (24, 116)
MAVI_YAY = (KIRMIZI_YAY[0] + 180, KIRMIZI_YAY[1] + 180)
KALINLIK = (34 * OLCEK, 6 * OLCEK)

KIRMIZI = (237, 27, 36)
MAVI = (12, 76, 163)
PLAKA = (255, 255, 255)

# Başlatıcı simgesinde kelime, alt yazı olmadığı için biraz büyütülür ve
# halkanın merkezine oturur.
KELIME_TABANI = 118.0
KELIME_PUNTO = 62.0

# Simgenin kenarında güvenli boşluk: Android maskeleri köşeleri kırpıyor.
IC_ORAN = 0.86

YAZI_TIPLERI = [
    '/System/Library/Fonts/Supplemental/Arial Bold.ttf',
    '/System/Library/Fonts/Supplemental/Arial Unicode.ttf',
    '/Library/Fonts/Arial Bold.ttf',
    '/System/Library/Fonts/Helvetica.ttc',
]

BOYUTLAR = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
}


def yaziTipi(punto):
    for yol in YAZI_TIPLERI:
        if pathlib.Path(yol).exists():
            try:
                return ImageFont.truetype(yol, punto)
            except OSError:
                continue
    return ImageFont.load_default()


def nokta(aci, r):
    return (MERKEZ + r * math.cos(math.radians(aci)),
            MERKEZ - r * math.sin(math.radians(aci)))


def yayCiz(ciz, yay, renk, olcek, adim=120):
    """Ucu incelen yayı, saydamlığı uca doğru azalan dilimlerle çizer.

    SVG'deki gradyanın karşılığı: yayın sönük ucu şeffaf başlar, keskin ucunda
    tam opak olur.
    """
    a1, a2 = yay
    for i in range(adim):
        u1, u2 = i / adim, (i + 1) / adim
        # Sönük uçtan keskin uca: saydamlık 0 → 255.
        saydam = int(255 * (u1 ** 0.75))
        parcalar = []
        for u in (u1, u2):
            aci = a2 + (a1 - a2) * u
            kal = KALINLIK[1] + (KALINLIK[0] - KALINLIK[1]) * u
            parcalar.append((aci, kal))

        kose = []
        for aci, kal in parcalar:
            kose.append(nokta(aci, YARICAP + kal / 2))
        for aci, kal in reversed(parcalar):
            kose.append(nokta(aci, YARICAP - kal / 2))

        ciz.polygon([(x * olcek, y * olcek) for x, y in kose], fill=renk + (saydam,))


def simgeUret(boyut):
    # İçe yerleşim: kenar boşluğu bırakılır.
    ic = int(boyut * IC_ORAN)
    olcek = ic / 200

    tuval = Image.new('RGBA', (boyut, boyut), (0, 0, 0, 0))

    # Beyaz plaka: marka renkleri koyu zeminde de okunsun.
    plaka = ImageDraw.Draw(tuval)
    yaricap = int(boyut * 0.22)
    plaka.rounded_rectangle([0, 0, boyut - 1, boyut - 1], radius=yaricap, fill=PLAKA)

    katman = Image.new('RGBA', (ic, ic), (0, 0, 0, 0))
    ciz = ImageDraw.Draw(katman)
    yayCiz(ciz, KIRMIZI_YAY, KIRMIZI, olcek)
    yayCiz(ciz, MAVI_YAY, MAVI, olcek)

    # "İZ" mavi, "BAN" kırmızı — logodaki bölünme.
    punto = max(8, int(KELIME_PUNTO * olcek))
    font = yaziTipi(punto)
    iz, ban = 'İZ', 'BAN'
    izGenislik = ciz.textlength(iz, font=font)
    banGenislik = ciz.textlength(ban, font=font)
    toplam = izGenislik + banGenislik
    x = (ic - toplam) / 2
    y = KELIME_TABANI * olcek

    ciz.text((x, y), iz, font=font, fill=MAVI + (255,), anchor='ls')
    ciz.text((x + izGenislik, y), ban, font=font, fill=KIRMIZI + (255,), anchor='ls')

    kaydir = (boyut - ic) // 2
    tuval.alpha_composite(katman, (kaydir, kaydir))
    return tuval


def main():
    res = KOK / 'mobile' / 'android' / 'app' / 'src' / 'main' / 'res'
    for klasor, boyut in BOYUTLAR.items():
        hedef = res / klasor / 'ic_launcher.png'
        hedef.parent.mkdir(parents=True, exist_ok=True)
        simgeUret(boyut).save(hedef)
        print(f'  {klasor}/ic_launcher.png  {boyut}×{boyut}')

    magaza = KOK / 'mobile' / 'android' / 'app' / 'src' / 'main' / 'ic_launcher-playstore.png'
    # Play Console 512×512 ve saydamlıksız ister.
    kare = Image.new('RGB', (512, 512), PLAKA)
    kare.paste(simgeUret(512), (0, 0), simgeUret(512))
    kare.save(magaza)
    print(f'  ic_launcher-playstore.png  512×512  (Play Console listeleme simgesi)')


if __name__ == '__main__':
    main()
