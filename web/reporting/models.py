from datetime import date, datetime
from typing import Optional

from main.models import Casebook, User, ContentNode

# Proxy models for generating changelist pages in the reporting admin. While these superficially match
# the reporting views, they are Django mdoels based on the real models in main and so
# have all the same fields as their `main` equivalents, rather than the columns synthesized
# in the reporting views.


class Professor(User):
    @property
    def most_recently_created_casebook(self) -> Optional[Casebook]:
        return self.casebooks.all().order_by("-created_at").first()

    @property
    def most_recently_created_casebook_title(self) -> str:
        if casebook := self.most_recently_created_casebook:
            return f"{casebook.title} ({casebook.id})"
        return ""

    @property
    def most_recently_created_casebook_creation_date(self) -> Optional[str]:
        if casebook := self.most_recently_created_casebook:
            return casebook.created_at.strftime("%Y-%m-%d")
        return None

    @property
    def most_recently_modified_casebook(self) -> tuple[Optional[Casebook], datetime]:
        most_recent_casebook: Optional[Casebook] = None
        most_recent_modification_date = datetime(1900, 1, 1)
        for casebook in self.casebooks.all():
            try:
                most_recent_node = casebook.contents.filter(updated_at__isnull=False).latest(
                    "updated_at"
                )
                if most_recent_node.updated_at > most_recent_modification_date:
                    most_recent_casebook = most_recent_node.casebook
                    most_recent_modification_date = most_recent_node.updated_at
            except ContentNode.DoesNotExist:
                pass
        # Compare against the modification date of the casebook itself too; it may be newer than its contents
        try:
            most_recently_modified_casebook_obj: Casebook = self.casebooks.latest("updated_at")
            if most_recently_modified_casebook_obj.updated_at > most_recent_modification_date:
                most_recent_modification_date = most_recently_modified_casebook_obj.updated_at
                most_recent_casebook = most_recently_modified_casebook_obj
        except Casebook.DoesNotExist:
            pass
        return most_recent_casebook, most_recent_modification_date

    @property
    def most_recently_modified_casebook_title(self) -> str:
        if self.most_recently_modified_casebook[0]:
            if casebook := self.most_recently_modified_casebook[0]:
                return f"{casebook.title} ({casebook.id})"
        return ""

    @property
    def most_recently_modified_casebook_modification_date(self) -> Optional[str]:
        if self.most_recently_modified_casebook[0]:
            if date := self.most_recently_modified_casebook[1]:
                return date.strftime("%Y-%m-%d")
        return None

    class Meta:
        proxy = True
        verbose_name = "Professor"
        ordering = ("created_at",)


class ProfessorWithCasebooks(Professor):
    class Meta:
        proxy = True
        verbose_name = "Professors with casebook"
        ordering = ("created_at",)


class ReportingCasebook(Casebook):
    @property
    def authors_display(self) -> str:
        return ", ".join([a.attribution for a in self.attributed_authors])

    @property
    def most_recent_history(self) -> Optional[date]:
        if edit_log := self.edit_log.order_by("-entry_date").first():
            return edit_log.entry_date
        return None

    class Meta:
        proxy = True
        verbose_name = "Casebook"
        ordering = ("created_at",)


class CasebookProfessors(ReportingCasebook):
    class Meta:
        proxy = True
        verbose_name = "Casebooks from professor"
        ordering = ("created_at",)


class CasebookCAP(ReportingCasebook):
    class Meta:
        proxy = True
        verbose_name = "Casebooks with CAP content"
        ordering = ("created_at",)


class CasebookGPO(ReportingCasebook):
    class Meta:
        proxy = True
        verbose_name = "Casebooks with GPO content"
        ordering = ("created_at",)


class CasebookCollaborators(ReportingCasebook):
    class Meta:
        proxy = True
        verbose_name = "Casebooks with any collaborator"
        ordering = ("created_at",)


class CasebookCollaboratorsProf(ReportingCasebook):
    class Meta:
        proxy = True
        verbose_name = "Casebooks with professors as collaborator"
        ordering = ("created_at",)


class CasebookCAPProf(ReportingCasebook):
    class Meta:
        proxy = True
        verbose_name = "Casebooks with CAP content byprofessor"
        ordering = ("created_at",)


class CasebookGPOProf(ReportingCasebook):
    class Meta:
        proxy = True
        verbose_name = "Casebooks with GPO content by professor"
        ordering = ("created_at",)


class CasebookSeries(ReportingCasebook):
    class Meta:
        proxy = True
        verbose_name_plural = "Casebooks in series"
        ordering = ("created_at",)


class CasebookSeriesProf(ReportingCasebook):
    class Meta:
        proxy = True
        verbose_name_plural = "Casebooks in series by professors"
        ordering = ("created_at",)
