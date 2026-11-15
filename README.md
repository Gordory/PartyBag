# Party Bag

Аддон для WoW Forever (`Interface: 16001`). Каждый участник группы рассылает скрытыми addon-сообщениями
содержимое своих сумок (`itemID → количество`). При наведении на предмет в тултипе видно, у кого из группы
он есть и сколько, — удобно собирать неполные стаки у одного игрока.

Аддон должен стоять у всех, чьи сумки нужно видеть.

## Как работает

- Сканируются сумки 0–4 (без банка).
- После изменения сумок (с задержкой 2 с) отправляется полный снимок, если он изменился.
  Снимок режется на куски ≤ 255 байт (`S;ver;seq;idx;total;id:n,...`).
- При входе в группу или `/reload` аддон рассылает запрос `R;ver`, и все в ответ присылают свои снимки.
- Когда кто-то уходит из группы, его данные удаляются; при выходе из группы удаляются все.

## Команды

- `/partybag` или `/pbag` — от кого получены данные
- `/partybag sync` — запросить данные заново

## Деплой

```sh
./deploy.sh              # → /Volumes/Data/Games/World of Warcraft/_forever_/Interface/AddOns/PartyBag
DRY_RUN=1 ./deploy.sh    # только показать изменения
./deploy.sh _classic_era_  # в другую версию клиента
```

В локальной копии в `.toc` останется `@project-version@` — версию подставляет только packager при релизе.

## Релиз на CurseForge

Сборку и загрузку делает [BigWigs Packager](https://github.com/BigWigsMods/packager)
(`.github/workflows/release.yml`) при пуше тега `v*`:

```sh
git tag v0.1.0
git push origin v0.1.0
```

Тег без суффикса — Release, `v0.1.0-beta1` — Beta, `v0.1.0-alpha1` — Alpha.
Что попадает в zip, задаётся в `.pkgmeta`.

Одноразовая настройка:
1. Создать проект на [authors.curseforge.com](https://authors.curseforge.com) и дождаться модерации.
2. Добавить его ID в `PartyBag.toc`: `## X-Curse-Project-ID: <id>`.
3. Создать API-токен (authors.curseforge.com → API Tokens) и сохранить в секрет репозитория `CF_API_KEY`:
   `gh secret set CF_API_KEY`.

Без ID проекта или токена packager только создаёт GitHub Release с zip.

## Иконка

`Media/Icon.tga` (64×64, в игре) и `art/curseforge-avatar.png` (400×400, аватар проекта на CurseForge)
собраны из `art/icon-source.png` скриптом `art/make_icon.py` (нужны Pillow, numpy, scipy):

```sh
python3 art/make_icon.py art/icon-source.png <out_dir>
```
