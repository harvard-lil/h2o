import pytest
from django.urls import reverse

from main.models import ContentNode, TextBlock


def post_outline(client, casebook, data):
    return client.post(
        reverse("new_from_outline", args=[casebook]),
        data,
        content_type="application/json",
        as_user=casebook.testing_editor,
    )


@pytest.mark.parametrize(
    "payload",
    [
        {"data": []},
        {},
        [],
        {"data": "bad"},
        {"data": [None]},
        {"data": [{"title": None}]},
        {"data": [{"children": "bad"}]},
        {"data": [{"resource_type": "Clone"}]},
        {"data": [{"resource_type": "Clone", "casebookId": "invalid"}]},
        {"data": [{"resource_type": "Clone", "casebookId": True}]},
        {"data": [{"resource_type": "Link", "url": "not a link"}]},
        {"data": [{"resource_type": "bad"}]},
    ],
)
def test_invalid_outline(client, private_casebook, payload):
    response = post_outline(client, private_casebook, payload)
    assert response.status_code == 400
    assert response.json()["error"]
    assert not private_casebook.contents.exists()


def test_malformed_json(client, private_casebook):
    assert post_outline(client, private_casebook, "{bad").status_code == 400


@pytest.mark.parametrize("resource_type", ["TextBlock", "Section", "Temp"])
def test_parser_metadata_is_not_model_data(client, private_casebook, resource_type):
    response = post_outline(
        client,
        private_casebook,
        {
            "data": [
                {
                    "title": "Synthetic content",
                    "resource_type": resource_type,
                    "url": "https://example.com/",
                    "casebookId": "12",
                    "display_type": "Link",
                    "id": 123,
                    "resource_id": 123,
                }
            ]
        },
    )
    assert response.status_code == 200
    node = private_casebook.contents.get()
    assert node.resource_type == resource_type
    assert node.id != 123
    if resource_type == "TextBlock":
        assert node.resource.name == "Synthetic content"
    else:
        assert node.resource_id is None


def test_failed_outline_rolls_back_resources(client, private_casebook):
    count = TextBlock.objects.count()
    response = post_outline(
        client,
        private_casebook,
        {
            "data": [
                {"resource_type": "TextBlock", "title": "Synthetic text"},
                {"resource_type": "Clone"},
            ]
        },
    )
    assert response.status_code == 400
    assert TextBlock.objects.count() == count
    assert not private_casebook.contents.exists()


def test_target_section_must_belong_to_casebook(client, private_casebook, section):
    count = ContentNode.objects.count()
    response = post_outline(
        client,
        private_casebook,
        {
            "section": section.id,
            "data": [{"title": "Synthetic section"}],
        },
    )
    assert response.status_code == 404
    assert ContentNode.objects.count() == count


def test_clone_section(client, private_casebook, section):
    response = post_outline(
        client,
        private_casebook,
        {
            "data": [
                {
                    "resource_type": "Clone",
                    "casebookId": str(section.casebook_id),
                    "sectionId": str(section.id),
                    "url": "https://example.com/",
                }
            ]
        },
    )
    assert response.status_code == 200
    assert private_casebook.contents.filter(title=section.title).exists()


def test_clone_cannot_mix_source_ids(client, private_casebook, section):
    response = post_outline(
        client,
        private_casebook,
        {
            "data": [
                {
                    "resource_type": "Clone",
                    "casebookId": str(private_casebook.id),
                    "sectionId": str(section.id),
                }
            ]
        },
    )
    assert response.status_code == 404


def test_empty_reading_mode(client, private_casebook):
    response = client.get(
        reverse("printable_all", args=[private_casebook]), as_user=private_casebook.testing_editor
    )
    assert response.status_code == 404


@pytest.mark.parametrize("kind", [None, "", "Section"])
def test_add_to_existing_section(client, private_casebook, section_factory, kind):
    section = section_factory(casebook=private_casebook, resource_type=kind)
    response = post_outline(
        client,
        private_casebook,
        {
            "section": section.id,
            "data": [{"title": "Nested section"}],
        },
    )
    assert response.status_code == 200
    assert private_casebook.contents.get(title="Nested section").ordinals == [1, 1]


@pytest.mark.parametrize("node_source", [False, True])
def test_clone_forbidden_source_is_atomic(client, private_casebook, section, node_source):
    section.casebook.state = "Archived"
    section.casebook.save()
    data = {"resource_type": "Clone", "casebookId": str(section.casebook_id)}
    if node_source:
        data["sectionId"] = str(section.id)
    response = post_outline(
        client,
        private_casebook,
        {
            "data": [
                {"title": "Must roll back"},
                data,
            ]
        },
    )
    assert response.status_code == 403
    assert not private_casebook.contents.exists()


def test_clone_whole_book(client, private_casebook, section):
    response = post_outline(
        client,
        private_casebook,
        {
            "data": [
                {
                    "resource_type": "Clone",
                    "casebookId": str(section.casebook_id),
                    "url": "https://example.com/",
                    "display_type": "Clone",
                }
            ]
        },
    )
    assert response.status_code == 200
    assert private_casebook.contents.get(title=section.title).ordinals == [1, 1]


def test_clone_pretty_resource_url(client, private_casebook, section, common_title_factory):
    source = section.casebook
    user = source.testing_editor
    user.public_url = "synthetic-author"
    user.save()
    title = common_title_factory(current=source, public_url="synthetic-book")
    source.common_title = title
    source.save()
    response = post_outline(
        client,
        private_casebook,
        {
            "data": [
                {
                    "resource_type": "Clone",
                    "userSlug": user.public_url,
                    "titleSlug": title.public_url,
                    "ordSlug": "1-synthetic-section",
                }
            ]
        },
    )
    assert response.status_code == 200
    assert private_casebook.contents.get().title == section.title


def test_long_fetched_link_title(client, private_casebook, mocker):
    mocker.patch("main.views.get_link_title", return_value="x" * 20000)
    response = post_outline(
        client,
        private_casebook,
        {
            "data": [
                {
                    "resource_type": "Link",
                    "url": "https://example.com/",
                }
            ]
        },
    )
    assert response.status_code == 200
    node = private_casebook.contents.get()
    assert node.title == node.resource.name == "x" * 1024


@pytest.mark.parametrize("source_depth,target_depth", [(1, 2), (2, 1)])
def test_clone_preserves_descendant_positions(
    client, private_casebook, casebook, section_factory, source_depth, target_depth
):
    for depth in range(1, source_depth):
        section_factory(casebook=casebook, ordinals=[1] * depth)
    source = section_factory(casebook=casebook, ordinals=[1] * source_depth, title="Clone root")
    section_factory(casebook=casebook, ordinals=source.ordinals + [1], title="Clone child")
    data = [{"resource_type": "Clone", "casebookId": str(casebook.id), "sectionId": str(source.id)}]
    if target_depth == 2:
        data = [{"title": "Parent", "children": data}]
    response = post_outline(client, private_casebook, {"data": data})
    assert response.status_code == 200
    assert private_casebook.contents.get(title="Clone root").ordinals == [1] * target_depth
    assert private_casebook.contents.get(title="Clone child").ordinals == [1] * (target_depth + 1)
