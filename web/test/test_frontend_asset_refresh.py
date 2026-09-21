import json

from django.conf import settings
from django_vite.core.asset_loader import DjangoViteAssetLoader

from conftest import current_frontend_assets
import frontend_assets


def test_test_time_rebuild_refreshes_cached_asset_urls(tmp_path, monkeypatch):
    manifest = tmp_path / "manifest.json"
    entry = "frontend/pages/vue_app.js"

    def write_manifest(filename):
        manifest.write_text(json.dumps({entry: {"file": filename, "isEntry": True}}))

    write_manifest("assets/old.js")
    loader = DjangoViteAssetLoader.instance()
    try:
        with monkeypatch.context() as patch:
            patch.setattr(
                settings,
                "DJANGO_VITE",
                {
                    "default": {
                        **settings.DJANGO_VITE["default"],
                        "manifest_path": str(manifest),
                        "dev_mode": False,
                    }
                },
            )
            DjangoViteAssetLoader._apply_django_vite_settings()
            assert loader.generate_vite_asset_url(entry).endswith("assets/old.js")

            def rebuild():
                write_manifest("assets/new.js")
                return True

            patch.setattr(frontend_assets, "ensure_current", rebuild)
            current_frontend_assets.__wrapped__()
            assert loader.generate_vite_asset_url(entry).endswith("assets/new.js")
    finally:
        DjangoViteAssetLoader._apply_django_vite_settings()
