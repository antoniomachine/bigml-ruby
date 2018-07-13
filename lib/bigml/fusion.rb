# -*- coding: utf-8 -*-
#!/usr/bin/env python
#
# Copyright 2012-2018 BigML
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

# An local Fusion object.
# This module defines a Fusion to make predictions locally using its
# associated models.
# This module can not only save you a few credits, but also enormously
# reduce the latency for each prediction and let you use your models
# offline.
# 
# @api = BigML::Api.new(nil, nil, false, false, false, STORAGE)
# creating fusion
# fusion = api.create_fusion(['model/5143a51a37203f2cf7000972',
#                            'model/5143a51a37203f2cf7000985'])
# Fusion object to predict
# fusion = BigML::Fusion(fusion, @api)
# fusion.predict({"petal length" => 3, "petal width" => 1})
#
require_relative 'resourcehandler'
require_relative 'multimodel'
require_relative 'supervised'

module BigML
  
  OPERATING_POINT_KINDS_FUSION = ["probability"]
  LOCAL_SUPERVISED = ["model", "ensemble", "logisticregression", "deepnet", "fusion"]

  def self.rearrange_prediction(origin_classes, destination_classes, prediction)
    # Rearranges the probabilities in a compact array when the
    # list of classes in the destination resource does not match the
    # ones in the origin resource.
    new_prediction = []
    destination_classes.each do |class_name|
       origin_index = origin_classes.index(class_name)
       if origin_index > -1
         new_prediction << prediction[origin_index]
       else
         new_prediction = 0.0
       end 
    end  
  
    return new_prediction
  end
  
  def self.get_models_weight(models_info)
    # arses the information about model ids and weights in the `models`
    #    key of the fusion dictionary. The contents of this key can be either
    # list of the model IDs or a list of dictionaries with one entry per
    # model
    model_ids = []
    weights = []
    begin
      model_info = models_info[0]
      if model_info.is_a?(Hash)
        begin
          model_ids = models_info.map {|model| model["id"] }
        rescue KeyError => e
          raise ArgumentError, "The fusion information does not contain the model ids."
        end  
        
        begin
           weights = models_info.map{|model| model["weight"]}
        rescue KeyError => e
          weights = nil
        end  
      else
        model_ids = models_info
        weights = nil
      end  
      return model_ids, weights
    rescue KeyError => e
      raise ArgumentError, "Failed to find the models in the fusion info."
    end  
  end  
  
  class Fusion < ModelFields
    # A local predictive Fusion.
    #   Uses a number of BigML remote models to build local version of a fusion
    #   that can be used to generate predictions locally.
    #   The expected arguments are:
    #   fusion: fusion object or id
    #   api: connection object. If None, a new connection object is
    #        instantiated.
    #   max_models: integer that limits the number of models instantiated and
    #               held in memory at the same time while predicting. If None,
    #               no limit is set and all the fusion models are
    #               instantiated and held in memory permanently.
    #   cache_get: user-provided function that should return the JSON
    #              information describing the model or the corresponding
    #              Model object. Can be used to read these objects from a
    #              cache storage.
    #
    attr_accessor :model_ids, :regression
    
    def initialize(fusion, api=nil, max_models=nil)
      if api.nil?
         @api = BigML::Api.new(nil, nil, false, false, false, STORAGE)
      else
         @api = api
      end
      
      @resource_id = nil 
      @models_ids = nil
      @objective_id = nil 
      @distribution = nil 
      @models_splits = []
      @cache_get = nil
      @regression = false
      @fields = nil
      @class_names= nil
      
      @resource_id, fusion = BigML::get_resource_dict(fusion, "fusion", @api)
      if fusion.key?("object")
        fusion = fusion.fetch("object", {})
      end
      
      @model_ids, @weights = BigML::get_models_weight(fusion['models'])
      model_types = @model_ids.collect{|model| BigML::get_resource_type(model)}
      
      model_types.each do |model_type|
        if !LOCAL_SUPERVISED.include?(model_type)
          raise ArgumentError, 'The resource %s has not an allowed
                                supervised model type.' % model_type
        end
      end
      
      @importance = fusion.fetch("importance", [])
      @missing_numerics = fusion.fetch("missing_numerics", true)
      
      if fusion.key?("fusion")
        @fields = fusion.fetch("fusion", {}).fetch("fields")
        @objective_id = fusion.fetch("objective_field") 
      end  
      
      number_of_models = @model_ids.size
      if max_models.nil?
        @models_splits = [@model_ids]
      else
        @models_splits = (0..(number_of_models-1)).step(max_models).map{|index| @model_ids[index..(index+max_models-1)]}
      end
                                
      
      if !@fields.nil?
        summary = @fields[@objective_id]['summary']
        if summary.key?("bins")
          distribution = summary['bins']
        elsif summary.key?("counts")
          distribution = summary['counts']
        elsif  summary.key?("categories")
          distribution = summary['categories']
        else
          distribution =[]
        end
        
        @distribution = distribution
        
      end  
      
      @regression = @fields[@objective_id].fetch('optype', nil) == 'numeric'
      
      if !@regression
        objective_field = @fields[@objective_id]
        categories = objective_field['summary']['categories']
        @class_names = categories.map{|category| category[0]}.sort
        @objective_categories = @fields[@objective_id]['summary']['categories'].map{|it| it[0]}
      end  
      
      super(@fields, @objective_id)
                     
    end
    
    def get_fusion_resource(fusion)
      # Extracts the fusion resource info. The fusion argument can be
      #   - a path to a local file
      #   - an fusion id
      
      # the string can be a path to a JSON file
      if fusion.is_a?(String)
        begin
          @resource_id = BigML::get_fusion_id(fusion)
          if @resource_id.nil?
            if fusion.index('fusion/') > -1
              raise Exception, @api.error_message(fusion, 'fusion', 'get')
            else
              raise Exception, "Failed to open the expected JSON file at %s" % fusion
            end  
          end  
        rescue 
          raise Exception, "Failed to interpret %s JSON file expected." % fusion
        end  
      end  
      
      if !fusion.is_a?(Hash)
        fusion = BigML::retrieve_resource(@api, @resource_id, false)
      end
      
      return fusion
    end
    
    def list_models
      # Lists all the model/ids that compound the fusion.
      return @model_ids
    end
    
    def predict_probability(input_data, options={})
       return _predict_probability(input_data,
                                   options.fetch("missing_strategy", BigML::LAST_PREDICTION),
                                   options.fetch("compact",false))
    end
    
    def _predict_probability(input_data,
                            missing_strategy=BigML::LAST_PREDICTION,
                            compact=false)
      # For classification models, Predicts a probability for
      # each possible output class, based on input values.  The input
      # fields must be a dictionary keyed by field name or field ID.
      # For regressions, the output is a single element list
      # containing the prediction.
      # :param input_data: Input data to be predicted
      # :param missing_strategy: LAST_PREDICTION|PROPORTIONAL missing strategy
      #                          for missing fields
      # param compact: If False, prediction is returned as a list of maps, one
      #                per class, with the keys "prediction" and "probability"
      #                mapped to the name of the class and it's probability,
      #                respectively.  If True, returns a list of probabilities
      #                ordered by the sorted order of the class names.
      #
      
      votes = MultiVoteList.new([])
      if !@missing_numerics
         BigML::Util::check_no_missing_numerics(input_data, @fields)
      end

      @models_splits.each do |models_split|
        models = []
        models_split.each do |model|
          if BigML::get_resource_type(model) == "fusion"
            models << BigML::Fusion.new(model, @api)
          else
            models << BigML::SupervisedModel.new(model, @api)
          end    
        end
        
        votes_split=[]
        
        models.each do |model|
          begin
          prediction = model.predict_probability(
                              input_data,
                              {"missing_strategy" => missing_strategy, "compact" => true})
          rescue
            next
          end
          if @regression
            prediction = prediction[0]
            if !@weights.nil?
              prediction = self.weigh(prediction, model.resource_id)
            end  
          else
            # we need to check that all classes in the fusion
            # are also in the composing model
            if !@weights.nil?
              prediction = self.weigh(prediction, model.resource_id)
            end 
            
            if !@regression and @class_names != model.class_names
              begin
                prediction = BigML::rearrange_prediction(model.class_names,
                                                         @class_names,
                                                         prediction)
              rescue
                # class_names should be defined, but just in case
              end
            end  
          end
          
          votes_split <<  prediction
          
        end
        votes.extend(votes_split)
        
      end
      
      if @regression
        total_weight =  @weights.nil? ? 1 : @weights.sum
        
        prediction = ((votes.predictions.map{|prediction| prediction}.sum) / votes.predictions.size.to_f)
        
        prediction = (votes.predictions.map{|prediction| prediction}.sum) / votes.predictions.size.to_f*total_weight

        if compact
          output = [prediction]
        else
          output = {"prediction" => prediction}
        end    
      else
        output = votes.combine_to_distribution(true)
        if !compact
          output = @class_names.zip(output).map{|class_name, probability| {'category' => class_name,
                                                                           'probability' => probability} }
        end  
      end
      
      return output
    end
    
    def weigh(prediction, model_id)
      # Weighs the prediction according to the weight associated to the
      # current model in the fusion.
      #
      if prediction.is_a?(Array)
        prediction.each_with_index do |probability, index|
          probability*= @weights[@model_ids.index(model_id)]
          prediction[index] = probability
        end   
      else
        prediction = @weights[@model_ids.index(model_id)]
      end 
      
      return prediction
    end
          
    def predict(input_data, options={})
      # Makes a prediction based on a number of field values.
      # input_data: Input data to be predicted
      #  missing_strategy: LAST_PREDICTION|PROPORTIONAL missing strategy for
      #                    missing fields
      #  operating_point: In classification models, this is the point of the
      #                   ROC curve where the model will be used at. The
      #                   operating point can be defined in terms of:
      #                   - the positive_class, the class that is important to
      #                     predict accurately
      #                   - the probability_threshold,
      #                     the probability that is stablished
      #                     as minimum for the positive_class to be predicted.
      #                   The operating_point is then defined as a map with
      #                   two attributes, e.g.:
      #                     {"positive_class": "Iris-setosa",
      #                      "probability_threshold": 0.5}
      #  full: Boolean that controls whether to include the prediction's
      #        attributes. By default, only the prediction is produced. If set
      #        to True, the rest of available information is added in a
      #        dictionary format. The dictionary keys can be:
      #            - prediction: the prediction value
      #            - probability: prediction's probability
      #            - unused_fields: list of fields in the input data that
      #                             are not being used in the model
      
      # Checks and cleans input_data leaving the fields used in the model
      
      unused_fields = []
      full = options.key?("full") ? options["full"] : false
      new_data = self.filter_input_data(input_data, full)
      if full
        input_data,  unused_fields = new_data
      else
        input_data = new_data
      end 
      
      if !@missing_numerics
         BigML::Util::check_no_missing_numerics(input_data, @fields)
      end
      
      # Strips affixes for numeric values and casts to the final field type
      BigML::Util::cast(input_data, @fields)
      
                   
      full_prediction = _predict(input_data,
                                 options.key?("missing_strategy") ? options["missing_strategy"] : BigML::LAST_PREDICTION,
                                 options.key?("operating_point") ? options["operating_point"] : nil,
                                 options.key?("unused_fields") ? options["unused_fields"] : nil)
      
      if full
        return full_prediction.select {|key, value| !value.nil?}
      end
      
      return full_prediction['prediction']
    end  
    
    def _predict(input_data, missing_strategy=BigML::LAST_PREDICTION,
                 operating_point=nil, unused_fields=nil)
       # Makes a prediction based on a number of field values. Please,
       # note that this function does not check the types for the input
       # provided, so it's unsafe to use it directly without prior checking.
       #
       
       # When operating_point is used, we need the probabilities
       # of all possible classes to decide, so se use
       # the `predict_probability` method
       
       if !operating_point.nil?
         if @regression
           raise ArgumentError, "The operating_point argument can only 
                                 be used in classifications."
         end 
         
         return self.predict_operating(input_data,
                                       missing_strategy,
                                       operating_point)
       end
       
       result = self._predict_probability(input_data, 
                                          missing_strategy,
                                          false)
       if !@regression
         result = result.sort_by{|x| -x["probability"]}[0]
         result["prediction"] = result["category"]
         result.delete("category")
       end
       
       # adding unused fields, if any
       if unused_fields
         result.merge!({'unused_fields' => unused_fields})
       end
       
       return result
    end
    
    def predict_operating(input_data, missing_strategy=BigML::PREDICTION, operating_point={})
      # Computes the prediction based on a user-given operating point.
      
      # only probability is allowed as operating kind
      operating_point.merge!({"kind" => "probability"})
      
      kind, threshold, positive_class = BigML::parse_operating_point(operating_point, 
                                              OPERATING_POINT_KINDS_FUSION, @class_names)
                                              
      predictions = self._predict_probability(input_data, missing_strategy, false)
      position = @class_names.index(positive_class)
      
      if predictions[position][kind] > threshold
        prediction = predictions[position]
      else
        # if the threshold is not met, the alternative class with
        # highest probability or confidence is returned
        
        prediction = predictions.sort_by {|p| [-p[kind], p['category']]}[0..1]
        if prediction[0]["category"] == positive_class
            prediction = prediction[1]
        else
            prediction = prediction[0]
        end
      end
      
      prediction["prediction"] = prediction["category"]
      prediction.delete("category")
      
      return prediction
                
    end  
  
    
  end  
end