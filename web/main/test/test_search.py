from cgitb import reset
from django.urls import reverse
from test.test_helpers import check_response

from main.models import ContentNode, FullTextSearchIndex, TextBlock


def test_search_inside_default(full_casebook, client):
    """Search inside should match legal documents by default"""
    legal_documents = ContentNode.objects.filter(
        casebook=full_casebook, resource_type="LegalDocument"
    )
    FullTextSearchIndex().create_search_index()
    url = reverse("casebook_search", kwargs={"casebook_param": full_casebook})

    titles = [d.title for d in legal_documents]
    assert len(titles) > 0
    check_response(client.get(url), content_includes=titles)
    check_response(client.get(url, kwargs={"type": "legal_doc_fulltext"}), content_includes=titles)


def test_search_inside_text_passages(full_casebook, client):
    """Search inside should match text passages in the correct tab"""
    text_blocks = TextBlock.objects.filter(
        id__in=ContentNode.objects.filter(
            casebook=full_casebook, resource_type="TextBlock"
        ).values_list("resource_id", flat=True)
    )
    text_blocks[0].content = "Unique content"
    text_blocks[0].save()

    FullTextSearchIndex().create_search_index()
    url = reverse("casebook_search", kwargs={"casebook_param": full_casebook})

    titles = [d.name for d in text_blocks]
    assert len(titles) > 0

    # Search for all text blocks
    search_result = client.get(url, {"type": "textblock", "q": ""})
    assert len(titles) == len(search_result.context["results"])
    check_response(search_result, content_includes=titles)

    # Search for a specific text block
    search_result = client.get(url, {"type": "textblock", "q": text_blocks[0].content})
    assert 1 == len(search_result.context["results"])
    assert text_blocks[0].name in [r.metadata["name"] for r in search_result.context["results"]]
