# Generated by Django 3.2.14 on 2022-08-08 14:40

from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ('reporting', '0001_add_reporting_proxy_models'),
    ]

    operations = [
        migrations.AlterModelOptions(
            name='casebookseries',
            options={'ordering': ('created_at',), 'verbose_name_plural': 'Casebooks in series'},
        ),
        migrations.AlterModelOptions(
            name='casebookseriesprof',
            options={'ordering': ('created_at',), 'verbose_name_plural': 'Casebooks in series by professors'},
        ),
    ]
