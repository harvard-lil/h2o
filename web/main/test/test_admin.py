from django.forms.models import inlineformset_factory
from main.models import Casebook, CommonTitle


def test_casebook_series_deletes_only_membership(
    common_title_factory,
    casebook_factory,
):
    """The Admin model formset used to remove casebooks from series should break the relationship
    but not actually delete the casebook itself"""

    from main.admin import CasebookInSeriesFormset

    # The Series relationship is both direct and indirect; the `current`
    # casebook is a direct foreign key, but other casebooks in the series,
    # including the `current` casebook itself, must be given the inbound
    # relationship independently, normally handled by the serializer.
    series = common_title_factory()

    casebook1_in_series = casebook_factory(common_title=series)
    casebook2_in_series = casebook_factory(common_title=series)

    assert 2 == Casebook.objects.exclude(common_title=None).count()

    FormSet = inlineformset_factory(
        CommonTitle, Casebook, formset=CasebookInSeriesFormset, fields=("id",)
    )

    data = {
        "casebooks-0-DELETE": "on",
        "casebooks-0-id": casebook1_in_series.id,
        "casebooks-0-common_title": series.id,
        "casebooks-1-id": casebook2_in_series.id,
        "casebooks-1-common_title": series.id,
        "casebooks-TOTAL_FORMS": 2,  # Fields required for formset validation
        "casebooks-INITIAL_FORMS": 2,
    }
    formset = FormSet(data, instance=series)
    assert formset.is_valid()
    formset.save()

    # We should have removed casebook 1
    assert 1 == Casebook.objects.exclude(common_title=None).count()

    # But it should still exist...
    removed_casebook = Casebook.objects.get(id=casebook1_in_series.id)

    # ...just not be in the series
    assert removed_casebook.common_title is None
