from __future__ import annotations

import json
import socket
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from unittest.mock import patch

from backend.vaccine_pipeline.adapters.live_source_adapter import LiveSourceAdapter


class _Handler(BaseHTTPRequestHandler):
    responses: dict[str, tuple[int, str, dict[str, str]]] = {}

    def do_GET(self):
        code, body, headers = self.responses.get(self.path, (404, "", {}))
        raw = body.encode("utf-8")
        self.send_response(code)
        for k, v in headers.items():
            self.send_header(k, v)
        self.send_header("Content-Type", "application/json" if self.path.endswith(".json") else "text/html")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def log_message(self, format, *args):
        return


class LiveSourceAdapterTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.fixture = Path(self.tmp.name) / "fixture.json"
        self.fixture.write_text(
            json.dumps(
                {
                    "version": "2026.01",
                    "schedule": [
                        {
                            "vaccine_code": "HepB",
                            "dose_no": 1,
                            "min_age_days": 0,
                            "max_age_days": 30,
                            "min_interval_days": 0,
                            "effective_from": "2026-01-01",
                            "effective_to": None,
                        }
                    ],
                }
            ),
            encoding="utf-8",
        )

        sock = socket.socket()
        sock.bind(("127.0.0.1", 0))
        _, port = sock.getsockname()
        sock.close()

        self.server = ThreadingHTTPServer(("127.0.0.1", port), _Handler)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.base = f"http://127.0.0.1:{port}"

    def tearDown(self) -> None:
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)
        self.tmp.cleanup()

    def test_uses_live_schedule_when_feed_available(self) -> None:
        _Handler.responses = {
            "/source": (
                200,
                "<html>Updated 2026-03-05</html>",
                {"Last-Modified": "Thu, 05 Mar 2026 12:00:00 GMT"},
            ),
            "/feed.json": (
                200,
                json.dumps(
                    {
                        "version": "2026.02",
                        "sourceUpdatedAt": "2026-03-05",
                        "schedule": [
                            {
                                "vaccine_code": "DTaP",
                                "dose_no": 1,
                                "min_age_days": 42,
                                "max_age_days": 120,
                                "min_interval_days": 28,
                                "effective_from": "2026-03-01",
                                "effective_to": None,
                            }
                        ],
                    }
                ),
                {},
            ),
        }

        adapter = LiveSourceAdapter(
            "US",
            "CDC",
            self.fixture,
            source_name="CDC",
            source_url=f"{self.base}/source",
            source_updated_at="",
            schedule_feed_url=f"{self.base}/feed.json",
        )
        snapshot = adapter.fetch_snapshot()

        self.assertEqual(snapshot.version, "2026.02")
        self.assertEqual(snapshot.payload["schedule"][0]["vaccine_code"], "DTaP")
        self.assertEqual(snapshot.source_updated_at, "2026-03-05")

    def test_falls_back_to_fixture_when_feed_missing(self) -> None:
        _Handler.responses = {
            "/source": (
                200,
                "<html><body>last updated 2026-02-10</body></html>",
                {},
            )
        }

        adapter = LiveSourceAdapter(
            "TR",
            "MOH",
            self.fixture,
            source_name="MOH",
            source_url=f"{self.base}/source",
            source_updated_at="2026-01-01",
            schedule_feed_url=f"{self.base}/missing.json",
        )
        snapshot = adapter.fetch_snapshot()

        self.assertEqual(snapshot.payload["schedule"][0]["vaccine_code"], "HepB")
        self.assertTrue(snapshot.version.startswith("2026."))
        self.assertEqual(snapshot.source_updated_at, "2026-02-10")

    def test_parses_json_records_path_with_field_map(self) -> None:
        _Handler.responses = {
            "/source": (200, "<html>Updated 2026-03-07</html>", {}),
            "/feed.json": (
                200,
                json.dumps(
                    {
                        "version": "2026.03",
                        "updatedAt": "2026-03-07",
                        "payload": {
                            "items": [
                                {
                                    "code": "PCV13",
                                    "dose": "2",
                                    "ageWindow": "4 months",
                                    "intervalDays": "28",
                                    "effectiveFrom": "2026-02-01",
                                }
                            ]
                        },
                    }
                ),
                {},
            ),
        }

        adapter = LiveSourceAdapter(
            "US",
            "CDC",
            self.fixture,
            source_name="CDC",
            source_url=f"{self.base}/source",
            source_updated_at="",
            schedule_feed_url=f"{self.base}/feed.json",
            schedule_feed_path="payload.items",
            schedule_field_map={
                "vaccine_code": "code",
                "dose_no": "dose",
                "age_text": "ageWindow",
                "min_interval_days": "intervalDays",
                "effective_from": "effectiveFrom",
            },
        )
        snapshot = adapter.fetch_snapshot()
        row = snapshot.payload["schedule"][0]

        self.assertEqual(snapshot.version, "2026.03")
        self.assertEqual(row["vaccine_code"], "PCV13")
        self.assertEqual(row["dose_no"], 2)
        self.assertEqual(row["min_age_days"], 120)
        self.assertEqual(row["min_interval_days"], 28)
        self.assertEqual(row["effective_from"], "2026-02-01")

    def test_parses_html_table_feed(self) -> None:
        _Handler.responses = {
            "/source": (200, "<html>Updated 2026-03-08</html>", {}),
            "/feed.html": (
                200,
                """
                <html><body>
                  <table>
                    <tr><th>Vaccine</th><th>Dose</th><th>Age</th></tr>
                    <tr><td>MMR</td><td>Dose 1</td><td>12 months</td></tr>
                  </table>
                </body></html>
                """,
                {},
            ),
        }

        adapter = LiveSourceAdapter(
            "GB",
            "NHS",
            self.fixture,
            source_name="NHS",
            source_url=f"{self.base}/source",
            source_updated_at="",
            schedule_feed_url=f"{self.base}/feed.html",
            schedule_feed_format="html",
        )
        snapshot = adapter.fetch_snapshot()

        self.assertEqual(snapshot.payload["schedule"][0]["vaccine_code"], "MMR")
        self.assertEqual(snapshot.payload["schedule"][0]["dose_no"], 1)
        self.assertEqual(snapshot.payload["schedule"][0]["min_age_days"], 360)

    def test_uses_fallback_feed_url_when_primary_unavailable(self) -> None:
        _Handler.responses = {
            "/source": (200, "<html>Updated 2026-03-08</html>", {}),
            "/fallback.html": (
                200,
                """
                <html><body>
                  <table>
                    <tr><th>Vaccine</th><th>Dose</th><th>Age</th></tr>
                    <tr><td>MMR</td><td>Dose 1</td><td>12 months</td></tr>
                  </table>
                </body></html>
                """,
                {},
            ),
        }

        adapter = LiveSourceAdapter(
            "GB",
            "NHS",
            self.fixture,
            source_name="NHS",
            source_url=f"{self.base}/source",
            source_updated_at="",
            schedule_feed_url=f"{self.base}/missing.html",
            schedule_feed_fallback_urls=[f"{self.base}/fallback.html"],
            schedule_feed_format="html",
        )
        snapshot = adapter.fetch_snapshot()

        self.assertEqual(snapshot.fetch_mode, "live")
        self.assertEqual(snapshot.payload["schedule"][0]["vaccine_code"], "MMR")

    def test_parses_turkey_pdf_text_signals(self) -> None:
        adapter = LiveSourceAdapter(
            "TR",
            "MOH",
            self.fixture,
            source_name="MOH",
            source_url=f"{self.base}/source",
            source_updated_at="2026-01-01",
        )

        schedule = adapter._parse_turkey_pdf_schedule(
            """
            Ulusal Çocukluk Dönemi Aşılama Takvimi
            Hep-B
            DaBT - İPA- Hib - HepB
            KKK
            DOĞUM 2. AY SONU 4. AY SONU 6. AY SONU 12. AY SONU
            """
        )

        self.assertEqual([row["vaccine_code"] for row in schedule], ["HB", "DTaP-IPV-Hib-HepB", "MMR"])

    def test_parses_germany_pdf_text_signals(self) -> None:
        adapter = LiveSourceAdapter(
            "DE",
            "RKI",
            self.fixture,
            source_name="RKI",
            source_url=f"{self.base}/source",
            source_updated_at="2026-01-01",
        )

        schedule = adapter._parse_germany_pdf_schedule(
            """
            Tabelle 1 | Impfkalender 2026
            Hepatitis Bc  G1  G2  G3f
            Pneumokokkenc,d  G1  G2  G3f
            Masern, Mumps, Röteln  G1  G2
            """
        )

        self.assertEqual([row["vaccine_code"] for row in schedule], ["6-fach", "Pneumokokken", "MMR"])

    def test_parses_spain_pdf_text_signals(self) -> None:
        adapter = LiveSourceAdapter(
            "ES",
            "Sanidad",
            self.fixture,
            source_name="Sanidad",
            source_url=f"{self.base}/source",
            source_updated_at="2026-01-01",
        )

        schedule = adapter._parse_spain_pdf_schedule(
            """
            Calendario común de vacunación
            0meses 2meses 4meses 6meses 11meses 12meses
            Vacunación a los 2, 4, 11 meses (DTPa/VPI/Hib/HB)
            Enfermedad neumocócica
            Sarampión, rubeola, parotiditis
            """
        )

        self.assertEqual([row["vaccine_code"] for row in schedule], ["Hexavalente", "Neumococo", "MMR"])

    def test_parses_italy_html_text_signals(self) -> None:
        adapter = LiveSourceAdapter(
            "IT",
            "ISS",
            self.fixture,
            source_name="ISS",
            source_url=f"{self.base}/source",
            source_updated_at="2026-01-01",
        )

        schedule = adapter._parse_italy_html_schedule(
            """
            Calendario vaccinale del Piano nazionale
            2 mesi compiuti
            quattro mesi
            10 mesi
            epatite B
            rotavirus
            morbillo
            """
        )

        self.assertEqual([row["vaccine_code"] for row in schedule], ["Hexavalente", "Rotavirus", "MMR"])

    def test_parses_saudi_pdf_text_signals(self) -> None:
        adapter = LiveSourceAdapter(
            "SA",
            "MOH",
            self.fixture,
            source_name="MOH",
            source_url=f"{self.base}/source",
            source_updated_at="2026-01-01",
        )

        schedule = adapter._parse_saudi_pdf_schedule(
            """
            Basic Vaccination Schedule
            At Birth Hepatitis B
            2 months IPV DTaP Hepatitis B Hib PCV Rota Virus
            4 months IPV DTaP Hepatitis B Hib PCV Rota Virus
            6 months IPV DTaP Hepatitis B Hib PCV OPV Rota Virus BCG
            months 9 Measles MCV4
            12 months OPV MMR PCV MCV4
            """
        )

        self.assertEqual(
            [row["vaccine_code"] for row in schedule],
            ["HepB", "BCG", "DTaP", "Hib", "PCV", "IPV", "RV", "Measles", "MMR", "MCV4"],
        )

    def test_parses_france_public_service_news_signals(self) -> None:
        adapter = LiveSourceAdapter(
            "FR",
            "Service Public",
            self.fixture,
            source_name="Service Public",
            source_url=f"{self.base}/source",
            source_updated_at="2026-01-01",
        )

        schedule = adapter._parse_france_service_public_news(
            """
            Nouvelles obligations vaccinales pour les nourrissons
            La vaccination contre les méningocoques ACWY comprend une dose à 6 mois suivie d'un rappel à 12 mois.
            Pour le méningocoque B, le schéma inclut des doses à 3, 5 et 12 mois.
            """
        )

        self.assertEqual([row["vaccine_code"] for row in schedule], ["MenACWY", "MenACWY", "MenB", "MenB", "MenB"])

    def test_builds_france_overlay_snapshot_when_public_sources_are_accessible(self) -> None:
        adapter = LiveSourceAdapter(
            "FR",
            "Service Public",
            self.fixture,
            source_name="Service Public",
            source_url="https://www.service-public.gouv.fr/particuliers/vosdroits/F724",
            source_updated_at="2026-01-01",
            schedule_feed_url="https://www.service-public.gouv.fr/particuliers/actualites/A16520",
            schedule_feed_format="html",
        )

        with patch.object(
            LiveSourceAdapter,
            "_fetch_page_metadata",
            side_effect=[
                ("Calendrier des vaccinations", "2025-05-28"),
                (
                    "Diphtérie Tétanos Poliomyélite 1re injection à 2 mois 2e injection à 4 mois À 11 mois",
                    "2025-05-28",
                ),
                (
                    "La vaccination contre les méningocoques ACWY comprend une dose à 6 mois suivie d'un rappel à 12 mois. "
                    "Pour le méningocoque B, le schéma inclut des doses à 3, 5 et 12 mois.",
                    "2025-05-05",
                ),
                ("Calendrier des vaccinations", "2025-05-28"),
            ],
        ):
            snapshot = adapter.fetch_snapshot()

        self.assertEqual(snapshot.fetch_mode, "live_overlay")
        self.assertEqual(snapshot.fallback_reason, "fixture_supplemented")
        self.assertGreaterEqual(len(snapshot.payload["schedule"]), 5)
        self.assertIn("MenACWY", [row["vaccine_code"] for row in snapshot.payload["schedule"]])
        self.assertEqual(snapshot.source_updated_at, "2025-05-28")

    def test_classifies_connection_reset_fetch_error(self) -> None:
        adapter = LiveSourceAdapter(
            "SA",
            "MOH",
            self.fixture,
            source_name="MOH",
            source_url=f"{self.base}/source",
            source_updated_at="2026-01-01",
        )

        classified = adapter._classify_fetch_error(OSError(54, "Connection reset by peer"))
        self.assertEqual(classified, "connection_reset")

    def test_prefers_newer_page_metadata_for_source_updated_at(self) -> None:
        _Handler.responses = {
            "/source": (
                200,
                "<html>Updated 2026-04-06</html>",
                {"Last-Modified": "Mon, 06 Apr 2026 12:00:00 GMT"},
            ),
            "/feed.json": (
                200,
                json.dumps(
                    {
                        "version": "2025",
                        "sourceUpdatedAt": "2025-04-02",
                        "schedule": [
                            {
                                "vaccine_code": "DTaP",
                                "dose_no": 1,
                                "min_age_days": 42,
                                "max_age_days": 120,
                                "min_interval_days": 28,
                                "effective_from": "2025-01-01",
                                "effective_to": None,
                            }
                        ],
                    }
                ),
                {},
            ),
        }

        adapter = LiveSourceAdapter(
            "TR",
            "MOH",
            self.fixture,
            source_name="MOH",
            source_url=f"{self.base}/source",
            source_updated_at="2026-01-01",
            schedule_feed_url=f"{self.base}/feed.json",
        )
        snapshot = adapter.fetch_snapshot()

        self.assertEqual(snapshot.version, "2025")
        self.assertEqual(snapshot.source_updated_at, "2026-04-06")


if __name__ == "__main__":
    unittest.main()
