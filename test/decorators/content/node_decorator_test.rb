require 'application_system_test_case'

class Content::NodeDecoratorTest < ApplicationSystemTestCase
  describe 'action_buttons' do
    scenario 'renders casebook draft buttons' do
      casebook = content_nodes(:private_casebook)

      content = casebook.decorate(context: {action_name: 'layout', casebook: casebook})
      ## undefined method casebook_path
      ## node_decorator#28

      assert_content content.action_buttons
    end
  end
end
