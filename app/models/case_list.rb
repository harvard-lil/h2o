class CaseList

  attr_reader :query_method, :args

  def initialize(query_method, args)
    @query_method = query_method
    @args = args
  end

  def self.deliver_since_date_and_not_active(date)
    query_method = Proc.new{|arg_date| Case.since_date_and_not_active(arg_date)}
    delivered_mail = CaseList.generate(query_method, :date => date)
    delivered_mail
  end

  def self.deliver_newly_added
    query_method = Proc.new{Case.all}
    delivered_mail = CaseList.generate(query_method)
    delivered_mail
  end

  def self.generate(query_method, args = {})
    cl = CaseList.new(query_method, args)
    cl.generate
  end

  def generate
    query_results = self.query_method.call(self.args)
    Notifier.deliver_cases_list(query_results.to_tsv)
  end

end
