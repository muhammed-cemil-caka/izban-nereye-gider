#!/usr/bin/env python3
"""
İZBAN markasını üretir.

  · frontend/gorseller/izban-logo.svg  — duran kopya (üst bantta <img> ile)
  · frontend/index.html                — açılış ekranındaki canlanan kopya,
    iki işaret arasına gömülür (CSS ile canlandırılabilmesi için satır içi olmalı)

Ölçüler resmî logodan (240x240 PNG) piksel ölçümüyle çıkarıldı:
  · halka orta yarıçapı 69.5, yaylar uca doğru incelir (kalınlık 34 → 6)
  · kırmızı yay 24°..116°, mavi yay 196°..292° (0° = sağ, saat yönünün tersi)
  · kelime taban çizgisi y=120, "İZ" x 37..83, "BAN" x 91..202
  · renkler #ED1B24 (kırmızı) ve #0C4CA3 (mavi)
Hepsi 200'lük viewBox'a ölçeklenir. Mobil taraf aynı sayıları
mobile/lib/ekranlar/izban_logosu.dart içinde yeniden üretir.

    python3 araclar/logo-uret.py
"""
import math
import pathlib

OLCEK = 200 / 240
MERKEZ = 100.0
YARICAP = 69.5 * OLCEK
KIRMIZI_YAY = (24, 116)
MAVI_YAY = (196, 292)
KALINLIK = (34, 6)  # keskin uçtan sönük uca

YAZI_TIPI = "system-ui, -apple-system, 'Segoe UI', Roboto, sans-serif"


def nokta(aci, r):
    return (MERKEZ + r * math.cos(math.radians(aci)),
            MERKEZ - r * math.sin(math.radians(aci)))


def yay(a1, a2, adim=44):
    """Ucu incelen yayın kapalı yolu: dış kenar ileri, iç kenar geri."""
    dis, ic = [], []
    for i in range(adim + 1):
        u = i / adim
        aci = a1 + (a2 - a1) * u
        kalinlik = (KALINLIK[0] + (KALINLIK[1] - KALINLIK[0]) * u) * OLCEK
        dis.append(nokta(aci, YARICAP + kalinlik / 2))
        ic.append(nokta(aci, YARICAP - kalinlik / 2))

    parcalar = ['M %.2f %.2f' % dis[0]]
    parcalar += ['L %.2f %.2f' % p for p in dis[1:]]
    parcalar += ['L %.2f %.2f' % p for p in reversed(ic)]
    parcalar.append('Z')
    return ' '.join(parcalar)


def ortaCizgi(a1, a2, adim=44):
    """Süpürme maskesinin yolu: yayın orta çizgisi, sönük uçtan keskin uca."""
    parcalar = ['M %.2f %.2f' % nokta(a1, YARICAP)]
    for i in range(1, adim + 1):
        parcalar.append('L %.2f %.2f' % nokta(a1 + (a2 - a1) * i / adim, YARICAP))
    return ' '.join(parcalar)


def kelime(girinti, sinifOnEki=''):
    """Ortadaki İZBAN yazısı. Genişlikler textLength ile sabitlenir:
    yazı tipi cihazdan cihaza değişse de kilit aynı kalsın."""
    alt = ' class="%s-alt-yazi"' % sinifOnEki if sinifOnEki else ''
    g = ' class="%s-kelime"' % sinifOnEki if sinifOnEki else ' class="izban-kelime"'
    satirlar = [
        '<g%s font-family="%s" font-weight="900">' % (g, YAZI_TIPI),
        '  <text x="30.8" y="120" font-size="57" textLength="40.5" lengthAdjust="spacingAndGlyphs"',
        '        fill="#0C4CA3" stroke="#0C4CA3" stroke-width="1.6" paint-order="stroke">İZ</text>',
        '  <text x="72.5" y="120" font-size="57" textLength="95.8" lengthAdjust="spacingAndGlyphs"',
        '        fill="#ED1B24" stroke="#ED1B24" stroke-width="1.6" paint-order="stroke">BAN</text>',
        '  <text%s x="100" y="131" font-size="7.6" font-weight="700" text-anchor="middle"' % alt,
        '        textLength="112" lengthAdjust="spacing" fill="#0C4CA3">İZMİR BANLİYÖ SİSTEMİ</text>',
        '</g>',
    ]
    return '\n'.join(girinti + satir for satir in satirlar)


