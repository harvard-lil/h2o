# coding: utf-8
require 'test_helper'

class SearchesControllerTest < ActionDispatch::IntegrationTest
  describe SearchesController, :citation? do
    it "should match regular and slug citation forms" do
      ctrl = SearchesController.new
      assert ctrl.send(:citation?, "42 F. Supp. 135")
      assert ctrl.send(:citation?, "42-f-supp-135")
      refute ctrl.send(:citation?, "BOYER v. MILLER HATCHERIES, Inc.")
      refute ctrl.send(:citation?, "Not 42 F. Supp. 135")
      refute ctrl.send(:citation?, "42 F. Supp. 135 but not")
    end
  end
end
