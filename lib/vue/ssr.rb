module Vue
  module SSR
    class << self
      JS_SOURCE_PATH = Rails.root.join('lib','vue','ssr.js')
      JS_SETUP_PATH = Rails.root.join('test','javascript','mocha_setup.js')
      WEBPACK_CONFIG_PATH = Rails.root.join('config','webpack','test.js')

      def compile
        digest = Digest::MD5.hexdigest(File.read(JS_SOURCE_PATH))
        js_build_path = Rails.root.join('tmp',"lib-vue-ssr-#{digest}.js")

        if !File.file?(js_build_path)
          `NODE_ENV=production bin/webpack --entry #{JS_SOURCE_PATH} --output #{js_build_path} --config #{WEBPACK_CONFIG_PATH} --target node --mode production`
        end

        yield js_build_path
      end

      def render content, annotations = []
        compile do |script|
          node_cmd = "node -r #{JS_SETUP_PATH} #{script}"
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
end
