module HTMLFormatter
  @@versions = []

  class << self
    def versions
      # newest to oldest
      @@versions.sort { |a, b| b::EFFECTIVE_DATE <=> a::EFFECTIVE_DATE }
    end

    def at date
      versions.find { |v| v::EFFECTIVE_DATE <= date }
    end

    def latest
      versions.first
    end

    def process html_string
      latest.process(html_string)
    end
  end
end

# force rails to load the various versions
Dir["lib/html_formatter/*"].each { |path| require_dependency path[4..-1] }
