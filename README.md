<div align="center">

# Kiss VPN

**Десктоп-клиент для [kissmain.ru](https://kissmain.ru) под Windows**

[![release](https://img.shields.io/github/v/release/Loretiks/kiss-vpn?style=for-the-badge&color=ff4d8d&label=релиз)](https://github.com/Loretiks/kiss-vpn/releases/latest)
[![downloads](https://img.shields.io/github/downloads/Loretiks/kiss-vpn/total?style=for-the-badge&color=8b5cf6&label=скачиваний)](https://github.com/Loretiks/kiss-vpn/releases)
[![platform](https://img.shields.io/badge/Windows-10%20%7C%2011-0078d4?style=for-the-badge)](https://github.com/Loretiks/kiss-vpn/releases/latest)
[![telegram](https://img.shields.io/badge/Telegram-melanholy-26A5E4?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/m3lanh0lyy)

VLESS · Reality · XTLS-Vision · TUN · Split-tunneling · Auto-update

</div>

---

## Скачать

<table>
<tr>
<td width="50%" align="center">

### Установщик
[**KissVPN-Setup-0.1.0.exe**](https://github.com/Loretiks/kiss-vpn/releases/latest/download/KissVPN-Setup-0.1.0.exe)

~50 MB · Windows 10/11 (x64)

</td>
<td width="50%" align="center">

### Подписка
Получить ссылку: [kissmain.ru](https://kissmain.ru)

Формат: `https://kissmain.ru/sub/...`

</td>
</tr>
</table>

После установки приложение **обновляется автоматически** — в фоне раз в 6 часов проверяет новые релизы и предлагает поставить.

---

## Что умеет

- **VLESS + Reality + XTLS-Vision** — современный стек обхода, ядро [Mihomo](https://github.com/MetaCubeX/mihomo) v1.19.25 в комплекте.
- **Подписка kissmain.ru** — вставил ссылку → автоматически подтянулись все серверы со страновыми флагами и информацией о трафике.
- **Два режима**:
  - **Системный прокси** — без прав администратора, прокси на `127.0.0.1:7890`.
  - **TUN** — весь трафик системы через VPN, нужен helper-сервис (ставится при инсталляции).
- **Split-tunneling** в стиле SnowVPN — 7 типов правил:
  - Процесс · Домен (суффикс) · Ключевое слово · GeoSite (умное) · IP-CIDR · ASN · GeoIP
  - 5 готовых пресетов: РФ через прямой канал, Telegram/Discord через VPN, заблокированные ресурсы, и т.д.
- **Пинг до подключения** — параллельная проверка задержки до всех серверов, как в SnowVPN/FlClashX.
- **Авто-обновление** через GitHub Releases — silent install, рестарт приложения.
- **Аккуратное завершение** — при выходе/крэше системный прокси откатывается, маршруты убираются, Chrome продолжает работать.

---

## Скриншоты

> Скриншоты появятся в одном из ближайших релизов.

---

## Системные требования

| | |
|---|---|
| ОС | Windows 10 1809+ / Windows 11 |
| Архитектура | x64 |
| Права | Обычный пользователь для прокси-режима; админ при первой установке для TUN |
| Антивирус | Может ругаться на TUN-драйвер (Wintun) и helper-сервис — добавьте папку установки в исключения |

Если включён **Microsoft Vulnerable Driver Blocklist** (по умолчанию в Win11), TUN не запустится — нужно отключить блок-лист в `Параметры → Конфиденциальность и защита → Безопасность Windows → Безопасность устройства → Изоляция ядра`.

---

## Архитектура

```
┌─────────────────────────────────────────────────────────────┐
│  kiss_vpn.exe        Flutter UI (user-space)                │
│  Подписки · сервера · правила · трей · статистика           │
└────────┬────────────────────────────┬───────────────────────┘
         │ named pipe                 │ REST + WebSocket
         ▼                            ▼
┌────────────────────────┐   ┌──────────────────────────────┐
│ KissVPNHelper.exe      │   │ KissVPNCore.exe (Mihomo)     │
│ C# .NET 8 service      │   │ VLESS + Reality + XTLS       │
│ Wintun · маршруты      │   │ TUN / mixed-port             │
│ DNS · firewall         │   │ REST API @ 127.0.0.1:9090    │
└────────────────────────┘   └──────────────────────────────┘
```

Три отдельных процесса вместо одного монолита: UI ничего не знает о привилегированных операциях, ядро изолировано и переживает рестарт UI.

---

## Сборка из исходников

```powershell
# Однократно — скачать бандл (Mihomo, Wintun, GeoIP):
powershell -ExecutionPolicy Bypass -File scripts\fetch-vendor.ps1

# Сборка релиз-инсталлера:
powershell -ExecutionPolicy Bypass -File scripts\build.ps1
```

Подробнее: [`docs/releasing.md`](docs/releasing.md).

**Зависимости разработчика:**
- Flutter ≥ 3.27 stable (`flutter config --enable-windows-desktop`)
- .NET 8 SDK
- Visual Studio Build Tools (C++ Desktop workload)
- Inno Setup 6 (`winget install JRSoftware.InnoSetup`) — только для упаковки

---

## Связь

- Автор и поддержка: [**@m3lanh0lyy**](https://t.me/m3lanh0lyy)
- Сервис: [**kissmain.ru**](https://kissmain.ru)
- Баги и предложения: [Issues](https://github.com/Loretiks/kiss-vpn/issues)

---

## Лицензии бандла

Третьи компоненты сохраняют оригинальные лицензии:

| Компонент | Лицензия | Источник |
|---|---|---|
| Mihomo (Clash.Meta) | GPL-3.0 | [MetaCubeX/mihomo](https://github.com/MetaCubeX/mihomo) |
| Wintun | GPL-2.0 | [wintun.net](https://www.wintun.net) |
| GeoIP / GeoSite | CC BY-SA 4.0 | [Loyalsoldier](https://github.com/Loyalsoldier/v2ray-rules-dat), [MetaCubeX](https://github.com/MetaCubeX/meta-rules-dat) |
| country_flags | MIT | [hampuslavin/country_flags](https://pub.dev/packages/country_flags) |

Mihomo используется **как отдельный бинарник без модификаций** — UI/helper линкуются только между собой.
