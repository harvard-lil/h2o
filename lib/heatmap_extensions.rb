module HeatmapExtensions
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

  module InstanceMethods
    def heatmap_active
      !self.annotatable.collages.detect { |c| c.annotator_version != self.annotator_version }
    end

    def heatmap
      if self.annotator_version == 1
	      raw_data = {}
	      self.annotatable.collages.each do |collage|
	        collage.annotations.each do |annotation|
	          next if annotation.layers.empty?
	          a_start = annotation.annotation_start.gsub(/^t/, '').to_i 
	          a_end = annotation.annotation_end.gsub(/^t/, '').to_i
	          (a_start..a_end).each do |i|
	            raw_data["t#{i}"] ||= 0 
	            raw_data["t#{i}"] += 1
	          end
	        end
	      end
	      max = raw_data.values.max.to_f
	      { :data => raw_data, :max => max }
      else 
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
  end
end