def duranGovde():
    return '''  <defs>
    <linearGradient id="izbanKirmizi" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0" stop-color="#ED1B24" stop-opacity="0"/>
      <stop offset=".5" stop-color="#ED1B24" stop-opacity=".62"/>
      <stop offset="1" stop-color="#ED1B24"/>
    </linearGradient>
    <linearGradient id="izbanMavi" x1="1" y1="0" x2="0" y2="0">
      <stop offset="0" stop-color="#0C4CA3" stop-opacity="0"/>
      <stop offset=".5" stop-color="#0C4CA3" stop-opacity=".62"/>
      <stop offset="1" stop-color="#0C4CA3"/>
    </linearGradient>
  </defs>

  <path fill="url(#izbanKirmizi)" d="%s"/>
  <path fill="url(#izbanMavi)" d="%s"/>

%s''' % (yay(*KIRMIZI_YAY), yay(*MAVI_YAY), kelime('  '))


def canliGovde(girinti='          '):
    """Açılış ekranındaki kopya: yaylar maskeyle süpürülerek çizilir."""
    govde = '''<defs>
  <linearGradient id="izbanKirmiziCanli" x1="0" y1="0" x2="1" y2="0">
    <stop offset="0" stop-color="#ED1B24" stop-opacity="0"/>
    <stop offset=".5" stop-color="#ED1B24" stop-opacity=".62"/>
    <stop offset="1" stop-color="#ED1B24"/>
  </linearGradient>
  <linearGradient id="izbanMaviCanli" x1="1" y1="0" x2="0" y2="0">
    <stop offset="0" stop-color="#0C4CA3" stop-opacity="0"/>
    <stop offset=".5" stop-color="#0C4CA3" stop-opacity=".62"/>
    <stop offset="1" stop-color="#0C4CA3"/>
  </linearGradient>
  <!-- Süpürme: orta çizgi boyunca kalın bir çizgi, kesik deseniyle açılır.
       Yay uca doğru inceldiği için doğrudan çizgi olarak çizilemiyor. -->
  <mask id="izbanSupurmeKirmizi">
    <path class="acilis-supurge" d="%s" stroke="#fff" stroke-width="34" fill="none"/>
  </mask>
  <mask id="izbanSupurmeMavi">
    <path class="acilis-supurge" d="%s" stroke="#fff" stroke-width="34" fill="none"/>
  </mask>
</defs>

<path mask="url(#izbanSupurmeKirmizi)" fill="url(#izbanKirmiziCanli)" d="%s"/>
<path mask="url(#izbanSupurmeMavi)" fill="url(#izbanMaviCanli)" d="%s"/>

%s''' % (
        ortaCizgi(KIRMIZI_YAY[1], KIRMIZI_YAY[0]),
        ortaCizgi(MAVI_YAY[1], MAVI_YAY[0]),
        yay(*KIRMIZI_YAY),
        yay(*MAVI_YAY),
        kelime('', 'acilis'),
    )
    return '\n'.join(girinti + satir if satir else '' for satir in govde.split('\n'))


def main():
    kok = pathlib.Path(__file__).resolve().parent.parent

    hedef = kok / 'frontend' / 'gorseller' / 'izban-logo.svg'
    hedef.write_text(
        '<!-- araclar/logo-uret.py ile üretildi — elle düzenlemeyin. -->\n'
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200" '
        'width="200" height="200" role="img" aria-label="İZBAN">\n%s\n</svg>\n'
        % duranGovde(),
        encoding='utf-8')
    print('yazıldı:', hedef.relative_to(kok))

    sayfaYolu = kok / 'frontend' / 'index.html'
    sayfa = sayfaYolu.read_text(encoding='utf-8')
    bas, bit = '<!-- izban-logo:baslangic -->', '<!-- izban-logo:bitis -->'
    i, j = sayfa.index(bas), sayfa.index(bit)
    sayfa = sayfa[:i + len(bas)] + '\n' + canliGovde() + '\n          ' + sayfa[j:]
    sayfaYolu.write_text(sayfa, encoding='utf-8')
    print('gömüldü:', sayfaYolu.relative_to(kok))


if __name__ == '__main__':
    main()
