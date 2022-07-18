from abc import ABC, abstractmethod
from datetime import date
from typing import Any, Iterable, Iterator, List, Optional, Tuple

from dateutil.relativedelta import relativedelta
from django.contrib.admin.views.main import ChangeList
from django.db import connection
from django.db.models import Count
from django.http import HttpRequest
from main.admin import CasebookAdmin, UserAdmin  # type: ignore # main/admin.py is entirely ignored
from main.models import Casebook
from reporting.create_reporting_views import ALL_STATES, OLDEST_YEAR, PUBLISHED_CASEBOOKS


def get_reporting_ids(query: str, params: List[Any]) -> Iterator[int]:
    with connection.cursor() as cursor:

        # Filter out any empty params that might be optional for this query
        params = [p for p in params if p]
        cursor.execute(query, params)
        ids = (_id[0] for _id in cursor.fetchall())
        return ids


def get_date_ranges(request: HttpRequest) -> Tuple[date, date]:

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

    def get_queryset(self, request: HttpRequest):

        start_date, end_date = get_date_ranges(request)
        state = self.get_state(request)
        qs = self.model.objects.filter(
            id__in=get_reporting_ids(self.sql, [state, start_date, end_date])
        ).annotate(casebook_count=Count("casebooks"))

        ordering = self.get_ordering(request, qs)
        return qs.order_by(*ordering)


class ProfessorAdmin(UserAdmin):
    """Override the default changelist method to return the customized change list class"""

    def get_changelist(self, request: HttpRequest):
        class ChangeList(AbstractProfessorChangeList):
            @property
            def sql(self):
                return """--sql
                select user_id from reporting_professors
                where created_at >= %s
                and created_at <= %s
                """

        return ChangeList


class ProfessorWithCasebooksAdmin(UserAdmin):
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
                and created_at >= %s
                and created_at <= %s
                """

        return ChangeList


class AbstractCasebookChangeList(AbstractReportingChangeList):
    """Return a Casebook changelist that respects the publication and creation date ranges
    requested by the usage dashboard user."""

    def get_queryset(self, request: HttpRequest):

        start_date, end_date = get_date_ranges(request)
        state = PUBLISHED_CASEBOOKS if request.GET.get("published") == "True" else ALL_STATES
        qs = self.model.objects.filter(
            id__in=get_reporting_ids(self.sql, [state, start_date, end_date])
        )

        ordering = self.get_ordering(request, qs)
        return qs.order_by(*ordering)


class AbstractCasebooksAdmin(CasebookAdmin):
    """Return a Casebook list where subclasses can specify the specific view to report from
    and whether to join from the professor view to restrict results to casebooks by professors."""

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
                and c.created_at >= %s
                and c.created_at <= %s

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
