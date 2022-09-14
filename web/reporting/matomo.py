# Connect to the Matomo instance associated with this H2O install and pull reports
import logging
import re
from dataclasses import dataclass, field
from datetime import date
from typing import Optional

import requests
from dateutil.relativedelta import relativedelta
from django.conf import settings
from requests import HTTPError
from requests import ConnectTimeout
from main.models import Casebook

from reporting.create_reporting_views import ALL_STATES, PUBLISHED_CASEBOOKS

logger = logging.getLogger(__name__)


@dataclass
class CasebookResult:
    slug: str
    visits: int
    instance: Optional[Casebook] = None


@dataclass
class UsageData:
    start_date: date
    end_date: date
    status: str
    items: list[CasebookResult] = field(default_factory=list)


def usage(
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    published_casebook_only=False,
) -> UsageData:
    if not all((settings.MATOMO_SITE_URL, settings.MATOMO_API_KEY, settings.MATOMO_SITE_ID)):
        raise NotImplementedError(
            "Both of MATOMO_SITE_URL and MATOMO_API_KEY must be set to retrieve analytics"
        )
    return api(
        settings.MATOMO_SITE_URL,
        settings.MATOMO_API_KEY,
        settings.MATOMO_SITE_ID,
        start_date,
        end_date,
        published_casebook_only,
    )


def api(
    api_url: str,
    api_key: str,
    id_site: str,
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    published_casebooks_only=False,
) -> UsageData:

    if not start_date:
        start_date = date.today() - relativedelta(months=1)
    if not end_date:
        end_date = date.today()

    # Cap the oldest part of the range to keep Matomo from running out of memory
    start_date = max(end_date - relativedelta(months=6), start_date)
    start_date_str = start_date.strftime("%Y-%m-%d")
    end_date_str = end_date.strftime("%Y-%m-%d")

    web_usage = UsageData(status="OK", start_date=start_date, end_date=end_date)

    params = {
        "module": "API",
        "idSite": id_site,
        "token_auth": api_key,
        "format": "JSON",
        "method": "Actions.getPageUrls",
        "period": "range",
        "date": f"{start_date_str},{end_date_str}",
        "expanded": "1",
        "filter_column": "label",
        "filter_pattern": "^casebooks$",
        "showColumns": "nb_visits",
    }

    try:
        resp = requests.get(api_url, params=params)
        resp.raise_for_status()
    except (HTTPError, ConnectTimeout) as exc:
        web_usage.status = "The Matomo API returned an error code; this will be logged"
        logger.error(exc)
        logger.error(params)
        return web_usage

    try:
        data = resp.json()
    except ValueError:
        web_usage.status = "The Matomo API did not return JSON as expected"
        logger.error(web_usage.status)
        logger.error(params)
        logger.error(resp.content)
        return web_usage

    if len(data) == 0:
        web_usage.status = "The Matomo API did not report any data for this period"
        logger.error(web_usage.status)
        logger.error(params)
        return web_usage

    if "message" in data:
        web_usage.status = data["message"]
        logger.error(web_usage.status)
        logger.error(params)
        logger.error(resp.content)
        return web_usage

    casebooks = [c for c in data[0]["subtable"]]

    for casebook in casebooks:
        cr = CasebookResult(slug=casebook["label"], visits=casebook["nb_visits"])
        web_usage.items.append(cr)
        try:
            casebook_id_part = re.findall(r"^\d+", cr.slug)
            if len(casebook_id_part) == 0:
                logger.warning(f"Could not parse slug {cr.slug} for integer value")
                continue
            casebook_id = int(casebook_id_part[0])

            instance = Casebook.objects.get(
                id=casebook_id,
                state__in=PUBLISHED_CASEBOOKS if published_casebooks_only else ALL_STATES,
            )
            cr.instance = instance
        except Casebook.DoesNotExist:
            logger.warning(f"Could not find casebook instance matching slug {cr.slug}")
            continue

    return web_usage
