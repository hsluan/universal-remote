import '../../../domain/devices/device_kind.dart';

/// One recommendation in a setup guide.
class GuidePoint {
  const GuidePoint({required this.title, required this.detail, this.tag});

  final String title;
  final String detail;

  /// Short label such as "Works now" or "Coming next".
  final String? tag;
}

/// What to buy or set up so the app can control a kind of device.
class SetupGuide {
  const SetupGuide({required this.intro, required this.points});

  final String intro;
  final List<GuidePoint> points;
}

/// Wi-Fi smart plugs, from easiest for this app to control locally to cheapest.
const List<GuidePoint> _smartPlugs = [
  GuidePoint(
    title: 'Shelly Plus Plug S / Plug S Gen3',
    tag: 'Best fit',
    detail: 'Fully local: the app finds it on your Wi-Fi and switches it with no account, and it reports power '
        'use. Imported only in Vietnam, with a round-pin Schuko plug (needs a Type F socket or an adapter).',
  ),
  GuidePoint(
    title: 'CozyLife Wi-Fi plug (about 161,000₫)',
    tag: 'Cheaper',
    detail: 'Simple local control without any key. Many cheap plugs run Tuya firmware instead, so pick a listing '
        'that names the CozyLife app.',
  ),
  GuidePoint(
    title: 'Tuya / Smart Life plug (161,000–183,000₫)',
    tag: 'Shortcut now',
    detail: 'Sold everywhere, but switching it locally needs a key from a Tuya developer account. Until then, add '
        'it as a shortcut to Smart Life.',
  ),
  GuidePoint(
    title: 'Avoid',
    detail: 'Tapo P110M (needs your TP-Link login), Sonoff S26R2 / MINIR4 (need the eWeLink cloud key), and '
        'anything wired into the appliance: that is mains electrics, a job for an electrician.',
  ),
];

