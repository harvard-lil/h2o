# Generated by Django 2.2.10 on 2020-03-16 17:27

from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('main', '0046_auto_20200312_2042'),
    ]

    operations = [
        migrations.AlterField(
            model_name='casebook',
            name='old_casebook',
            field=models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.DO_NOTHING, related_name='replacement_casebook', to='main.ContentNode'),
        ),
    ]
