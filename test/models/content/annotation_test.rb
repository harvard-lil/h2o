require 'test_helper'

class Content::AnnotationTest < ActiveSupport::TestCase
  test 'appends protocol to content url' do
    url = 'example.com'
    annotation = Content::Annotation.new(kind: 'link', content: url)
    assert_equal "http://#{url}/", annotation.content
  end
  
  test 'invalid without content' do
    Content::Annotation::KINDS_WITH_CONTENT.each do |kind|
      annotation = Content::Annotation.new(kind: kind)
      refute annotation.valid?, 'annotation is valid without a name'
      assert_not_nil annotation.errors[:content], 'no validation error for content present'
    end
  end
end
