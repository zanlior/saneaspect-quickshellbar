# Configure prayer times

The public copy has no API endpoint, city or country configured. It does not request a timetable until you provide all three. Prayer times, reminders and azan stay available after configuration.

## Set your API and location

1. Start Island and press **Super+comma** to open Settings.
2. Open **Prayer Times**.
3. Replace the empty **Prayer API URL** field with an HTTPS endpoint containing the literal `{date}` placeholder. For the existing AlAdhan-compatible implementation, the example endpoint is:

   ```text
   https://api.aladhan.com/v1/timingsByCity/{date}
   ```

4. Enter your own **City** and **Country**. These are deliberately blank in the public copy.
5. Choose the calculation method and whether to use Hanafi Asr. Choose the method suitable for your timetable rather than assuming the included default is appropriate for your location.
6. Audio paths start blank. Before the public setup refinement, set `prayerFajrAzanFolder`, `prayerAzanFolder` and optional `prayerAzanFile` in your local `island-shell/settings.json`. The final setup stage exposes these paths in Settings.

Settings are saved locally in `${XDG_CONFIG_HOME:-$HOME/.config}/island-shell/settings.json`. Keep that file out of the public repository.

The endpoint receives your city and country in the request query. `{date}` is replaced with `DD-MM-YYYY`; the code adds `city`, `country`, `method` and `school` parameters with URL encoding. Do not put passwords or API secrets in the endpoint or in committed defaults.

## Replace the API provider

Change the endpoint through Settings; editing Python code is unnecessary for a compatible service. Changing the endpoint also changes the offline cache identity so another provider's cached results are not reused.

An arbitrary prayer API is not automatically compatible. The current adapter in `scripts/prayer_times.py` expects a JSON object with:

- `code: 200` and a `data` object.
- `data.timings` containing Fajr, Dhuhr, Asr, Maghrib and Isha times as `HH:MM` (optional parenthesized timezone suffix).
- `data.meta.timezone` containing an IANA timezone name.
- `data.date.gregorian.date` in `DD-MM-YYYY`.
- `data.date.hijri.day`, `.month.number`, and `.year`.

For a provider with another response or authentication format, update `PrayerService.fetch_day()` and `parse_day()` in `scripts/prayer_times.py`. Keep credentials in local environment/configuration rather than source files. Run the included tests after adapting the provider.

## Change distributable defaults

For a private installation you can set `prayerApiUrl`, `prayerCity`, `prayerCountry`, `prayerMethod` and `prayerHanafi` in both `defaults.json` and `Defaults.js`. Keep the JSON values and the JavaScript `values` object identical. Saved local settings override defaults, so changing these files will not overwrite an existing selection.

For public distribution, leave the API URL, city and country empty and let each person configure their installation. Keep location and audio paths out of commit messages and screenshots too.

## Troubleshooting

- “Set your prayer API URL and location”: one of the three required fields is empty.
- “Prayer times unavailable”: check HTTPS, the literal `{date}` placeholder, provider compatibility, network access and calculation settings.
- A saved timetable can continue working offline. Missing or invalid responses do not invent prayer times.
