module DiffLCS
  def self.format diff
    diff.map do |changes|
      ["*** #{changes.first.position}" +
       (changes.first.position != changes.last.position ? ",#{changes.last.position}" : "") + " ***",
       changes.reduce({}) do |memo, change|
         memo[change.action] = (memo[change.action] || "") + change.element
         memo
       end.map { |action, elements| "#{action} " + elements.gsub("\n", "\n#{action} ") }].join("\n")
    end.join("\n\n")
  end
end
