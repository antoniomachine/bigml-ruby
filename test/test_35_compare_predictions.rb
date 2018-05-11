require_relative "../lib/bigml/api"
require_relative "../lib/bigml/timeseries"

require "test/unit"

class Test35ComparePredictions < Test::Unit::TestCase

  def setup
   @api = BigML::Api.new
   @test_name=File.basename(__FILE__).gsub('.rb','')
   @api.delete_all_project_by_name(@test_name)
   @project = @api.create_project({'name' => @test_name})
  end

  def teardown
    @api.delete_all_project_by_name(@test_name)
  end

  # Scenario: Successfully comparing forecasts from time series
  def test_scenario1
    data = [[File.dirname(__FILE__)+'/data/grades.csv', {"000005" => {"horizon" => 5}}, {"000005" => [{"point_forecast" => [73.96192, 74.04106, 74.12029, 74.1996, 74.27899], "model" => "M,M,N"}]}, {"objective_fields" => ["000001", "000005"]}],
            [File.dirname(__FILE__)+'/data/grades.csv', {"000005" => {"horizon" => 5, "ets_models" => {"names" => ["M,N,N"], "criterion" => "aic", "limit" => 3}}}, {"000005" => [{"point_forecast" =>  [68.39832, 68.39832, 68.39832, 68.39832, 68.39832], "model" => "M,N,N"}]}, {"objective_fields" => ["000001", "000005"]}],
            [File.dirname(__FILE__)+'/data/grades.csv', {"000005" => {"horizon" => 5, "ets_models" => {"names" => ["A,A,N"], "criterion" => "aic", "limit" => 3}}}, {"000005" => [{"point_forecast" =>  [72.46247, 72.56247, 72.66247, 72.76247, 72.86247], "model" => "A,A,N"}]}, {"objective_fields" => ["000001", "000005"]}],
            [File.dirname(__FILE__)+'/data/grades.csv', {"000005" => {"horizon" => 5}, "000001" => {"horizon" => 3, "ets_models" => {"criterion" => "aic", "limit" => 2}}}, {"000005" => [{"point_forecast" => [73.96192, 74.04106, 74.12029, 74.1996, 74.27899], "model" => "M,M,N"}], "000001" => [{"point_forecast" => [55.51577, 89.69111, 82.04935], "model" => "A,N,A"}, {"point_forecast" => [56.67419, 91.89657, 84.70017], "model" => "A,A,A"}]}, {"objective_fields" => ["000001", "000005"]}]
           ]
                       
    puts
    puts "Scenario: Successfully comparing forecasts from time series"

    data.each do |filename, input_data, forecast_points, params|
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
       time_series = @api.create_time_series(dataset, params)
       
       puts "And I wait until the time series is ready"
       assert_equal(BigML::HTTP_CREATED, time_series["code"])
       assert_equal(@api.ok(time_series), true)
       
       puts "And I create a local time series"
       local_time_series = BigML::TimeSeries.new(time_series["resource"], @api)
       
       puts "When I create a forecast for <%s>" % JSON.generate(input_data)
       
       forecast = @api.create_forecast(time_series, input_data)
       
       puts "And I wait until the forecast is ready"
       assert_equal(BigML::HTTP_CREATED, forecast["code"])
       assert_equal(@api.ok(forecast), true)
       
       puts "Then the forecast is <%s>" % JSON.generate(forecast_points) 
       
       attrs = ["point_forecast", "model"]
       
       forecast_points.each do |field_id, value|
         f = forecast['object']['forecast']['result'][field_id]
         p = value
         
         assert_equal(f.size, p.size)
         
         (0..(f.size-1)).each do |index|
           attrs.each do |attr|
             if f[index][attr].is_a?(Array)
               f[index][attr].each_with_index do |item, pos|
                 assert_equal(p[index][attr][pos].to_f.round(3), item.to_f.round(3))
               end 
             else
               assert_equal(f[index][attr].to_f.round(3), p[index][attr].to_f.round(3))
             end 
           end 
         end 
         
       end 
       
       puts "And I create a local forecast for <%s>" % JSON.generate(input_data)
       local_forecast = local_time_series.forecast(input_data)
       
       puts "Then the local forecast is <%s>" % JSON.generate(forecast_points) 
       
       forecast_points.each do |field_id, value|
         f = local_forecast[field_id]
         p = value
         
         assert_equal(f.size, p.size)
         (0..(f.size-1)).each do |index|
           attrs.each do |attr|
             if f[index][attr].is_a?(Array)
               f[index][attr].each_with_index do |item, pos|
                 assert_equal(p[index][attr][pos].to_f.round(3), item.to_f.round(3))
               end 
             else
               assert_equal(f[index][attr].to_f.round(3), p[index][attr].to_f.round(3))
             end    
           end 
         end 
         
       end

    end
  end
  
  # Scenario: Successfully comparing forecasts from time series with "A" seasonality
  def test_scenario2
    data = [[File.dirname(__FILE__)+'/data/grades.csv', {"000005" => {"horizon" => 5}}, {"000005" => [{"point_forecast" => [73.96192, 74.04106, 74.12029, 74.1996, 74.27899], "model" => "M,M,N"}]}, {"objective_fields" => ["000001", "000005"], "period" => 12}],
            [File.dirname(__FILE__)+'/data/grades.csv', {"000005" => {"horizon" => 5, "ets_models" => {"names" => ["M,N,A"], "criterion" => "aic", "limit" => 3}}}, {"000005" => [{"point_forecast" =>  [67.43222, 68.24468, 64.14437, 67.5662, 67.79028], "model" => "M,N,A"}]}, {"objective_fields" => ["000001", "000005"], "period" => 12}],
            [File.dirname(__FILE__)+'/data/grades.csv', {"000005" => {"horizon" => 5, "ets_models" => {"names" => ["A,A,A"], "criterion" => "aic", "limit" => 3}}}, {"000005" => [{"point_forecast" =>  [74.73553, 71.6163, 71.90264, 76.4249, 75.06982], "model" => "A,A,A"}]}, {"objective_fields" => ["000001", "000005"], "period" => 12}]
           ]
    
    puts
    puts "Scenario: Successfully comparing forecasts from time series with 'A' seasonality"

    data.each do |filename, input_data, forecast_points, params|
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
       time_series = @api.create_time_series(dataset, params)
       
       puts "And I wait until the time series is ready"
       assert_equal(BigML::HTTP_CREATED, time_series["code"])
       assert_equal(@api.ok(time_series), true)
       
       puts "And I create a local time series"
       local_time_series = BigML::TimeSeries.new(time_series["resource"], @api)
       
       puts "When I create a forecast for <%s>" % JSON.generate(input_data)
       
       forecast = @api.create_forecast(time_series, input_data)
       
       puts "And I wait until the forecast is ready"
       assert_equal(BigML::HTTP_CREATED, forecast["code"])
       assert_equal(@api.ok(forecast), true)
       
       puts "Then the forecast is <%s>" % JSON.generate(forecast_points) 
       
       attrs = ["point_forecast", "model"]
       
       forecast_points.each do |field_id, value|
         f = forecast['object']['forecast']['result'][field_id]
         p = value
         
         assert_equal(f.size, p.size)
         
         (0..(f.size-1)).each do |index|
           attrs.each do |attr|
             if f[index][attr].is_a?(Array)
               f[index][attr].each_with_index do |item, pos|
                 assert_equal(p[index][attr][pos].to_f.round(3), item.to_f.round(3))
               end 
             else
               assert_equal(f[index][attr].to_f.round(3), p[index][attr].to_f.round(3))
             end 
           end 
         end 
         
       end 
       
       puts "And I create a local forecast for <%s>" % JSON.generate(input_data)
       local_forecast = local_time_series.forecast(input_data)
       
       puts "Then the local forecast is <%s>" % JSON.generate(forecast_points) 
       
       forecast_points.each do |field_id, value|
         f = local_forecast[field_id]
         p = value
         
         assert_equal(f.size, p.size)
         (0..(f.size-1)).each do |index|
           attrs.each do |attr|
             if f[index][attr].is_a?(Array)
               f[index][attr].each_with_index do |item, pos|
                 assert_equal(p[index][attr][pos].to_f.round(3), item.to_f.round(3))
               end 
             else
               assert_equal(f[index][attr].to_f.round(3), p[index][attr].to_f.round(3))
             end    
           end 
         end 
         
       end
       
    end
  end
  
  # Scenario: Successfully comparing forecasts from time series with "M" seasonality
  def test_scenario3
    data = [[File.dirname(__FILE__)+'/data/grades.csv', {"000005" => {"horizon" => 5, "ets_models" => {"names" => ["M,N,M"], "criterion" => "aic", "limit" => 3}}}, {"000005" => [{"point_forecast" => [68.99775, 72.76777, 66.5556, 70.90818, 70.92998], "model" => "M,N,M"}]}, {"objective_fields" => ["000001", "000005"], "period" => 12}],
    
            [File.dirname(__FILE__)+'/data/grades.csv', {"000005" => {"horizon" => 5, "ets_models" => {"names" => ["M,A,M"], "criterion" => "aic", "limit" => 3}}}, {"000005" => [{"point_forecast" =>  [70.65993, 78.20652, 69.64806, 75.43716, 78.13556], "model" => "M,A,M"}]}, {"objective_fields" => ["000001", "000005"], "period" => 12}],
            
            [File.dirname(__FILE__)+'/data/grades.csv', {"000005" => {"horizon" => 5, "ets_models" => {"names" => ["M,M,M"], "criterion" => "aic", "limit" => 3}}}, {"000005" => [{"point_forecast" =>  [71.75055, 80.67195, 70.81368, 79.84999, 78.27634], "model" => "M,M,M"}]}, {"objective_fields" => ["000001", "000005"], "period" => 12}]
           ]
    puts
    puts "Scenario: Successfully comparing forecasts from time series with 'M' seasonality"

    data.each do |filename, input_data, forecast_points, params|
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
       time_series = @api.create_time_series(dataset, params)
       
       puts "And I wait until the time series is ready"
       assert_equal(BigML::HTTP_CREATED, time_series["code"])
       assert_equal(@api.ok(time_series), true)

       puts "And I create a local time series"
       local_time_series = BigML::TimeSeries.new(time_series["resource"], @api)
       
       puts "When I create a forecast for <%s>" % JSON.generate(input_data)
       
       forecast = @api.create_forecast(time_series, input_data)
       
       puts "And I wait until the forecast is ready"
       assert_equal(BigML::HTTP_CREATED, forecast["code"])
       assert_equal(@api.ok(forecast), true)
       
       puts "Then the forecast is <%s>" % JSON.generate(forecast_points) 
       
       attrs = ["point_forecast", "model"]
       
       forecast_points.each do |field_id, value|
         f = forecast['object']['forecast']['result'][field_id]
         p = value
         
         assert_equal(f.size, p.size)
         
         (0..(f.size-1)).each do |index|
           attrs.each do |attr|
             if f[index][attr].is_a?(Array)
               f[index][attr].each_with_index do |item, pos|
                 assert_equal(p[index][attr][pos].to_f.round(3), item.to_f.round(3))
               end 
             else
               assert_equal(f[index][attr].to_f.round(3), p[index][attr].to_f.round(3))
             end 
           end 
         end 
         
       end 
       
       puts "And I create a local forecast for <%s>" % JSON.generate(input_data)
       local_forecast = local_time_series.forecast(input_data)
       
       puts "Then the local forecast is <%s>" % JSON.generate(forecast_points) 
       
       forecast_points.each do |field_id, value|
         f = local_forecast[field_id]
         p = value
         
         assert_equal(f.size, p.size)
         (0..(f.size-1)).each do |index|
           attrs.each do |attr|
             if f[index][attr].is_a?(Array)
               f[index][attr].each_with_index do |item, pos|
                 assert_equal(p[index][attr][pos].to_f.round(3), item.to_f.round(3))
               end 
             else
               assert_equal(f[index][attr].to_f.round(3), p[index][attr].to_f.round(3))
             end    
           end 
         end 
         
       end
       
    end
  end
  
  # Scenario: Successfully comparing forecasts from time series with trivial models
  def test_scenario4
    data = [[File.dirname(__FILE__)+'/data/grades.csv', {"000005" => {"horizon" => 5, "ets_models" => {"names" => ["naive"]}}}, {"000005" => [{"point_forecast" => [61.39, 61.39, 61.39, 61.39, 61.39], "model" => "naive"}]}, {"objective_fields" => ["000001", "000005"], "period" => 1}],
            [File.dirname(__FILE__)+'/data/grades.csv', {"000005" => {"horizon" => 5, "ets_models" => {"names" => ["naive"]}}}, {"000005" => [{"point_forecast" =>  [78.89, 61.39, 78.89, 61.39, 78.89], "model" => "naive"}]}, {"objective_fields" => ["000001", "000005"], "period" => 2}],
            [File.dirname(__FILE__)+'/data/grades.csv', {"000005" => {"horizon" => 5, "ets_models" => {"names" => ["mean"], }}}, {"000005" => [{"point_forecast" =>  [68.45974, 68.45974, 68.45974, 68.45974, 68.45974], "model" => "mean"}]}, {"objective_fields" => ["000001", "000005"], "period" => 1}],
            [File.dirname(__FILE__)+'/data/grades.csv', {"000005" => {"horizon" => 5, "ets_models" => {"names" => ["mean"], }}}, {"000005" => [{"point_forecast" =>  [69.79553, 67.15821, 69.79553, 67.15821, 69.79553], "model" => "mean"}]}, {"objective_fields" => ["000001", "000005"], "period" => 2}],
            [File.dirname(__FILE__)+'/data/grades.csv', {"000005" => {"horizon" => 5, "ets_models" => {"names" => ["drift"], }}}, {"000005" => [{"point_forecast" =>  [61.50545, 61.6209, 61.73635, 61.8518, 61.96725], "model" => "drift"}]}, {"objective_fields" => ["000001", "000005"], "period" => 1}],
            [File.dirname(__FILE__)+'/data/grades.csv', {"000005" => {"horizon" => 5, "ets_models" => {"names" => ["drift"], }}}, {"000005" => [{"point_forecast" =>  [61.50545, 61.6209, 61.73635, 61.8518, 61.96725], "model" => "drift"}]}, {"objective_fields" => ["000001", "000005"], "period" => 2}]
           ]
    puts
    puts "Scenario: Successfully comparing forecasts from time series with trivial models"

    data.each do |filename, input_data, forecast_points, params|
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
       time_series = @api.create_time_series(dataset, params)
       
       puts "And I wait until the time series is ready"
       assert_equal(BigML::HTTP_CREATED, time_series["code"])
       assert_equal(@api.ok(time_series), true)

       puts "And I create a local time series"
       local_time_series = BigML::TimeSeries.new(time_series["resource"], @api)
       
       puts "When I create a forecast for <%s>" % JSON.generate(input_data)
       
       forecast = @api.create_forecast(time_series, input_data)
       
       puts "And I wait until the forecast is ready"
       assert_equal(BigML::HTTP_CREATED, forecast["code"])
       assert_equal(@api.ok(forecast), true)
       
       puts "Then the forecast is <%s>" % JSON.generate(forecast_points) 
       
       attrs = ["point_forecast", "model"]
       
       forecast_points.each do |field_id, value|
         f = forecast['object']['forecast']['result'][field_id]
         p = value
         
         assert_equal(f.size, p.size)
         
         (0..(f.size-1)).each do |index|
           attrs.each do |attr|
             if f[index][attr].is_a?(Array)
               f[index][attr].each_with_index do |item, pos|
                 assert_equal(p[index][attr][pos].to_f.round(3), item.to_f.round(3))
               end 
             else
               assert_equal(f[index][attr].to_f.round(3), p[index][attr].to_f.round(3))
             end 
           end 
         end 
         
       end 
       
       puts "And I create a local forecast for <%s>" % JSON.generate(input_data)
       local_forecast = local_time_series.forecast(input_data)
       
       puts "Then the local forecast is <%s>" % JSON.generate(forecast_points) 
       
       forecast_points.each do |field_id, value|
         f = local_forecast[field_id]
         p = value
         
         assert_equal(f.size, p.size)
         (0..(f.size-1)).each do |index|
           attrs.each do |attr|
             if f[index][attr].is_a?(Array)
               f[index][attr].each_with_index do |item, pos|
                 assert_equal(p[index][attr][pos].to_f.round(3), item.to_f.round(3))
               end 
             else
               assert_equal(f[index][attr].to_f.round(3), p[index][attr].to_f.round(3))
             end    
           end 
         end 
         
       end
       
    end
  end
  
end