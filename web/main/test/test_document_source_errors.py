from django.urls import reverse


def test_document_source_failure(client, user, legal_doc_source, mocker):
    from main.utils import APICommunicationError

    mocker.patch.object(
        legal_doc_source.api_model(),
        "search",
        side_effect=APICommunicationError("upstream failure"),
    )
    response = client.get(
        reverse("search_using", args=[legal_doc_source.id]), {"q": "Synthetic"}, as_user=user
    )
    assert response.status_code == 502
    assert response.json()["error"]
