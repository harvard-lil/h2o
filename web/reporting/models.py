from main.models import Casebook, User


class Professor(User):
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