/// Guides for kinds that need add-on hardware, a setting on the device, or an
/// integration that is not built yet. Researched October 2026; sources are listed
/// in ARCHITECTURE_AND_PLAN.md.
const Map<DeviceKind, SetupGuide> setupGuides = {
  DeviceKind.fan: SetupGuide(
    intro: 'A fan without a remote can still be switched on and off: plug it into a Wi-Fi smart plug and leave the '
        "fan's own switch on. It must start by itself when power comes back: a rotary knob does, touch buttons that "
        'start in "off" do not. Smart plug control is the next update of this app.',
    points: _smartPlugs,
  ),
  DeviceKind.plug: SetupGuide(
    intro: 'Smart plugs turn anything with a power switch into a remote-controlled device (fan, lamp, kettle). '
        'Local control over your Wi-Fi is the next update of this app.',
    points: _smartPlugs,
  ),
  DeviceKind.light: SetupGuide(
    intro: 'Three ways, from easiest for this app to cheapest. Wi-Fi light control is the next update; IR bulbs '
        'right after it.',
    points: [
      GuidePoint(
        title: 'Philips WiZ bulbs',
        tag: 'Best fit',
        detail: 'Sold by Signify in Vietnam. Set each bulb up once in the WiZ app; then this app finds and controls '
            'it over your Wi-Fi with no account (local control is on by default): on/off, brightness, white tone '
            'and colour.',
      ),
      GuidePoint(
        title: 'Yeelight W3 (about 202,000₫)',
        tag: 'Good',
        detail: 'Switch on LAN Control once in the Yeelight app, then this app controls it locally. Buy '
            'Yeelight-branded bulbs: Xiaomi-branded ones lost LAN control in 2021.',
      ),
      GuidePoint(
        title: 'IR RGB bulb or LED strip with a 24-key remote',
        tag: 'Cheapest',
        detail: "Driven by this phone's IR blaster, no Wi-Fi needed: on/off, brightness and colours. One-way (the "
            "app can't read the bulb's state) and the phone must point at it.",
      ),
      GuidePoint(
        title: 'Avoid for now',
        detail: 'Xiaomi Mi and Tapo bulbs need your cloud login for local control; Rạng Đông smart bulbs use '
            'Bluetooth Mesh with no public API. Keep using their apps (as shortcuts).',
      ),
    ],
  ),
  DeviceKind.camera: SetupGuide(
    intro: "Today: a shortcut to the camera's app. Next: live view and pan/tilt inside this app over your Wi-Fi "
        '(RTSP/ONVIF), without the maker\'s cloud. Get your cameras ready for it:',
    points: [
      GuidePoint(
        title: 'Imou',
        tag: 'Coming next',
        detail: 'Live view uses RTSP with the user "admin" and the safety code on the camera label (or the device '
            'password set in Imou Life). Pan/tilt over ONVIF depends on the model.',
      ),
      GuidePoint(
        title: 'EZVIZ',
        tag: 'Coming next',
        detail: 'In the EZVIZ app: Profile › Settings › LAN Live View › scan › your camera › Local Server Settings › '
            'enable RTSP. Password: the 6-letter verification code on the label. Some firmware turns RTSP off again '
            'after a reboot; doorbells have no RTSP.',
      ),
      GuidePoint(
        title: 'Tapo',
        tag: 'Coming next',
        detail: 'In the Tapo app: your camera › Device Settings › Advanced Settings › Camera Account. Battery models '
            '(C410, C420, C425) have no RTSP, and only two of Tapo Care, SD recording and RTSP/ONVIF run at once.',
      ),
      GuidePoint(
        title: 'Hikvision',
        tag: 'Coming next',
        detail: "ONVIF is off by default: in the camera's web page open Configuration › Network › Advanced Settings › "
            'Integration Protocol, enable ONVIF and add an ONVIF user.',
      ),
      GuidePoint(
        title: 'Xiaomi',
        tag: 'Shortcut only',
        detail: 'Xiaomi cameras have no local stream (Xiaomi says the C300 and CW300 support neither RTSP nor ONVIF), '
            'so link them to Xiaomi Home. Showing them here would need an always-on home computer running go2rtc, '
            'which supports the C200, C300, C400, C500 Pro and AW300.',
      ),
      GuidePoint(
        title: 'On this phone',
        detail: 'The Redmi 4X decodes one 1080p video at a time in hardware, so the app will show the small '
            "sub-stream in lists and each camera's main stream only full screen.",
      ),
    ],
  ),
  DeviceKind.vehicle: SetupGuide(
    intro: 'A phone cannot unlock or start a motorbike: smart keys use their own radio, and the makers\' apps '
        'show information rather than control the bike.',
    points: [
      GuidePoint(
        title: 'Honda Smart Key',
        tag: 'Not possible',
        detail: 'The key fob talks to the bike over its own short-range radio; no app can replace it. My Honda+ '
            '(warranty, maintenance) and Honda RoadSync (navigation on supported bikes) can be added as shortcuts.',
      ),
      GuidePoint(
        title: 'Yamaha Y-Connect',
        tag: 'Android 8+',
        detail: 'Last parking spot, fault alerts and fuel use, on bikes with a CCU unit. It needs Android 8 or newer, '
            'so it does not run on the Redmi 4X (Android 7).',
      ),
      GuidePoint(
        title: 'Find my bike',
        tag: 'Coming next',
        detail: 'A coin-sized Bluetooth tag (iTag) on the bike: the app makes it beep and remembers where the phone '
            'last saw it. It has no GPS of its own and beeps when you walk away, so it helps in a car park, not '
            'against theft.',
      ),
      GuidePoint(
        title: 'Anti-theft',
        detail: 'For tracking and remote engine cut-off, use a GPS tracker with a SIM card (for example Viettel '
            'Smart Motor) and add its app as a shortcut.',
      ),
    ],
  ),
  DeviceKind.tv: SetupGuide(
    intro: "TVs are next for this phone's IR blaster: codes for Samsung, LG, Sony, Panasonic and Toshiba TVs are "
        'already in the app.',
    points: [
      GuidePoint(
        title: 'TV remote',
        tag: 'Coming next',
        detail: 'Power, volume, channels, arrows, OK, back, home, source and numbers, with the same brand search as '
            'Find my AC.',
      ),
    ],
  ),
};
