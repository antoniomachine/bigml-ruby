require_relative "../lib/bigml/api"


require "test/unit"

class TestTimeSeries < Test::Unit::TestCase

  def setup
   @api = BigML::Api.new
   @test_name=File.basename(__FILE__).gsub('.rb','')
   @api.delete_all_project_by_name(@test_name)
   @project = @api.create_project({'name' => @test_name})
  end

  def teardown
    @api.delete_all_project_by_name(@test_name)
  end

  #  "Scenario: Successfully creating forecasts from a dataset"
  def test_scenario1
    data = [[File.dirname(__FILE__)+'/data/grades.csv', 
            'my new time series name', 
            {"000005" => {"horizon" => 5}}, 
            {"000005" => [{"point_forecast" => [73.96192, 74.04106, 74.12029, 74.1996, 74.27899], "model" => "M,M,N"}]}]
           ]
    puts
    puts "Scenario: Successfully creating forecasts from a dataset"

    data.each do |filename, time_series_name, input_data, forecast_points|
       puts
       puts "Given I create a data source uploading a <%s> file" % filename
       source = @api.create_source(filename, {'name'=> 'source_test', 'project'=> @project["resource"]})

       puts "And I wait until the source is ready"
       assert_equal(BigML::HTTP_CREATED, source["code"])
       assert_equal(1, source["object"]["status"]["code"])
       assert_equal(@api.ok(source), true)
       
       puts "And I create a dataset"
       dataset=@api.create_dataset(source)

       puts "And I wait until the dataset is ready"
       assert_equal(BigML::HTTP_CREATED, dataset["code"])
       assert_equal(1, dataset["object"]["status"]["code"])
       assert_equal(@api.ok(dataset), true)
       
       puts "And I create time-series from a dataset"
       time_series = @api.create_time_series(dataset)
       
       puts "And I wait until the time series is ready"
       assert_equal(BigML::HTTP_CREATED, time_series["code"])
       assert_equal(@api.ok(time_series), true)
       
       puts "And I update the time series name to <%s>" % time_series_name
       time_series = @api.update_time_series(time_series['resource'], {'name' => time_series_name})
       
       puts "When I wait until the time series is ready"
       assert_equal(BigML::HTTP_ACCEPTED, time_series["code"])
       assert_equal(@api.ok(time_series), true)
       
       puts "Then the time series name is <%s>" % time_series_name
       assert_equal(time_series['object']['name'], time_series_name)

       puts "And I create a forecast for <%s>" % JSON.generate(input_data)
       forecast = @api.create_forecast(time_series, input_data)
       
       puts "And I wait until the forecast is ready"
       assert_equal(BigML::HTTP_CREATED, forecast["code"])
       assert_equal(@api.ok(forecast), true)

       puts "Then the forecasts are <%s>" % JSON.generate(forecast_points)
       
       attrs = ["point_forecast", "model"]
       
       forecast_points.each do |field_id, value|
         f = forecast['object']['forecast']['result'][field_id]
         p = value
         
         assert_equal(f.size, p.size)
         
         (0..(f.size-1)).each do |index|
           attrs.each do |attr|
             assert_equal(f[index][attr], p[index][attr])
           end 
         end 
         
       end 
       
    end
  end
  
end