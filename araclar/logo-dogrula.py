#!/usr/bin/env python3
"""
Logonun geometrisini denetler.

    python3 araclar/logo-dogrula.py

logo-uret.py markayı ÜRETİR; bu betik ürettiğinin doğru olduğunu SORAR:

  · iki yay birbirinin tam 180° döndürülmüşü mü (marka dönme simetrik)
  · kelime kilidi halkanın merkezine oturuyor mu
  · yaylar kelimeye ya da alt yazıya değiyor mu
  · yaylar 200'lük kutunun dışına taşıyor mu

Resmî logoda yaylar kelimeye DEĞMİYOR: piksel ölçümüyle kırmızı yayın kutusu
satır 19..48, kelime 51'de başlıyor; mavi yay 92'de başlıyor, alt yazı 89'da
bitiyor. Bizdeki halka bir ara kelimeye göre küçüktü ve yaylar hem kelimeyi hem
alt yazıyı kesiyordu — alt yazı yayla aynı renk olduğu için okunmuyordu bile.
"""
import math
import sys

sys.path.insert(0, __file__.rsplit('/', 1)[0])
from importlib import import_module

uret = import_module('logo-uret')

MERKEZ = uret.MERKEZ
KUTU = 200

# Metin mürekkebinin kapladığı alan. Büyük harf yüksekliği punto × 0.72,
# alt yazının tamamı taban çizgisinden 6 birim yukarı.
KELIME = (30.8, uret.KELIME_TABANI - 41, 168.3, uret.KELIME_TABANI)
ALT_YAZI = (44, uret.ALT_YAZI_TABANI - 6, 156, uret.ALT_YAZI_TABANI)


def yayKalinligi(aci, yay):
    """Verilen açıdaki yay kalınlığı; yay uca doğru inceliyor."""
    a1, a2 = yay[0] % 360, yay[1] % 360
    if a1 <= a2:
        icinde = a1 <= aci <= a2
        u = (aci - a1) / (a2 - a1)
    else:
        icinde = aci >= a1 or aci <= a2
        u = ((aci - a1) % 360) / ((a2 - a1) % 360)
    if not icinde:
        return None
    kalin, ince = (k * uret.OLCEK for k in uret.KALINLIK)
    return kalin + (ince - kalin) * u


def bandaUzaklik(x, y):
    """Noktanın en yakın yay bandına uzaklığı; negatifse bandın üstünde."""
    dx, dy = x - MERKEZ, MERKEZ - y
    r = math.hypot(dx, dy)
    aci = math.degrees(math.atan2(dy, dx)) % 360

    enAz = None
    for yay in (uret.KIRMIZI_YAY, uret.MAVI_YAY):
        kalinlik = yayKalinligi(aci, yay)
        if kalinlik is None:
            continue
        uzaklik = abs(r - uret.YARICAP) - kalinlik / 2
        enAz = uzaklik if enAz is None else min(enAz, uzaklik)
    return enAz


def kutuBosluğu(kutu, adim=60):
    x0, y0, x1, y1 = kutu
    enAz = None
    for i in range(adim + 1):
        for j in range(adim + 1):
            u = bandaUzaklik(x0 + (x1 - x0) * i / adim, y0 + (y1 - y0) * j / adim)
            if u is None:
                continue
            enAz = u if enAz is None else min(enAz, u)
    return enAz


def main():
    sorun = 0

    def denetle(baslik, gecti, ayrinti=''):
        nonlocal sorun
        if not gecti:
            sorun += 1
        print(('  ✓ ' if gecti else '  ✗ ') + baslik + (('  — ' + ayrinti) if ayrinti else ''))

    print('\nLogo geometrisi\n')

    denetle(
        'yaylar birbirinin 180° döndürülmüşü',
        uret.MAVI_YAY == (uret.KIRMIZI_YAY[0] + 180, uret.KIRMIZI_YAY[1] + 180),
        f'kırmızı {uret.KIRMIZI_YAY}, mavi {uret.MAVI_YAY}')

    # Kilit: kelime mürekkebinin üstünden alt yazının altına.
    kilitUst, kilitAlt = KELIME[1], ALT_YAZI[3]
    kilitOrta = (kilitUst + kilitAlt) / 2
    denetle('kelime kilidi halkanın merkezine oturuyor',
            abs(kilitOrta - MERKEZ) <= 1.0,
            f'kilit ortası y={kilitOrta:.1f}, halka merkezi y={MERKEZ:.0f}')

    denetle('kelime yatayda ortalı',
            abs((KELIME[0] + KELIME[2]) / 2 - MERKEZ) <= 1.0,
            f'orta x={(KELIME[0] + KELIME[2]) / 2:.1f}')

    for ad, kutu in (('kelime', KELIME), ('alt yazı', ALT_YAZI)):
        bosluk = kutuBosluğu(kutu)
        denetle(f'{ad} yaylara değmiyor',
                bosluk is None or bosluk > 0,
                'değiyor' if (bosluk is not None and bosluk <= 0)
                else f'{bosluk:.1f} birim boşluk' if bosluk is not None else 'yay yok')

    dis = uret.YARICAP + uret.KALINLIK[0] * uret.OLCEK / 2
    denetle('yaylar kutunun içinde', dis < KUTU / 2,
            f'dış yarıçap {dis:.1f}, kenara {KUTU / 2 - dis:.1f} birim')

    print(f'\n{"sorun yok" if not sorun else str(sorun) + " sorun"}\n')
    sys.exit(1 if sorun else 0)


if __name__ == '__main__':
    main()
