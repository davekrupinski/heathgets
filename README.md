# heathgets

Saves each day's *Heathcliff* strip to a folder on the Synology. It keeps a permanent dated archive plus a fixed `latest` file for widgets and viewers to read.

It runs as a small Docker container on the NUC (CasaOS) and writes to a NAS share mounted on the NUC. It uses only the Ruby standard library, so there are no gems.

## Source

Strips come from [Creators Syndicate](https://www.creators.com/read/heathcliff), Heathcliff's syndicate. Each page provides the strip date (`og:title`), the image (`og:image`) and a link to the previous day. GoComics also carries the strip, but it sits behind a JavaScript bot challenge, so it isn't used.

Creators' page URLs use opaque ids, not dates. To reach older strips, the script starts at today's page and follows the "previous" links.

## Output

```
<data root>/
├── .heathgets                      # marker that proves the share is mounted
└── heathcliff/
    ├── 2026/2026-11-09.jpg         # one file per day, kept forever
    ├── latest.jpg                  # newest strip, fixed name
    └── latest.json                 # {date, file, latest_file, image_url, fetched_at}
```

- Writes are atomic: each file goes to a temp file first and is then renamed into place.
- `latest.*` only moves forward, so backfilling old dates never replaces it.

## Commands

```
bin/heathgets init               # create the marker (once, on the real share)
bin/heathgets run [DAYS]         # fetch missing strips from the last DAYS days (default 7)
bin/heathgets fetch FROM[..TO]   # backfill, e.g. 2026-01-01..2026-11-08
bin/heathgets daemon             # run now, then at each HEATHGETS_RUN_HOURS (default 6,12 ET)
```

- **`run`** walks back from today and stops at the first day that's already saved. If the NUC or NAS was down for a few days, the next run fills the gap.
- **`fetch`** walks back one page per day, about 2 seconds per page, so going back a year takes roughly 15 minutes.
- **Missing marker:** every command except `init` refuses to run if the data root has no `.heathgets` file. If the NAS isn't mounted, the script won't write into the empty mountpoint on the NUC's own disk.

## Install on CasaOS

GitHub builds the Docker image on every push to `main` and publishes it as
`ghcr.io/davekrupinski/heathgets:latest`. The NUC just downloads it, so there's nothing to build there.

1. **Pick the folder.** Choose a folder on the Synology for the strips (e.g. `comics`) and find its path as the NUC sees it. In CasaOS, open **Files** and browse to the mounted Synology share. The path is shown at the top, e.g. `/media/synology/comics`.
2. **Import the app.** In CasaOS, open **App Store**, then **Custom Install** (top right), then **Import** (the icon at the top right of that dialog). Paste the contents of [`casaos/docker-compose.yml`](casaos/docker-compose.yml) and click **Submit**.
3. **Set the folder.** In the form, under **Volumes**, replace `/media/CHANGE-ME/comics` with your folder path. Then click **Install**.
4. **Mark the folder.** This is a one-time step. Open the app's **⋮** menu, choose **Terminal**, and run:
   ```sh
   bin/heathgets init
   ```
   The app retries every 15 minutes until this is done. To fetch right away instead, restart the app from the same menu.
5. **Check it worked.** Open **Logs** from the **⋮** menu and look for `saved .../2026-11-09.jpg`. The files should also be visible in Synology File Station.

**Updating:** push to GitHub, wait for the build to finish (see the repo's Actions tab), then choose **Check then update** in the app's ⋮ menu in CasaOS.

**Backfilling** (optional, from the app terminal):
```sh
bin/heathgets fetch 2026-01-01..2026-11-08
```

**Permissions:** the container runs as user `1000:1000`. If the logs show `Permission denied` writing to the share, change `user:` (in the app's settings) to the owner of the share's files. Run `ls -ln` on the folder over SSH to see the owner.

**Without CasaOS:** from a checkout, `cp .env.example .env`, edit it, then run `docker compose up -d`.

## Development

```sh
rake test                                             # minitest, no network
HEATHGETS_DATA=./tmp-data bin/heathgets init
HEATHGETS_DATA=./tmp-data bin/heathgets run 3         # real fetch into ./tmp-data
```

`test/fixtures/` holds saved copies of two real pages. If Creators changes its layout, save a fresh page there and update `Fetcher.parse`.
