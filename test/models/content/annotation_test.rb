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

  test 'converts global offsets to paragraph based offsets when and saves them when creating and updating' do
    resource = content_nodes(:resource_with_full_case)
    annotation = Content::Annotation.create(resource: resource,
                                            kind: 'highlight',
                                            global_start_offset: 10,
                                            global_end_offset: 50)
    assert_equal 0, annotation.start_paragraph
    assert_equal 2, annotation.end_paragraph
    assert_equal 10, annotation.start_offset
    assert_equal 29, annotation.end_offset

    resource.resource.update content: resource.resource.content[0..30]
    annotation.reload

    assert_equal 0, annotation.start_paragraph
    assert_equal 0, annotation.end_paragraph
    assert_equal 10, annotation.start_offset
    assert_equal 19, annotation.end_offset
  end
end
