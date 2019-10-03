from django.apps import AppConfig
from django.contrib.admin.apps import AdminConfig


class MainConfig(AppConfig):
    name = 'main'

class CustomAdminConfig(AdminConfig):
    default_site = 'main.admin.CustomAdminSite'
