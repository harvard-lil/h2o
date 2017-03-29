module H2o::Test::Helpers::Sunspot
  def self.included(base)
    # Disable sunspot for most tests
    sunspot_test_session = Sunspot.session
    sunspot_stub_session = Sunspot::Rails::StubSessionProxy.new(sunspot_test_session)
    Sunspot.session = sunspot_stub_session

    base.setup do
      if metadata[:solr]
        Sunspot.session = sunspot_test_session
        Sunspot.searchable.each &:solr_reindex
      end
    end
    base.teardown do
      if metadata[:solr]
        Sunspot.remove_all!
        Sunspot.session = sunspot_stub_session
      end
    end
  end
end

class Sunspot::Rails::StubSessionProxy::Search
  def execute!
  end
  def each_hit_with_result
  end
end
