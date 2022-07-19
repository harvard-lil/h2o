from rest_framework import serializers
from django.urls import reverse
from rest_framework.exceptions import ValidationError
from main.models import Casebook, CommonTitle, User, ContentCollaborator
from main.utils import send_invitation_email, send_collaboration_email
from . import models


class AnnotationSerializer(serializers.ModelSerializer):
    start_offset = serializers.IntegerField(source="global_start_offset")
    end_offset = serializers.IntegerField(source="global_end_offset")

    class Meta:
        model = models.ContentAnnotation
        fields = (
            "id",
            "resource_id",
            "start_offset",
            "end_offset",
            "kind",
            "content",
            "created_at",
            "updated_at",
        )


class NewAnnotationSerializer(serializers.ModelSerializer):
    start_offset = serializers.IntegerField(source="global_start_offset")
    end_offset = serializers.IntegerField(source="global_end_offset")

    class Meta:
        model = models.ContentAnnotation
        fields = ("id", "start_offset", "end_offset", "kind", "content")


class UpdateAnnotationSerializer(serializers.ModelSerializer):
    class Meta:
        model = models.ContentAnnotation
        fields = ("id", "content")


class LegalDocumentSerializer(serializers.ModelSerializer):
    class Meta:
        model = models.LegalDocument
        fields = ("id", "content")


class TextBlockSerializer(serializers.ModelSerializer):
    class Meta:
        model = models.TextBlock
        fields = ("id", "content")


class RecursiveField(serializers.Serializer):
    def to_representation(self, value):
        serializer = self.parent.parent.__class__(value, context=self.context)
        return serializer.data


class ContentNodeSerializer(serializers.ModelSerializer):

    resource_type = serializers.SerializerMethodField()
    citation = serializers.SerializerMethodField()

    edit_url = serializers.URLField(source="get_preferred_url")
    url = serializers.URLField(source="get_absolute_url")

    decision_date = serializers.DateField(source="resource.decision_date", default=None)
    children = []
    is_transmutable = serializers.BooleanField()

    def get_resource_type(self, node):
        return node.doc_class

    def get_citation(self, node):
        if node.resource_type == "LegalDocument":
            return node.resource.cite_string
        return None

    class Meta:
        model = models.ContentNode
        fields = (
            "title",
            "id",
            "resource_type",
            "edit_url",
            "url",
            "citation",
            "decision_date",
            "is_transmutable",
            "ordinal_string",
            "ordinals",
        )


class SectionOutlineSerializer(serializers.ModelSerializer):
    resource_type = serializers.SerializerMethodField()
    edit_url = serializers.URLField(source="get_preferred_url")
    url = serializers.URLField(source="get_absolute_url")
    citation = serializers.SerializerMethodField()
    decision_date = serializers.DateField(source="resource.decision_date", default=None)
    children = RecursiveField(many=True, allow_null=True, default=[])
    is_transmutable = serializers.BooleanField()

    def get_resource_type(self, node):
        return node.doc_class

    def get_citation(self, node):
        if node.resource_type == "LegalDocument":
            return node.resource.cite_string
        return None

    class Meta:
        model = models.ContentNode
        fields = (
            "title",
            "id",
            "resource_type",
            "edit_url",
            "url",
            "citation",
            "decision_date",
            "children",
            "is_transmutable",
            "ordinal_string",
        )


