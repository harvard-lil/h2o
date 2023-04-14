import csv
import dataclasses
from datetime import date
from io import StringIO

from dateutil.relativedelta import relativedelta
from dateutil.rrule import *
from django.contrib.admin.views.decorators import staff_member_required
from django.db import connection
from django.http import HttpRequest, HttpResponse, JsonResponse

from main.test.test_permissions_helpers import no_perms_test
from reporting.create_reporting_views import OLDEST_YEAR
from reporting.matomo import usage

from .admin.usage_dashboard import DateForm




@no_perms_test
@staff_member_required
def matomo_stats(request: HttpRequest):
    """When requested as on page load, retrieve Matomo analytics for the given time period"""
    form = DateForm(request.GET)
    if form.is_valid():
        web_usage = usage(
            form.cleaned_data["start_date"],
            form.cleaned_data["end_date"],
            form.cleaned_data["published"],
        )
        return JsonResponse(dataclasses.asdict(web_usage))
    return JsonResponse("")


@no_perms_test
@staff_member_required
def casebook_timeseries(request: HttpRequest):
    """Return the output of the casebook timeseries query, as a csv"""
    with connection.cursor() as cursor:
        # These do not respect date filters because they're cumulative over all time
        year_qs = []
        for year in rrule(
            YEARLY, until=date.today(), dtstart=date.today() - relativedelta(years=10)
        ):
            year_qs.append(
                f'case when created_year = {year.year} then num_casebooks else 0 end as "year_{year.year}"\n'
            )
        sql = f"""--sql
            select distinct user_id, attribution,
            {', '.join([yq for yq in year_qs])}
            from reporting_professors_with_casebooks_over_time
            """
        cursor.execute(sql)

        output = StringIO()
        export = []
        export.append([col.name.replace('_', ' ') for col in cursor.description])
        for row in cursor.fetchall():
            export.append(row)
        csv.writer(output).writerows(export)

        return HttpResponse(
            output.getvalue().encode(),
            headers={
                "Content-Type": "text/csv",
                "Content-Disposition": f'attachment; filename="{"casebooks-published-over-time"}-{date.today().isoformat()}.csv',
            },
        )