module Tidy
  class << self
    PATH = Rails.root.join('node_modules','htmltidy2','bin','darwin','tidy')
    CONFIG = {quiet: true,
              show_warnings: false,
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
      CONFIG.map { |k, v| "--#{k.to_s.gsub('_', '-')} #{v ? 'yes' : 'no'}"}.join(' ')
    end
  end
end
