class CaseList

  attr_reader :query_method, :args

  def initialize(query_method, args)
    @query_method = query_method
    @args = args
  end

  def self.deliver_since_date_and_not_active(date)
    query_method = Proc.new{|arg_date| Case.since_date_and_not_active(arg_date)}
    delivered_mail, query_results = CaseList.generate(query_method, :date => date)
    delivered_mail
  end

  def self.deliver_newly_added
    query_method = Proc.new{Case.newly_added}
    delivered_mail, query_results = CaseList.generate(query_method)
    CaseList.mark_as_sent(query_results)
    delivered_mail
  end

  def self.generate(query_method, args = {})
    cl = CaseList.new(query_method, args)
    cl.generate
  end

  def generate
    query_results = self.query_method.call(self.args)
    return Notifier.deliver_cases_list(query_results.to_tsv), query_results
  end

  def self.mark_as_sent(query_results)
    query_results.each do |case_obj|
      case_obj.update_attribute(:sent_in_cases_list, true)
    end
  end
end
