module HeatmapExtensions
  extend ActiveSupport::Concern

  module ClassMethods
    def color_list
      [
        { :hex => 'ff0080', :text => '#000000' },
        { :hex => '9e00ff', :text => '#FFFFFF' },
        { :hex => '6600ff', :text => '#FFFFFF' },
        { :hex => '2e00ff', :text => '#FFFFFF' },
        { :hex => '000aff', :text => '#FFFFFF' },
        { :hex => '0042ff', :text => '#FFFFFF' },
        { :hex => '007aff', :text => '#FFFFFF' },
        { :hex => '00b3ff', :text => '#000000' },
        { :hex => '00ffdb', :text => '#000000' },
        { :hex => '00ffa3', :text => '#000000' },
        { :hex => '00ff6b', :text => '#000000' },
        { :hex => '05ff00', :text => '#000000' },
        { :hex => '73fd00', :text => '#000000' },
        { :hex => 'abfd00', :text => '#000000' },
        { :hex => 'e4fd00', :text => '#000000' },
        { :hex => 'ffee00', :text => '#000000' },
        { :hex => 'feb62a', :text => '#000000' },
        { :hex => 'fdac12', :text => '#000000' },
        { :hex => 'fe872a', :text => '#000000' },
        { :hex => 'ff3800', :text => '#000000' },
        { :hex => 'fe2a2a', :text => '#000000' }
      ]
    end
  end

  def heatmap
    heatmap_annotations = self.annotatable.collages.inject([]) do |arr, c|
      if c != self && c.annotator_version == self.annotator_version
        c.annotations.each do |ann|
          arr << ann.to_json(:include => :layers)
        end
      end
      arr
    end

    heatmap_annotations.flatten
  end
end
