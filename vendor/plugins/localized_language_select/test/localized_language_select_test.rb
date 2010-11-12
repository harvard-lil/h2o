# -*- coding: utf-8 -*-
require 'test/unit'

require 'rubygems'
require 'active_support'
require 'action_controller'
require 'action_controller/test_process'
require 'action_view'
require 'action_view/helpers'
require 'action_view/helpers/tag_helper'
require 'i18n'

require 'localized_language_select'

class LocalizedLanguageSelectTest < Test::Unit::TestCase

  include ActionView::Helpers::FormOptionsHelper
  include ActionView::Helpers::TagHelper

  def test_action_view_should_include_helper_for_object
    assert ActionView::Helpers::FormBuilder.instance_methods.include?('localized_language_select')
    assert ActionView::Helpers::FormOptionsHelper.instance_methods.include?('localized_language_select')
  end

  def test_action_view_should_include_helper_tag
    assert ActionView::Helpers::FormOptionsHelper.instance_methods.include?('localized_language_select_tag')
  end

  def test_should_return_select_tag_with_proper_name_for_object
    assert localized_language_select(:user, :language) =~
              Regexp.new(Regexp.escape('<select id="user_language" name="user[language]">')),
              "Should have proper name for object"
  end

  def test_should_return_select_tag_with_proper_name
    assert localized_language_select_tag( "competition_submission[data][language]", nil) =~
              Regexp.new(
              Regexp.escape('<select id="competition_submission[data][language]" name="competition_submission[data][language]">') ),
              "Should have proper name"
  end

  def test_should_return_option_tags
    assert localized_language_select(:user, :language) =~ Regexp.new(Regexp.escape('<option value="es">Spanish</option>'))
  end

  def test_should_return_localized_option_tags
    I18n.locale = 'fr'
    assert localized_language_select(:user, :language) =~ Regexp.new(Regexp.escape('<option value="es">espagnol</option>'))
  end

  def test_should_return_localized_country_option_tags
    I18n.locale = 'fr'
    assert localized_language_select(:user, :language) =~ Regexp.new(Regexp.escape('<option value="es-ES">espagnol ibérique</option>'))
  end

  def test_should_return_priority_languages_first
    assert localized_language_options_for_select(nil, [:es, :fr]) =~ Regexp.new(
      Regexp.escape("<option value=\"es\">Spanish</option>\n<option value=\"fr\">French</option><option value=\"\" disabled=\"disabled\">-------------</option>\n<option value=\"ab\">Abkhazian</option>\n"))
  end

  def test_i18n_should_know_about_languages
    assert_equal 'Spanish', I18n.t('es', :scope => 'languages')
    I18n.locale = 'fr'
    assert_equal 'espagnol', I18n.t('es', :scope => 'languages')
  end

  def test_localized_languages_array_returns_correctly
    assert_nothing_raised { LocalizedLanguageSelect::localized_languages_array() }
    I18n.locale = 'en'
    assert_equal 504, LocalizedLanguageSelect::localized_languages_array.size
    assert_equal 'Abkhazian', LocalizedLanguageSelect::localized_languages_array.first[0]
    I18n.locale = 'fr'
    assert_equal 503, LocalizedLanguageSelect::localized_languages_array.size
    assert_equal 'abkhaze', LocalizedLanguageSelect::localized_languages_array.first[0]
  end

  def test_priority_languages_returns_correctly_and_in_correct_order
    assert_nothing_raised { LocalizedLanguageSelect::priority_languages_array([:nl, :fr]) }
    I18n.locale = 'en'
    assert_equal [ ['Dutch', 'nl'], ['French', 'fr'] ], LocalizedLanguageSelect::priority_languages_array([:nl, :fr])
  end

  private

  def setup
    ['fr', 'en'].each do |locale|
      # I18n.load_translations( File.join(File.dirname(__FILE__), '..', 'locale', "#{locale}.rb")  )  # <-- Old style! :)
      I18n.load_path += Dir[ File.join(File.dirname(__FILE__), '..', 'locale', "#{locale}.rb") ]
    end
    I18n.locale = 'en'
  end

end