class CasebookListSerializer(serializers.ModelSerializer):
    authors = serializers.SerializerMethodField()
    url = serializers.SerializerMethodField()
    settings_url = serializers.SerializerMethodField()
    edit_url = serializers.SerializerMethodField()
    id = serializers.IntegerField()
    draft_url = serializers.SerializerMethodField()
    user_editable = serializers.SerializerMethodField()

    def get_url(self, casebook):
        return casebook.get_absolute_url()

    def get_edit_url(self, casebook):
        return casebook.get_edit_url()

    def get_settings_url(self, casebook):
        return reverse("casebook_settings", args=[casebook])

    def get_draft_url(self, casebook):
        return casebook.draft and casebook.draft.get_edit_url()

    def get_user_editable(self, casebook):
        request = self.context.get("request")
        if request and hasattr(request, "user"):
            user = request.user
            return casebook.editable_by(user)
        return False

    def get_authors(self, casebook):
        def to_representation(collaborator):
            return {
                "can_edit": collaborator.can_edit,
                "has_attribution": collaborator.has_attribution,
                "attribution": collaborator.user.attribution,
                "public_url": collaborator.user.public_url,
                "verified_professor": collaborator.user.verified_professor,
                "titles": [
                    x.common_title.public_url
                    for x in collaborator.user.casebooks.all()
                    if x.common_title
                ],
            }

        return [to_representation(x) for x in casebook.contentcollaborator_set.order_by("id").all()]

    class Meta:
        model = models.Casebook
        fields = [
            "id",
            "title",
            "subtitle",
            "is_public",
            "is_archived",
            "has_draft",
            "authors",
            "url",
            "settings_url",
            "edit_url",
            "draft_url",
            "updated_at",
            "can_archive",
            "user_editable",
        ]


class CommonTitleSerializer(serializers.ModelSerializer):
    casebooks = CasebookListSerializer(many=True, default=[], source="public_casebooks")
    current = CasebookListSerializer()

    def update(self, instance, validated_data):
        casebook_ids = [c["id"] for c in validated_data.pop("public_casebooks")]
        new_casebooks = Casebook.objects.filter(id__in=casebook_ids).all()
        if len(new_casebooks) != len(casebook_ids):
            raise ValidationError
        old_casebooks = set(instance.casebooks.all())
        cbs_to_update = []
        for cb in new_casebooks:
            if cb not in old_casebooks:
                cb.common_title = instance
                cbs_to_update.append(cb)
            else:
                old_casebooks.remove(cb)
        for cb in old_casebooks:
            cb.common_title = None
            cbs_to_update.append(cb)

        Casebook.objects.bulk_update(cbs_to_update, ["common_title"])
        instance.name = validated_data.get("name", instance.name)
        instance.public_url = validated_data.get("public_url", instance.public_url)
        current_dict = validated_data.get("current", None)
        if current_dict:
            current = next((cb for cb in new_casebooks if cb.id == current_dict["id"]), None)
            if not current:
                raise ValidationError
            instance.current = current
        instance.save()
        return instance

    class Meta:
        model = models.CommonTitle
        fields = ["id", "name", "public_url", "current", "casebooks"]


class NewCommonTitleSerializer(serializers.ModelSerializer):
    casebooks = CasebookListSerializer(many=True)

    def create(self, validated_data):
        casebook_ids = [c["id"] for c in validated_data.pop("casebooks")]
        casebooks = Casebook.objects.filter(id__in=casebook_ids).all()
        if len(casebooks) != len(casebook_ids):
            raise ValidationError
        instance = CommonTitle(**validated_data)
        instance.save()
        for casebook in casebooks:
            casebook.common_title = instance
        Casebook.objects.bulk_update(casebooks, ["common_title"])
        return instance

    class Meta:
        model = models.CommonTitle
        fields = ["name", "public_url", "current", "casebooks"]


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = models.User
        fields = ["email_address", "attribution", "affiliation", "id"]


class CollaboratorSerializer(serializers.ModelSerializer):
    user = UserSerializer()

    class Meta:
        model = models.ContentCollaborator
        fields = ["casebook", "has_attribution", "can_edit", "user", "id"]


class PotentialUser(serializers.BaseSerializer):
    email_address = serializers.EmailField(required=False)
    id = serializers.IntegerField(required=False)
    attribution = serializers.CharField(required=False)
    affiliation = serializers.CharField(required=False)

    def to_internal_value(self, data):
        id = data.get("id", None)
        email_address = data.get("email_address", None)
        if not id:
            if not email_address:
                raise serializers.ValidationError(
                    {"email_address": "Either an id or email address is required."}
                )
            user = User.objects.filter(email_address=email_address).first()
            if user:
                self.instance = user
        else:
            user = User.objects.filter(id=id).first()
            if not user:
                raise serializers.ValidationError({"id": "User with this id does not exist."})
            self.instance = user
        return {"id": id, "email_address": email_address}

    def create(self, validated_data):
        # No user present in system with given email address
        # Send out an invite
        return User.objects.create(**validated_data)

    def update(self, instance, validated_data):
        raise NotImplementedError


