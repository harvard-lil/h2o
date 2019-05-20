require 'tempfile'

module Vue
  module SSR
    def self.compile
      file = Tempfile.new('vue_ssr.js')
      begin
        `NODE_ENV=production bin/webpack --entry #{Rails.root.join('lib','vue','ssr.js')} --output #{file.path} --config #{Rails.root.join('config','webpack','test.js')} --target node --mode production`
        yield file.path
      ensure
        file.close
        file.unlink
      end
    end

    def self.render content, annotations = []
      self.compile do |script|
        node_cmd = "node -r #{Rails.root.join('test','javascript','mocha_setup.js')} #{script}"
        IO.popen(node_cmd, 'r+') do |io|
          io.write({content: content,
                    annotations: annotations}.to_json)
          io.close_write
          io.read
        end
      end
    end
  end
end
