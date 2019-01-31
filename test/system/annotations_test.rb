# coding: utf-8
require 'application_system_test_case'

class AnnotationsSystemTest < ApplicationSystemTestCase

  describe 'as an anonymous visitor' do
    scenario 'cannot annotate a resource', js: true do
      casebook = content_nodes(:public_casebook)
      resource = content_nodes(:public_casebook_section_1_2)

      visit resource_path casebook, resource
      assert_content resource.title

      select_text 'content to highlight'
      refute_selector('a[data-annotation-type=highlight]') # annotation menu does not pop up
    end
  end


  describe 'annotating a resource as a registered user' do
    let (:casebook) { content_nodes(:draft_casebook) }
    let (:resource) { content_nodes(:'draft_resource_2') }

    before do
      sign_in @user = users(:verified_professor)
      visit annotate_resource_path casebook, resource
    end

    scenario 'highlighting', js: true do
      text = 'content to highlight'
      select_text text

      assert_api :creates, 'Content::Annotation' do
        find('#create-highlight').click
      end

      sel = '.highlight .selected-text';
      assert_selector(sel)
      find(sel).assert_text text
    end

    scenario 'eliding', js: true do
      text = 'content to elide'
      select_text text

      assert_api :creates, 'Content::Annotation' do
        find('#create-elision').click
      end

      assert_no_content text
      assert_content "elided:\n✎\n;"
    end

    scenario 'replacement', js: true do
      text = 'content to replace'
      content = 'New Text'

      select_text text
      find('#create-replacement').click

      assert_api :creates, 'Content::Annotation' do
        find('.replacement-text').send_keys content, :enter
      end

      assert_content content
      assert_equal content, Content::Annotation.last.content
    end

    scenario 'adding a link', js: true do
      text = 'content to link'
      content = 'https://testlink.org'

      select_text text
      find('#create-link').click
      fill_in 'link-input', with: content

      assert_api :creates, 'Content::Annotation' do
        find('#link-input').send_keys :enter
      end

      has_link?(text, href: content)
    end

    scenario 'adding a note', js: true do
      text = 'content to note'
      content = 'Here is a new note'

      select_text text
      find('#create-note').click

      fill_in 'note-textarea', with: content

      assert_api :creates, 'Content::Annotation' do
        find('#save-note').click
      end

      find('.note-content', text: content) #acts as a assert_content for a span
      assert_selector('.note-content')
    end

    scenario 'deleting an annotation', js: true do
      text = 'content to highlight'
      select_text text

      assert_api :creates, 'Content::Annotation' do
        find('#create-highlight').click
      end

      sel = '.highlight .selected-text';
      assert_selector(sel)

      assert_api :deletes, 'Content::Annotation' do
        click_button '✎'
        find('.context-menu').click # click on Remove Note link
      end

      refute_selector(sel)
    end
  end
end
