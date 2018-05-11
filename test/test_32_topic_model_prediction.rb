require_relative "../lib/bigml/api"
require_relative "../lib/bigml/topicmodel"
require "test/unit"

DUMMY_MODEL = {
    "topic_model" =>  {
        "alpha" =>  0.08,
        "beta" =>  0.1,
        "hashed_seed" =>  0,
        "language" =>  "en",
        "bigrams" =>  true,
        "case_sensitive" =>  false,
        "term_topic_assignments" =>  [[0, 0, 1, 2],
                                   [0, 1, 2, 0],
                                   [1, 2, 0, 0],
                                   [0, 0, 2, 0]],
        "termset" =>  ["cycling", "playing", "shouldn't", "uńąnimous court"],
        "options" =>  {},
        "topics" =>  [{"name" =>  "Topic 1",
                    "id" => "000000",
                    "top_terms" => ["a", "b"],
                    "probability" => 0.1},
                   {"name" => "Topic 2",
                    "id" => "000001",
                    "top_terms" => ["c", "d"],
                    "probability" => 0.1},
                   {"name" => "Topic 3",
                    "id" => "000000",
                    "top_terms" => ["e", "f"],
                    "probability" => 0.1},
                   {"name" => "Topic 4",
                    "id" => "000000",
                    "top_terms" => ["g", "h"],
                    "probability" => 0.1}],
        "fields" => {
            "000001" => {
                "datatype" => "string",
                "name" => "TEST TEXT",
                "optype" => "text",
                "order" => 0,
                "preferred" => true,
                "summary" => {},
                "term_analysis" => {}
            }
        }
    },
    "resource" => "topicmodel/aaaaaabbbbbbccccccdddddd"
}

class TestTopicModelPrediction < Test::Unit::TestCase

  def setup
   @api = BigML::Api.new
   @test_name=File.basename(__FILE__).gsub('.rb','')
   @api.delete_all_project_by_name(@test_name)
   @project = @api.create_project({'name' => @test_name})
  end

  def teardown
    @api.delete_all_project_by_name(@test_name)
  end

  # Scenario 1: Successfully creating a local Topic Distribution
  def test_scenario1
    data = [{"model" =>  DUMMY_MODEL,
             "text" => {"TEST TEXT" =>  "uńąnimous court 'UŃĄNIMOUS COURT' `play``the plays PLAYing SHOULDN'T CYCLE cycling shouldn't uńąnimous or court's"},
             "expected_distribution" => [{"name" => 'Topic 1', "probability" => 0.1647366}, 
                                         {"name" => 'Topic 2', "probability" => 0.1885310}, 
                                         {"name" => 'Topic 3', "probability" => 0.4879441}, 
                                         {"name" => 'Topic 4', "probability" => 0.1587880}]}]
    puts 
    puts "Scenario 1: Successfully creating a local Topic Distribution"
  
    data.each do |item|

       puts "Given I have a block of text and an LDA model"
       topic_model = BigML::TopicModel.new(item["model"])
       puts "And I use the model to predict the topic distribution"
       distribution = topic_model.distribution(item["text"])
      
       assert_equal(distribution.size, item["expected_distribution"].size)
      
       puts "Then the value of the distribution matches the expected distribution"
       distribution.each_with_index do |d,index|
          assert_equal(d["probability"].round(4),item["expected_distribution"][index]["probability"].round(4))
          assert_equal(d["name"],item["expected_distribution"][index]["name"])
       end 
    end
    
  end
  
  # Scenario 2: Successfully creating Topic Model from a dataset
  def test_scenario2
    data = [{"filename" => File.dirname(__FILE__)+"/data/spam.csv",
             "topic_model_name" => "my new topic model name",
             "params" => {"fields" => {"000001" => {"optype" => "text", "term_analysis" => {"case_sensitive" => true, "stem_words" => true, "use_stopwords" => false, "language" => "en"}}}}}]
    puts 
    puts "Scenario 2: Successfully creating Topic Model from a dataset"
  
    data.each do |item|
      puts
      puts "Given I create a data source uploading a " + item["filename"] + " file"
      source = @api.create_source(item["filename"], {'name'=> 'source_test', 'project'=> @project["resource"]})

      puts "And I wait until the source is ready"
      assert_equal(BigML::HTTP_CREATED, source["code"])
      assert_equal(1, source["object"]["status"]["code"])
      assert_equal(@api.ok(source), true)
      
      puts "And I update the source with params <%s>" % JSON.generate(item["params"])
      source = @api.update_source(source, item["params"])
      assert_equal(BigML::HTTP_ACCEPTED, source["code"])
      assert_equal(@api.ok(source), true)

      puts "And I create dataset"
      dataset=@api.create_dataset(source)
   
      puts "And I wait until the dataset is ready"
      assert_equal(BigML::HTTP_CREATED, dataset["code"])
      assert_equal(1, dataset["object"]["status"]["code"])
      assert_equal(@api.ok(dataset), true)
      
      puts "And I create topic model from a dataset"
      topicmodel = @api.create_topic_model(dataset)
      
      puts "And I wait until the topic model is ready"
      assert_equal(BigML::HTTP_CREATED, topicmodel["code"])
      assert_equal(1, topicmodel["object"]["status"]["code"])
      assert_equal(@api.ok(topicmodel), true)
      
      puts "And I update the topic model name to <%s>" % item["topic_model_name"]
      topicmodel = @api.update_topic_model(topicmodel, {'name' => item["topic_model_name"]})
      
      puts "When I wait until the topic_model is ready"
      assert_equal(BigML::HTTP_ACCEPTED, topicmodel["code"])
      assert_equal(@api.ok(topicmodel), true)
      
      puts "Then the topic model name is <%s>" % item["topic_model_name"]
      assert_equal(topicmodel['object']['name'], item["topic_model_name"])
      
    end
    
  end

end
