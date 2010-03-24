module SweeperHelper

  def expire_question_instance(record)
    expire_fragment("question-instance-index-#{record.question_instance_id}-false")
    expire_fragment("question-instance-index-#{record.question_instance_id}-true")
  end

  def expire_question(record)
    ids_to_expire = [record.id, record.ancestors_ids].flatten

    ids_to_expire.each do |question_id|
      expire_fragment("question-detail-view-#{question_id}")
      expire_fragment("question-reply-detail-view-#{question_id}")
    end
  end

end
