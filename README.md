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

Собирает и публикует сам CurseForge (Automatic Packaging) по webhook из GitHub,
по правилам из `.pkgmeta`. Релиз — это пуш тега:

```sh
git tag v0.1.0
git push origin v0.1.0
```

Тег с `alpha` — Alpha, с `beta` — Beta, остальные — Release.
Тег нужно пушить через git: тег, созданный через GitHub API или веб-интерфейс, может не прислать webhook.

Одноразовая настройка:
1. Проект на CurseForge: Settings → Source — GitHub, `https://github.com/Gordory/PartyBag`;
   Automatic Packaging — пакетовать только теги.
2. API-токен: https://www.curseforge.com/account/api-tokens (например, «Webhooks»).
3. GitHub → Settings → Webhooks → Add webhook, Payload URL:
   `https://www.curseforge.com/api/projects/<projectID>/package?token=<token>`,
   остальное по умолчанию. `<projectID>` — в блоке «About This Project» на странице проекта.

## Иконка

`Media/Icon.tga` (64×64) — иконка в списке аддонов, `curseforge/avatar.png` (400×400) — аватар проекта
на CurseForge. Исходник — `art/icon-source.png`.

## Страница на CurseForge

`curseforge/` — исходники страницы проекта: `summary.txt` (короткое описание), `description.md` (полное), `avatar.png`.
Packager их не синхронизирует — после правок скопировать на authors.curseforge.com вручную.
