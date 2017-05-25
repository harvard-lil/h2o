module IframeHelper
  def data_for(object)
    {
      external: url_for(object),
      type: object.class.table_name
    }
  end
end
