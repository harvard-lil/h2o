from main.admin import admin_site  # type: ignore  # main/admin.py is ignored
from reporting.models import (
    CasebookCAPProf,
    Professor,
    ProfessorWithCasebooks,
    CasebookProfessors,
    ReportingCasebook,
    CasebookCAP,
    CasebookGPO,
    CasebookGPOProf,
    CasebookCollaborators,
    CasebookCollaboratorsProf,
    CasebookSeries,
    CasebookSeriesProf,
)


from reporting.admin.views import (
    CasebookCAPProfAdmin,
    ProfessorAdmin,
    ProfessorWithCasebooksAdmin,
    CasebookProfessorsAdmin,
    ReportingCasebookAdmin,
    CasebookGPOAdmin,
    CasebookCAPAdmin,
    CasebookGPOProfAdmin,
    CasebookCollaboratorsAdmin,
    CasebookCollaboratorsProfAdmin,
    CasebookSeriesAdmin,
    CasebookSeriesProfAdmin,
)

admin_site.register(Professor, ProfessorAdmin)
admin_site.register(ProfessorWithCasebooks, ProfessorWithCasebooksAdmin)
admin_site.register(ReportingCasebook, ReportingCasebookAdmin)
admin_site.register(CasebookProfessors, CasebookProfessorsAdmin)
admin_site.register(CasebookCAP, CasebookCAPAdmin)
admin_site.register(CasebookGPO, CasebookGPOAdmin)
admin_site.register(CasebookCAPProf, CasebookCAPProfAdmin)
admin_site.register(CasebookGPOProf, CasebookGPOProfAdmin)
admin_site.register(CasebookCollaborators, CasebookCollaboratorsAdmin)
admin_site.register(CasebookCollaboratorsProf, CasebookCollaboratorsProfAdmin)
admin_site.register(CasebookSeries, CasebookSeriesAdmin)
admin_site.register(CasebookSeriesProf, CasebookSeriesProfAdmin)
