require "test/unit"

require_relative "../lib/bigml/api"
require_relative "../lib/bigml/model"
require_relative "../lib/bigml/multivote"

class TestMultiVotePredicction < Test::Unit::TestCase

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
    data = [
            {"filename" => File.dirname(__FILE__)+"/data/predictions_c.json", 
             "method" => 0,
             "prediction" => "a",
	     "confidence" => 0.450471270879},
            {"filename" => File.dirname(__FILE__)+"/data/predictions_c.json",
             "method" => 1,
             "prediction" => "a",
             "confidence" => 0.552021302649},
            {"filename" => File.dirname(__FILE__)+"/data/predictions_c.json",
             "method" => 2,
             "prediction" => "a",
             "confidence" => 0.403632421178},
            {"filename" => File.dirname(__FILE__)+"/data/predictions_r.json",
             "method" => 0,
             "prediction" => 1.55555556667, 
             "confidence" => 0.400079152063},
           {"filename" => File.dirname(__FILE__)+"/data/predictions_r.json",
             "method" => 1,
             "prediction" => 1.59376845074,
             "confidence" => 0.248366474212},
           {"filename" => File.dirname(__FILE__)+"/data/predictions_r.json",
             "method" => 2,
             "prediction" => 1.55555556667,
             "confidence" => 0.400079152063}
          ]

    puts "Scenario: Successfully computing predictions combinations"
    data.each do |item|
       puts

       puts "Given I create a MultiVote for the set of predictions in file <%s>" % item["filename"]
       multivote =  BigML::MultiVote.new(JSON.parse(File.open(item["filename"], "rb").read))

       puts "When I compute the prediction with confidence using method <%s>" % item["method"]
       combined_results = multivote.combine(item["method"], nil, true)

       puts "And I compute the prediction without confidence using method <%s>" % item["method"] 
       combined_results_no_confidence = multivote.combine(item["method"])

       if multivote.is_regression() 
          puts "Then the combined prediction is <%s>" % item["prediction"]
          assert_equal(combined_results["prediction"].round(6), item["prediction"].round(6))
          puts "And the combined prediction without confidence is <%s>" % item["prediction"]
          assert_equal(combined_results_no_confidence.round(6), item["prediction"].round(6))
       else
          puts "Then the combined prediction is <%s>" % item["prediction"]
          assert_equal(combined_results["prediction"], item["prediction"])
          puts "And the combined prediction without confidence is <%s>" % item["prediction"]
          assert_equal(combined_results_no_confidence,item["prediction"])
       end
       puts "And the confidence for the combined prediction is %s " % item["confidence"]
       assert_equal(combined_results["confidence"].round(5), item["confidence"].round(5)) 
    end

  end

end

