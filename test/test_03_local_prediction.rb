require "test/unit"

require_relative "../lib/bigml/api"
require_relative "../lib/bigml/model"

class TestLocalPredicction < Test::Unit::TestCase

  def setup
   @api = BigML::Api.new
   @test_name=File.basename(__FILE__).gsub('.rb','')
   @api.delete_all_project_by_name(@test_name)
   @project = @api.create_project({'name' => @test_name})
  end

  def teardown
    @api.delete_all_project_by_name(@test_name)
  end

  # Scenario: Successfully creating a prediction:
  def test_scenario1
    data = [{"filename" => File.dirname(__FILE__)+"/data/iris_model.json", 
             "data_input" => {'petal length'=> 0.5},
            "confidence" => 0.90594,
	          "prediction" => "Iris-setosa"}]

    puts "Scenario: Successfully creating a prediction from a local model in a json file" 
  
    data.each do |item|
       puts
       puts "Given I create a local model from a "+item["filename"]+" file "
       model = BigML::Model.new(item["filename"], @api)

       puts "When I create a local prediction for "+JSON.generate(item["data_input"])+" with confidence"
       prediction = model.predict(item["data_input"], {'full' => true})
       puts "Then the local prediction is %s " % item["prediction"]
       assert_equal(prediction["prediction"], item["prediction"])

       puts "And the local prediction's confidence is %s" % item["confidence"]
       assert_equal(prediction["confidence"], item["confidence"])
    end

  end

end

