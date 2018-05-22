# encoding: utf-8
require_relative 'modelfields'
require_relative 'tssubmodels'

REQUIRED_INPUT = "horizon"
SUBMODEL_KEYS = ["indices", "names", "criterion", "limit"]
DEFAULT_SUBMODEL = {"criterion": "aic", "limit": 1}
INDENT = " " * 4

module BigML
  
  def self.compute_forecasts(submodels, horizon)
    # Computes the forecasts for each of the models in the submodels
    # array. The number of forecasts is set by horizon.
    # 
    forecasts = []
    submodels.each do |submodel|
      name = submodel["name"]
      trend = name
      seasonality = nil
      if name.include?(",")
        _, trend, seasonality = name.split(",")
        args = [submodel, horizon, seasonality]
      else
        args = [submodel, horizon]
      end

      forecasts << {"model" => name, "point_forecast" => self.send(SUBMODELS[trend], *args) }
      
    end
    
    return forecasts

  end
  
  def self.filter_submodels(submodels, filter_info)
    # Filters the submodels available for the field in the time-series
    # model according to the criteria provided in the prediction input data
    # for the field.
    #
    field_submodels = []
    submodel_names = []
    # filtering by indices and/or names
    indices = filter_info.fetch(SUBMODEL_KEYS[0].to_sym, filter_info.fetch(SUBMODEL_KEYS[0], []))
    names = filter_info.fetch(SUBMODEL_KEYS[1].to_sym, filter_info.fetch(SUBMODEL_KEYS[1], []))

    if !indices.empty?
      # adding all submodels by index if they are not also in the names
      # list
      field_submodels=[]
      submodels.each_with_index do |submodel,index|
        if indices.include?(index)
          field_submodels << submodel
        end  
      end
    end
    
    # union with filtered by names
    if !names.empty?
      pattern = names.join("|")
      # only adding the submodels if they have not been included by using
      # indices
      submodel_names=field_submodels.map{|submodel| submodel["name"]}
      
      named_submodels=[]
      submodels.each do |submodel|
        
        if submodel["name"] =~ /#{names.join("|")}/ and !submodel_names.include?(submodel["name"])
          named_submodels << submodel
        end  
        
      end
      
      field_submodels+=named_submodels
    end
    
    if indices.empty? and names.empty?
      field_submodels+=submodels
    end  

    # filtering the resulting set by criterion and limit
    criterion = filter_info.fetch(SUBMODEL_KEYS[2].to_sym, filter_info.fetch(SUBMODEL_KEYS[2], nil))
    if !criterion.nil?
      field_submodels = field_submodels.sort_by{|x| x.fetch(criterion,  Float::INFINITY)}
      limit = filter_info.fetch(SUBMODEL_KEYS[3].to_sym, filter_info.fetch(SUBMODEL_KEYS[3], nil))
      if !limit.nil?
        field_submodels = field_submodels[0..(limit-1)]
      end  
    end
    
    return field_submodels
  end   
  
  class TimeSeries < ModelFields
    # A lightweight wrapper around a time series model.
    # Uses a BigML remote time series model to build a local version
    # that can be used to generate predictions locally.
    
    def initialize(time_series, api=nil)
      @resource_id = nil
      @input_fields = []
      @objective_fields = []
      @all_numeric_objectives = false
      @period = 1
      @ets_models = {}
      @error = nil
      @damped_trend = nil
      @seasonality = nil
      @trend = nil
      @time_range = {}
      @field_parameters = {}
      @_forecast = {}
      
      # checks whether the information needed for local predictions is in
      # the first argument
      if time_series.is_a?(Hash) and !BigML::check_model_fields(time_series)
        # if the fields used by the logistic regression are not
        # available, use only ID to retrieve it again
        time_series = BigML::get_time_series_id(time_series)
        @resource_id = time_series
      end
      
      if !(time_series.is_a?(Hash) and time_series.key?("resource") and !time_series["resource"].nil?)
        if api.nil?
          api = BigML::Api.new(nil, nil, false, false, false, STORAGE)
        end  
        @resource_id = BigML::get_time_series_id(time_series)
        if @resource_id.nil?
          raise Exception, api.error_message(time_series, 'time_series', 'get')
        end 
        query_string = BigML::ONLY_MODEL
        time_series = BigML::retrieve_resource(api, @resource_id, query_string)
      else
        @resource_id = BigML::get_time_series_id(time_series)
      end 
      
      if time_series.key?('object') and time_series['object'].is_a?(Hash)
         time_series = time_series['object']
      end
      
      begin
        @input_fields = time_series.fetch("input_fields", [])
        @_forecast = time_series.fetch("forecast", nil)
        @objective_fields = time_series.fetch("objective_fields", [])
        objective_field = time_series.key?('objective_field') ? 
                   time_series['objective_field'] : time_series['objective_fields']
      rescue
        raise ArgumentError.new("Failed to find the time series expected JSON structure. Check your arguments.")
      end  
       
      if time_series.key?('time_series') and time_series['time_series'].is_a?(Hash)
        status = BigML::Util::get_status(time_series) 
        if status.key?('code') and status['code'] == FINISHED
           time_series_info = time_series['time_series']
           fields = time_series_info.fetch('fields', {})
           @fields = fields
           if @input_fields.empty?
             @input_fields = []
             # REVISAR
             @input_fields = @fields.sort_by {|k,v| v["column_number"]}.map{|k,v| k }
           end 
                     
           @all_numeric_objectives = time_series_info.fetch('all_numeric_objectives', nil)
           @period = time_series_info.fetch('period', 1)
           @ets_models = time_series_info.fetch('ets_models', {})
           @error = time_series_info.fetch('error', nil)
           @damped_trend = time_series_info.fetch('damped_trend',nil)
           @seasonality = time_series_info.fetch('seasonality', nil)
           @trend = time_series_info.fetch('trend', nil)
           @time_range = time_series_info.fetch('time_range', nil)
           @field_parameters = time_series_info.fetch('field_parameters', {})

           objective_id = BigML::extract_objective(objective_field)
           super(fields, objective_id)
        else
          raise Exception.new("The time series isn't finished yet")  
        end 
      else 
        raise Exception.new("Cannot create the TimeSeries instance. 
                         Could not find the 'time_series' key  
                         in the resource:\n\n%s" % time_series)
      end
       
    end
    
    def forecast(input_data=nil)
      # Returns the class prediction and the confidence
      # input_data: Input data to be predicted
      #
      if input_data.nil?
        forecasts = {}
        @_forecast.each do |field_id,value|
          forecasts[field_id] = []
          value.each do |forecast|
            local_forecast = {}
            local_forecast.merge!({"point_forecast" => forecast["point_forecast"]})
            local_forecast.merge!({"model" => forecast["model"]})
            forecasts[field_id] <<  local_forecast
          end  
        end  
        return forecasts
      end
      
      # Checks and cleans input_data leaving only the fields used as
      # objective fields in the model
      new_data = self.filter_objectives(input_data)
      input_data = new_data
      # filter submodels: filtering the submodels in the time-series
      # model to be used in the prediction
      filtered_submodels = {}
      input_data.each do |field_id, field_input|
        filter_info = field_input.fetch("ets_models", {})
        if filter_info.empty?
          filter_info = DEFAULT_SUBMODEL
        end
        filtered_submodels[field_id] = BigML::filter_submodels(@ets_models[field_id], filter_info)
      end  

      forecasts = {}
      
      filtered_submodels.each do |field_id, submodels|
        forecasts[field_id] = BigML::compute_forecasts(submodels,input_data[field_id]["horizon"])
      end
        
      return forecasts
      
     end
     
     def filter_objectives(input_data, full=false)
       # Filters the keys given in input_data checking against the
       # objective fields in the time-series model fields.
       # If `full` is set to True, it also
       # provides information about the fields that are not used.
       #

       unused_fields = []
       new_input = {}
       if input_data.is_a?(Hash)
         
         input_data.each do |key, value|
           if !@fields.include?(key)
             key = @inverted_fields.fetch(key, key)
           end
           
           if @fields.include?(key)
             new_input[key] = value
           else
             unused_fields << key
           end  
           
         end
         
         input_data.each do|key,value|
           value = self.normalize(value)
           if !value.is_a?(Hash)
             raise ArgumentError.new("Each field input data needs to be specified 
                                 as a dictionary. Found %s for field %s." % [a.class.to_s, key])
           end 
           
           if !value.key?(REQUIRED_INPUT)
             raise ArgumentError.new("Each field in input data must contain at 
                                 least a \"horizon\" attribute.")
           end
           
           if value.fetch("ets_models", {}).keys().any? {|k| !SUBMODEL_KEYS.include?(k) }
             raise ArgumentError.new("Only %s allowed as keys in each fields submodel filter." % SUBMODEL_KEYS.join(", "))
           end 
         end
         
         return full ? [new_input, unused_fields] : new_input
           
       else
         puts "Failed to read input data in the expected  {field:value} format."
         return full ? [{}, []] : {}
       end
     end
     
     def ruby(out=STDOUT)
       # TODO
     end 
     
  end  
end