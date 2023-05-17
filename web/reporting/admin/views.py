import csv
from abc import ABC, abstractmethod
from datetime import date
from io import StringIO
from typing import Any, Iterable, Optional, Union

from dateutil.relativedelta import relativedelta
from django.contrib.admin.views.main import ChangeList
from django.db import connection
from django.db.models import Count
from django.db.models.query import QuerySet
from django.http import HttpRequest, HttpResponse
from main.admin import BaseAdmin, CasebookAdmin, UserAdmin  # type: ignore # main/admin.py is entirely ignored
from main.models import Casebook
from reporting.create_reporting_views import ALL_STATES, OLDEST_YEAR, PUBLISHED_CASEBOOKS

MAX_CSV_RESULTS = 1_000


def get_reporting_ids(query: str, params: list[Any]) -> Iterable[int]:
    with connection.cursor() as cursor:

        # Filter out any empty params that might be optional for this query
        params = [p for p in params if p]
        cursor.execute(query, params)
        ids = (_id[0] for _id in cursor.fetchall())
        return ids


def get_date_ranges(request: HttpRequest) -> tuple[Union[str, date], Union[str, date]]:

    start_date = request.GET.get("start_date", date.today() - relativedelta(years=OLDEST_YEAR))
    end_date = request.GET.get("end_date", date.today())
    return start_date, end_date


class AbstractReportingChangeList(ABC, ChangeList):
    """Return a change list view that expects a subclass to implement SQL that will return a list of primary
    keys to be materialized into the underlying Proxy model."""

    @property
    @abstractmethod
    def sql(self):
        """Subclasses should implement the SQL that applies to their particular reporting table"""
        pass


class AbstractProfessorChangeList(AbstractReportingChangeList):
    """Implement materializing a User-derived queryset that is filtered on the custom dashboard fields
    and has expected annotations for the parent queryset, here the count of casebooks by this author."""

    def get_state(self, request: HttpRequest) -> Optional[Iterable[str]]:
        return None

    def get_queryset(self, request: HttpRequest) -> QuerySet:

        start_date, end_date = get_date_ranges(request)
        state = self.get_state(request)
        qs = self.model.objects.filter(
            id__in=get_reporting_ids(self.sql, [state, start_date, end_date])
        ).annotate(casebook_count=Count("casebooks"))

        ordering = self.get_ordering(request, qs)
        return qs.order_by(*ordering)


class CsvResponseMixin(BaseAdmin):
    @property
    def field_list(self) -> Iterable[str]:
        """Return a list of fields to be included in the CSV output for this class"""
        return []

    def changelist_view(self, request: HttpRequest, extra_context=None) -> HttpResponse:
        if "_csv" in request.GET:
            qs: QuerySet = self.get_changelist_instance(request).queryset[:MAX_CSV_RESULTS]

            output = StringIO()
            export = [[f for f in self.field_list]]
            for obj in qs:
                row: list[str] = [str(getattr(obj, field)) for field in self.field_list]
                export.append(row)
            csv.writer(output).writerows(export)
            return self.csv_response(output)

        return super().changelist_view(request, extra_context)

    def csv_response(self, output_rows: StringIO) -> HttpResponse:
        """Return a response object of type CSV given a datastructure of rows of string output"""
        return HttpResponse(
            output_rows.getvalue().encode(),
            headers={
                "Content-Type": "text/csv",
                "Content-Disposition": f'attachment; filename="{self.model._meta.model_name}-{date.today().isoformat()}.csv',
            },
        )


class ProfessorExportMixin(CsvResponseMixin):
    @property
    def field_list(self) -> Iterable[str]:
        return (
            "id",
            "attribution",
            "email_address",
            "affiliation",
            "most_recently_created_casebook_title",
            "most_recently_created_casebook_creation_date",
            "most_recently_modified_casebook_title",
            "most_recently_modified_casebook_modification_date",
            "last_login_at",
        )


class CasebookExportMixin(CsvResponseMixin):
    @property
    def field_list(self) -> Iterable[str]:
        return ("id", "title", "authors_display", "state", "created_at", "most_recent_history")


class ProfessorAdmin(ProfessorExportMixin, UserAdmin):
    """Override the default changelist method to return the customized change list class"""

    def get_changelist(self, request: HttpRequest):
        class ChangeList(AbstractProfessorChangeList):
            @property
            def sql(self):
                return """--sql
                select user_id from reporting_professors
                where date(last_login_at) >= %s
                and date(last_login_at) <= %s
                """

        return ChangeList


