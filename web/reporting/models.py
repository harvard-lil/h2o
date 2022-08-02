from datetime import date
from typing import Optional
from main.models import Casebook, User


class Professor(User):
    @property
    def most_recent_casebook(self) -> Optional[Casebook]:
        return self.casebooks.all().order_by("-created_at").first()

    @property
    def most_recent_casebook_title(self) -> str:
        if casebook := self.most_recent_casebook:
            return casebook.title
        return ""

    @property
    def most_recent_casebook_modified(self) -> str:
        if casebook := self.most_recent_casebook:
            return casebook.updated_at
        return ""

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
        verbose_name = "Casebooks in series"
        ordering = ("created_at",)


class CasebookSeriesProf(ReportingCasebook):
    class Meta:
        proxy = True
        verbose_name = "Casebooks in series by professors"
        ordering = ("created_at",)
