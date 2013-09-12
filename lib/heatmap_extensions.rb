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
    def heatmap
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
      #raw_data # Need to scale
      #No colors
      #color_map = Collage.color_map
      max = raw_data.values.max.to_f
      #scale_data = {}
      #raw_data.each { |k, v| scale_data[k] = color_map[((v.to_f/max)*22).to_i - 1] }
      #scale_data
      { :data => raw_data, :max => max }
    end
  end
end