class CollaboratorDeserializer(serializers.BaseSerializer):
    casebook = serializers.IntegerField()
    has_attribution = serializers.BooleanField()
    can_edit = serializers.BooleanField()
    id = serializers.IntegerField(required=False)
    user = PotentialUser()

    def to_internal_value(self, data):
        instance = None
        casebook_id = data.get("casebook", None)
        if not casebook_id:
            raise serializers.ValidationError({"casebook": "This field is required."})
        casebook = Casebook.objects.filter(id=casebook_id).first()
        if not casebook:
            raise serializers.ValidationError({"casebook": "Casebook with given id not found."})
        has_attribution = data.get("has_attribution", False)
        can_edit = data.get("can_edit", False)
        id = data.get("id", None)
        if id:
            collaborator = ContentCollaborator.objects.filter(id=id).first()
            if not collaborator:
                raise serializers.ValidationError(
                    {"id": "Collaborator with this id does not exist."}
                )
            instance = collaborator
        user = data.get("user", None)
        if not user:
            raise serializers.ValidationError({"user": "This field is required."})
        deserialized_user = PotentialUser(data=user, context=self.context)
        deserialized_user.is_valid()
        return {
            "casebook": casebook,
            "has_attribution": has_attribution,
            "can_edit": can_edit,
            "user": deserialized_user,
            "instance": instance,
        }

    def create(self, validated_data):
        instance = validated_data.pop("instance", None)
        if instance:
            instance.has_attribution = validated_data.get("has_attribution")
            instance.can_edit = validated_data.get("can_edit")
            return instance.save()
        existing_user = validated_data.get("user").instance
        if existing_user:
            send_collaboration_email(
                self.context["request"], existing_user, validated_data.get("casebook")
            )
        else:
            existing_user = validated_data.get("user").save()
            send_invitation_email(
                self.context["request"], existing_user, validated_data.get("casebook")
            )
        data = {**validated_data}
        data["user"] = existing_user
        results = ContentCollaborator.objects.create(**data)
        return results

    def update(self, instance, validated_data):
        raise NotImplementedError


class LegalDocumentSourceSerializer(serializers.ModelSerializer):
    short_description = serializers.SerializerMethodField()
    long_description = serializers.SerializerMethodField()
    search_regexes = serializers.SerializerMethodField()

    def get_short_description(self, source):
        return source.api_model().details["short_description"]

    def get_long_description(self, source):
        return source.api_model().details["long_description"]

    def get_search_regexes(self, source):
        return source.api_model().details["search_regexes"]

    class Meta:
        model = models.LegalDocumentSource
        fields = ("id", "name", "short_description", "long_description", "search_regexes")


class LegalDocumentSearchParams:
    def __init__(
        self,
        q=None,
        name=None,
        before_date=None,
        after_date=None,
        jurisdiction=None,
        citation=None,
        frontend_url=None,
    ):
        self.q = q
        self.name = name
        self.before_date = before_date
        self.after_date = after_date
        self.jurisdiction = jurisdiction
        self.citation = citation
        self.frontend_url = frontend_url


class LegalDocumentSearchParamsSerializer(serializers.Serializer):
    q = serializers.CharField(max_length=1000, required=False)
    name = serializers.CharField(max_length=1000, required=False)
    before_date = serializers.DateField(required=False)
    after_date = serializers.DateField(required=False)
    jurisdiction = serializers.CharField(max_length=100, required=False)
    citation = serializers.CharField(max_length=100, required=False)
    frontend_url = serializers.URLField(required=False)

    def create(self, validated_data):
        return LegalDocumentSearchParams(**validated_data)


class CasebookInfoSerializer(serializers.ModelSerializer):
    id = serializers.IntegerField()
    title = serializers.CharField()
    subtitle = serializers.CharField()
    headnote = serializers.CharField()
    authors = serializers.SerializerMethodField()
    created_at = serializers.DateTimeField()
    updated_at = serializers.DateTimeField()

    class Meta:
        model = models.Casebook
        fields = ("id", "title", "subtitle", "headnote", "authors", "created_at", "updated_at")

    def get_authors(self, source):
        return [author.display_name for author in source.primary_authors]
