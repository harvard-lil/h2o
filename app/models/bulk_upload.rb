class BulkUpload < ActiveRecord::Base
  has_many :imports
  
  def delayed_job
      @delayed_job ||= find_delayed_job
  end
  
  private
  def find_delayed_job
    begin
      Delayed::Job.find(self.delayed_job_id)
    rescue ActiveRecord::RecordNotFound
      nil
    end
  end
end