class ProfessorWithCasebooksAdmin(ProfessorExportMixin, UserAdmin):
    """Return a User/Professor changelist that respects the publication status of casebooks
    by this author"""

    def get_changelist(self, request: HttpRequest):
        class ChangeList(AbstractProfessorChangeList):
            def get_state(self, request: HttpRequest):
                return (
                    (Casebook.LifeCycle.PUBLISHED.value,)
                    if request.GET.get("published") == "True"
                    else ALL_STATES
                )

            @property
            def sql(self):
                return """--sql
                select user_id from reporting_professors_with_casebooks
                where state in %s
                and date(last_login_at) >= %s
                and date(last_login_at) <= %s
                """

        return ChangeList


class AbstractCasebookChangeList(AbstractReportingChangeList):
    """Return a Casebook changelist that respects the publication and usage date ranges
    requested by the usage dashboard user."""

    def get_queryset(self, request: HttpRequest):

        start_date, end_date = get_date_ranges(request)
        state = PUBLISHED_CASEBOOKS if request.GET.get("published") == "True" else ALL_STATES
        qs = self.model.objects.filter(
            id__in=get_reporting_ids(self.sql, [state, start_date, end_date])
        )

        ordering = self.get_ordering(request, qs)
        return qs.order_by(*ordering)


class AbstractCasebooksAdmin(CasebookExportMixin, CasebookAdmin):
    """Return a Casebook list where subclasses can specify the database view to select from,
    and indicate whether to join on the professor view to restrict results to casebooks by professors."""

    @property
    @abstractmethod
    def table_name(self) -> str:
        pass

    @property
    def join_on_professor(self) -> bool:
        return False

    def get_changelist(self, request: HttpRequest):
        parent = self

        class ChangeList(AbstractCasebookChangeList):
            @property
            def sql(self):
                return f"""--sql
                select c.casebook_id from {parent.table_name} as c
                {"inner join reporting_casebooks_from_professors rp on rp.casebook_id = c.casebook_id"
                    if parent.join_on_professor
                    else ""}
                where c.state in %s
                and date(c.updated_at) >= %s
                and date(c.updated_at) <= %s

                """

        return ChangeList


class ReportingCasebookAdmin(AbstractCasebooksAdmin):
    @property
    def table_name(self):
        return "reporting_casebooks"


class CasebookProfessorsAdmin(AbstractCasebooksAdmin):
    @property
    def table_name(self):
        return "reporting_casebooks_from_professors"


class CasebookCAPAdmin(AbstractCasebooksAdmin):
    @property
    def table_name(self):
        return "reporting_casebooks_including_source_cap"


class CasebookGPOAdmin(AbstractCasebooksAdmin):
    @property
    def table_name(self):
        return "reporting_casebooks_including_source_gpo"


class CasebookCollaboratorsAdmin(AbstractCasebooksAdmin):
    def has_module_permission(self, request: HttpRequest):
        return False

    @property
    def table_name(self):
        return "reporting_casebooks_with_multiple_collaborators"


class CasebookGPOProfAdmin(AbstractCasebooksAdmin):
    def has_module_permission(self, request: HttpRequest):
        return False

    @property
    def join_on_professor(self) -> bool:
        return True

    @property
    def table_name(self) -> str:
        return "reporting_casebooks_including_source_gpo"


class CasebookCAPProfAdmin(AbstractCasebooksAdmin):
    def has_module_permission(self, request: HttpRequest):
        return False

    @property
    def join_on_professor(self) -> bool:
        return True

    @property
    def table_name(self) -> str:
        return "reporting_casebooks_including_source_cap"


class CasebookCollaboratorsProfAdmin(AbstractCasebooksAdmin):
    @property
    def join_on_professor(self) -> bool:
        return True

    @property
    def table_name(self) -> str:
        return "reporting_casebooks_with_multiple_collaborators"


class CasebookSeriesAdmin(AbstractCasebooksAdmin):
    @property
    def table_name(self):
        return "reporting_casebooks_series"


class CasebookSeriesProfAdmin(AbstractCasebooksAdmin):
    @property
    def table_name(self):
        return "reporting_casebooks_series_from_professors"
