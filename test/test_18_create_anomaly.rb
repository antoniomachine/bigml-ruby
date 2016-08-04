require_relative "../lib/bigml/api"
require_relative "../lib/bigml/anomaly"

require "test/unit"

#  Creating anomaly detector
class TestCreateAnomaly < Test::Unit::TestCase

  def setup
   @api = BigML::Api.new(nil, nil, true)
   @test_name=File.basename(__FILE__).gsub('.rb','')
   @api.delete_all_project_by_name(@test_name)
   @project = @api.create_project({'name' => @test_name})
  end

  def teardown
    @api.delete_all_project_by_name(@test_name)
  end

  # Scenario: Successfully creating an anomaly detector from a dataset and a dataset list 
  def test_scenario1
    data = [[File.dirname(__FILE__)+'/data/tiny_kdd.csv']]

    puts 
    puts "Scenario: Successfully creating an anomaly detector from a dataset and a dataset list"

    data.each do |item|
       puts
       puts "Given I create a data source uploading a %s file" % item[0]
       source = @api.create_source(item[0], {'name'=> 'source_test', 'project'=> @project["resource"]})

       puts "And I wait until the source is ready"
       assert_equal(BigML::HTTP_CREATED, source["code"])
       assert_equal(1, source["object"]["status"]["code"])
       assert_equal(@api.ok(source), true)

       puts "And I create dataset with local source"
       dataset=@api.create_dataset(source)

       puts "And I wait until the dataset is ready"
       assert_equal(BigML::HTTP_CREATED, dataset["code"])
       assert_equal(1, dataset["object"]["status"]["code"])
       assert_equal(@api.ok(dataset), true)
 
       puts "Then I create an anomaly detector from a dataset"
       anomaly = @api.create_anomaly(dataset)

       puts "And I wait until the anomaly detector"
       assert_equal(BigML::HTTP_CREATED, anomaly["code"])
       assert_equal(1, anomaly["object"]["status"]["code"])
       assert_equal(@api.ok(anomaly), true)

       puts "And I check the anomaly detector stems from the original dataset"
       assert_equal(anomaly["object"]["dataset"],dataset["resource"])

       puts "And I store the dataset id in a list"
       datasetsIds = [dataset["resource"]]

       puts "And I create a dataset"
       dataset=@api.create_dataset(source)
       puts "And I wait until the dataset is ready"
       assert_equal(BigML::HTTP_CREATED, dataset["code"])
       assert_equal(1, dataset["object"]["status"]["code"])
       assert_equal(@api.ok(dataset), true)

       puts "And I store the dataset id in a list"
       datasetsIds << dataset["resource"]

       puts "Then I create an anomaly detector from a dataset list"
       anomaly = @api.create_anomaly(datasetsIds);

       puts "And I wait until the anomaly detector is ready"
       assert_equal(BigML::HTTP_CREATED, anomaly["code"])
       assert_equal(1, anomaly["object"]["status"]["code"])
       assert_equal(@api.ok(anomaly), true)

       puts "And I check the anomaly detector stems from the original dataset list"
       assert_equal(anomaly["object"]["datasets"], datasetsIds)
 
    end

  end

  #  Scenario: Successfully creating an anomaly detector from a dataset and generating the anomalous dataset 
  def test_scenario2
    data = [[File.dirname(__FILE__)+'/data/iris_anomalous.csv', 1]]
  
    puts 
    puts "Scenario: Successfully creating an anomaly detector from a dataset and generating the anomalous dataset"
  
    data.each do |filename, rows|
       puts 
       puts "Given I create a data source uploading a %s file" % filename
       source = @api.create_source(filename, {'name'=> 'source_test', 'project'=> @project["resource"]})

       puts "And I wait until the source is ready"
       assert_equal(BigML::HTTP_CREATED, source["code"])
       assert_equal(1, source["object"]["status"]["code"])
       assert_equal(@api.ok(source), true)

       puts "And I create dataset with local source"
       dataset=@api.create_dataset(source)

       puts "And I wait until the dataset is ready"
       assert_equal(BigML::HTTP_CREATED, dataset["code"])
       assert_equal(1, dataset["object"]["status"]["code"])
       assert_equal(@api.ok(dataset), true)

       puts "Then I create an anomaly detector with %s anomalies from a dataset" % rows
       anomaly = @api.create_anomaly(dataset, {"seed" => "BigML", "top_n" => rows})

       puts "And I wait until the anomaly detector"
       assert_equal(BigML::HTTP_CREATED, anomaly["code"])
       assert_equal(1, anomaly["object"]["status"]["code"])
       assert_equal(@api.ok(anomaly), true)

       puts "And I create a dataset with only the anomalies"
       local_anomaly = BigML::Anomaly.new(anomaly["resource"], @api)
       new_dataset = @api.create_dataset(dataset, {'lisp_filter' => local_anomaly.anomalies_filter()})
       
       puts "And I wait until the dataset is ready"
       assert_equal(BigML::HTTP_CREATED, new_dataset["code"])
       assert_equal(1, new_dataset["object"]["status"]["code"])
       assert_equal(@api.ok(new_dataset), true)

       puts "And I check that the dataset has <%s> rows" % rows
       assert_equal(new_dataset["object"]["rows"],rows)
    end
  end

end

