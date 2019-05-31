module Tidy
  class << self
    PATH = Rails.root.join('node_modules','htmltidy2','bin',Gem::Platform.local.os,'tidy')
    CONFIG = {force_output: true,
              quiet: true,
              show_errors: 0,
              show_warnings: false,
              show_info: false,
              enclose_text: true,
              drop_empty_elements: true,
              hide_comments: true,
              tidy_mark: false}

    def exec html
      IO.popen("#{PATH} #{flags}", 'r+') do |io|
        io.write(html)
        io.close_write
        io.read
      end
    end

    private

    def flags
      CONFIG.map { |k, v|
        "--#{k.to_s.gsub('_', '-')} #{v === true ? 'yes' : v === false ? 'no' : v}"
      }.join(' ')
    end
  end
end
