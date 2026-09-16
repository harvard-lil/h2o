import pytest
from django.templatetags.static import static
from pathlib import Path

from django.conf import settings


@pytest.mark.parametrize(
    "url, asset",
    [
        ("/favicon.ico", "images/favicon.ico"),
        ("/apple-touch-icon.png", "images/h20-logo.png"),
        ("/apple-touch-icon-precomposed.png", "images/h20-logo.png"),
    ],
)
def test_browser_icon_urls(client, url, asset):
    response = client.get(url)
    assert response.status_code == 302
    assert response["Location"] == static(asset)
    assert (Path(settings.STATIC_ROOT) / asset).is_file()
