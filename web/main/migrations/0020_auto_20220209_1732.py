# Generated by Django 2.2.27 on 2022-02-09 17:32

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('main', '0019_livesettings'),
    ]

    operations = [
        migrations.AddField(
            model_name='livesettings',
            name='export_average_rate',
            field=models.IntegerField(default=0),
        ),
        migrations.AddField(
            model_name='livesettings',
            name='export_last_minute_updated',
            field=models.IntegerField(default=0),
        ),
    ]
