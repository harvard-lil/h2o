module HeatmapExtensions
  module ClassMethods
    def color_map
      [
        'ff0080',
        '9e00ff',
        '6600ff',
        '2e00ff',
        '000aff',
        '0042ff',
        '007aff',
        '00b3ff',
        '00ffdb',
        '00ffa3',
        '00ff6b',
        '05ff00',
        '73fd00',
        'abfd00',
        'e4fd00',
        'ffee00',
        'feb62a',
        'fdac12',
        'fe872a',
        'ff3800',
        'fe2a2a'
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
