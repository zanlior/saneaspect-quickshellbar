import datetime as dt
import io
import json
import pathlib
import sys
import tempfile
import unittest
from unittest.mock import patch
from urllib.parse import parse_qs, urlsplit

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
from prayer_times import PrayerService, configuration


class PrayerConfigurationTests(unittest.TestCase):
    def settings(self):
        return dict(prayerCity='Example City', prayerCountry='Example Country',
                    prayerMethod=3, prayerHanafi=False,
                    prayerApiUrl='https://example.org/timings/{date}')

    def test_missing_api_or_location_does_not_send_request(self):
        for field in ('prayerApiUrl', 'prayerCity', 'prayerCountry'):
            settings = self.settings()
            settings[field] = ''
            with tempfile.TemporaryDirectory() as directory, patch('urllib.request.urlopen') as request:
                result = PrayerService(cache_dir=directory).get(settings)
                self.assertEqual(result['status'], 'unconfigured')
                request.assert_not_called()
                self.assertEqual(list(pathlib.Path(directory).iterdir()), [])

    def test_replaced_endpoint_encodes_location_and_preserves_query(self):
        settings = self.settings()
        settings['prayerCity'] = 'Example & City'
        settings['prayerApiUrl'] += '?format=json'
        with patch('urllib.request.urlopen', return_value=io.BytesIO(b'{"code":200}')) as request:
            result = PrayerService.fetch_day(dt.date(2026, 1, 2), configuration(settings))
        self.assertEqual(result, {'code': 200})
        url = request.call_args.args[0].full_url
        self.assertEqual(urlsplit(url).path, '/timings/02-01-2026')
        query = parse_qs(urlsplit(url).query)
        self.assertEqual(query['city'], ['Example & City'])
        self.assertEqual(query['country'], ['Example Country'])
        self.assertEqual(query['format'], ['json'])
        self.assertEqual(query['method'], ['3'])
        self.assertEqual(query['school'], ['0'])

    def test_invalid_endpoint_is_rejected_before_request(self):
        for endpoint in ('http://example.org/{date}', 'https://example.org/timings',
                         'https://user:secret@example.org/{date}',
                         'https://example.org/{date}#fragment'):
            settings = self.settings()
            settings['prayerApiUrl'] = endpoint
            with patch('urllib.request.urlopen') as request:
                with self.assertRaises(ValueError):
                    PrayerService.fetch_day(dt.date(2026, 1, 2), configuration(settings))
                request.assert_not_called()

    def test_changing_provider_changes_cache_configuration(self):
        settings = self.settings()
        first = configuration(settings)
        settings['prayerApiUrl'] = 'https://other.example.org/{date}'
        self.assertNotEqual(first, configuration(settings))

    def test_public_defaults_have_no_location_or_endpoint(self):
        settings = json.loads((ROOT / 'defaults.json').read_text())
        for key in ('prayerApiUrl', 'prayerCity', 'prayerCountry'):
            self.assertEqual(settings[key], '')


if __name__ == '__main__':
    unittest.main()
