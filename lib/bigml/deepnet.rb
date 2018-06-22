# encoding: utf-8

# A local Predictive Deepnet.
# This module defines a Deepnet to make predictions locally or
# embedded into your application without needing to send requests to
# BigML.io.
# This module cannot only save you a few credits, but also enormously
# reduce the latency for each prediction and let you use your models
# offline.
# You can also visualize your predictive model in IF-THEN rule format
# and even generate a python function that implements the model.
# Example usage (assuming that you have previously set up the BIGML_USERNAME
# and BIGML_API_KEY environment variables and that you own the model/id below):
#
# require "bigml"
# require "deepnet"
# 
# api = BigML::api.new()
# deepnet = BigML::Deepnet.new('deepnet/5026965515526876630001b2')
# deepnet.predict({"petal length" => 3, "petal width"=> 1})
#
require_relative 'model'
require_relative 'laminar/preprocess_np'
require_relative 'laminar/math_ops'

module BigML
  
  MEAN = "mean"
  STANDARD_DEVIATION = "stdev"

  def self.moments(amap)
    return amap[MEAN], amap[STANDARD_DEVIATION]
  end

  def self.expand_terms(terms_list, input_terms)
    #
    #Builds a list of occurrences for all the available terms
    #
  
    terms_occurrences = [0.0] * terms_list.size
  
    input_terms.each do|term,occurrences|
      index = terms_list.index(term)
      terms_occurrences[index] = occurrences
    end   
  
    return terms_occurrences

  end

  class Deepnet < ModelFields
    #
    # A lightweight wrapper around Deepnet model.
    # Uses a BigML remote model to build a local version that can be used
    # to generate predictions locally.
    #
   
    attr_accessor :regression
    
    def initialize(deepnet, api=nil)
      # The Deepnet constructor can be given as first argument:
      #            - a deepnet structure
      #            - a deepnet id
      #            - a path to a JSON file containing a deepnet structure
    
      @resource_id = nil
      @regression = false
      @network = nil
      @networks = nil
      @input_fields = []
      @class_names = []
      @preprocess = []
      @optimizer = nil
      @missing_numerics = false
      
      if api.nil?
        api = BigML::Api.new(nil, nil, false, false, false, STORAGE)
      end  
    
      if deepnet.is_a?(String)
        if File.file?(deepnet)
          File.open(deepnet, "r") do |f|
              deepnet = JSON.parse(f.read)
          end
          @resource_id =  BigML::get_deepnet_id(deepnet)
          if @resource_id.nil?
             raise ArgumentError, "The JSON file does not seem to contain a valid BigML deepnet representation"
          end
        else 
          @resource_id =  BigML::get_deepnet_id(deepnet)
          if @resource_id.nil?
            if !model.index('deepnet/').nil?
                raise Exception, api.error_message(deepnet, 'deepnet', 'get')
            else
                raise Exception, "Failed to open the expected JSON file at %s" % [deepnet]
            end
          end 
        end 
      end
    
      # checks whether the information needed for local predictions is in
      # the first argument
      if deepnet.is_a?(Hash) and !BigML::check_model_fields(deepnet)
         # if the fields used by the deepenet are not
         # available, use only ID to retrieve it again
         deepnet = BigML::get_deepnet_id(deepnet)
         @resource_id = deepnet
      end
      
      if !(deepnet.is_a?(Hash) and deepnet.key?('resource') and !deepnet['resource'].nil?) 
         query_string = ONLY_MODEL
         deepnet = BigML::retrieve_resource(api, @resource_id, query_string)
      else
         @resource_id =  BigML::get_deepnet_id(deepnet)
      end
    
      if deepnet.key?('object') and deepnet['object'].is_a?(Hash)
         deepnet = deepnet['object']
      end
      
      @input_fields = deepnet['input_fields']
       
      if deepnet.key?("deepnet") and deepnet['deepnet'].is_a?(Hash)
         status = BigML::Util::get_status(deepnet)
         objective_field = deepnet['objective_fields']
         deepnet = deepnet['deepnet']
         if status.key?('code') and status['code'] == FINISHED
            @fields = deepnet['fields']
            super(@fields, BigML::extract_objective(objective_field), nil, nil, true, true)
            
            @regression = @fields[@objective_id]['optype'] == BigML::Laminar::NUMERIC
          
            if !@regression
              @class_names = @fields[@objective_id]['summary']['categories'].map{|it|it[0]}.sort
              @objective_categories = @fields[@objective_id]['summary']['categories'].map{|it|it[0]}
            end  
          
            @missing_numerics = deepnet.fetch('missing_numerics', false)
          
            if deepnet.key?("network")
              network = deepnet['network']
              @network = network
              @networks = network.fetch('networks', [])
              @preprocess = network.fetch('preprocess')
              @optimizer = network.fetch('optimizer', {})
            end  
                              
         else
           raise Exception, "The deepnet isn't finished yet"
         end    
      else 
        raise Exception, "Cannot create the Deepnet instance. Could not find
                         the 'deepnet' key in the resource:\n\n%s" % deepnet   
      end   
      
    end
    
    def fill_array(input_data, unique_terms)
      #
      # Filling the input array for the network with the data in the
      # input_data dictionary. Numeric missings are added as a new field
      #and texts/items are processed.
      #
      columns=[]
      @input_fields.each do|field_id,value|
        # if the field is text or items, we need to expand the field
        # in one field per term and get its frequency
        if @tag_clouds.key?(field_id)
          terms_occurrences = BigML::expand_terms(@tag_clouds[field_id],
                                                  unique_terms.fetch(field_id,[]))
          columns+=terms_occurrences
          
        elsif @items.key?(field_id)
          terms_occurrences = BigML::expand_terms(@items[field_id],
                                                  unique_terms.fetch(field_id,[]))
          columns+=terms_occurrences
        elsif @categories.key?(field_id)
          category = unique_terms.fetch(field_id, nil)
          
          if !category.nil?
            category = category[0][0]
          end
          columns << [category]
        else
          # when missing_numerics is True and the field had missings
          # in the training data, then we add a new "is missing?" element
          # whose value is 1 or 0 according to whether the field is
          # missing or not in the input data
          
          if @missing_numerics and @fields[field_id]["summary"]["missing_count"] > 0
            if input_data.key?(field_id)
              columns+=[input_data[field_id], 0.0]
            else 
              columns+=[0.0, 1.0]
            end  
          else
            columns << input_data.fetch(field_id, nil)
          end  
        end      
      end 
      return BigML::Laminar.preprocess(columns, @preprocess)
    end
    
    def predict(input_data, options={})
      return _predict(input_data,
                     options.key?("operating_point") ? options["operating_point"] : nil,
                     options.key?("operating_kind") ? options["operating_kind"] : nil,
                     options.key?("full") ? options["full"] : false)
    end 
    
    def _predict(input_data, operating_point=nil, operating_kind=nil, full=false)
      # Makes a prediction based on a number of field values.
      # input_data: Input data to be predicted
      # operating_point: In classification models, this is the point of the
      #                 ROC curve where the model will be used at. The
      #                 operating point can be defined in terms of:
      #                 - the positive_class, the class that is important to
      #                   predict accurately
      #                 - the probability_threshold,
      #                   the probability that is stablished
      #                   as minimum for the positive_class to be predicted.
      #                 The operating_point is then defined as a map with
      #                 two attributes, e.g.:
      #                   {"positive_class": "Iris-setosa",
      #                    "probability_threshold": 0.5}
      # operating_kind: "probability". Sets the
      #                property that decides the prediction. Used only if
      #                no operating_point is used
      #
      # full: Boolean that controls whether to include the prediction's
      #             attributes. By default, only the prediction is produced. If set
      #             to True, the rest of available information is added in a
      #              dictionary format. The dictionary keys can be:
      #                  - prediction: the prediction value
      #                  - probability: prediction's probability
      #                  - unused_fields: list of fields in the input data that
      #                                   are not being used in the model
      
      
      # Checks and cleans input_data leaving the fields used in the model
      unused_fields = []
      new_data = self.filter_input_data(input_data, full)
      
      if full
          input_data, unused_fields = new_data
      else
          input_data = new_data
      end
      
      # Strips affixes for numeric values and casts to the final field type
      BigML::Util::cast(input_data, @fields)
      
      # When operating_point is used, we need the probabilities
      # of all possible classes to decide, so se use
      # the `predict_probability` method
      
      if !operating_point.nil?
        
        if @regression
          raise ArgumentError.new("The operating_point argument can only be used in classifications.")
        end
        
        return self.predict_operating(input_data, operating_point)
      end
      
      if !operating_kind.nil?
        
        if @regression
          raise ArgumentError.new("The operating_point argument can only be used in classifications.")
        end
        
        return self.predict_operating_kind(input_data, operating_kind)
      end
      
      # Computes text and categorical field expansion
      unique_terms = self.get_unique_terms(input_data)

      input_array = self.fill_array(input_data, unique_terms)
      
      if !@networks.nil? && !@networks.empty?
        prediction = self.predict_list(input_array)
      else
        prediction = self.predict_single(input_array)
      end
          
      if full
        if !prediction.is_a?(Hash)
          prediction = {"prediction" => prediction}
        end
        
        prediction.merge({"unused_fields" => unused_fields})
      else
        if prediction.is_a?(Hash)
          prediction = prediction["prediction"]  
        end  
      end
      
      return prediction
                
    end
    
    def predict_single(input_array)
      #
      # Makes a prediction with a single network
      #
      
      if !@network['trees'].nil?
        input_array = BigML::Laminar.tree_transform(input_array, @network['trees'])
      end

      return self.to_prediction(self.model_predict(input_array,
                                                   @network))
    end
    
    def predict_list(input_array)
      
      if !@network['trees'].nil?
        input_array_trees = BigML::Laminar.tree_transform(input_array,
                                                          @network['trees'])
      end
      
      youts = []
      @networks.each do|model|
        if !model.fetch('trees', nil).nil?
          youts << self.model_predict(input_array_trees, model)
        else  
          youts << self.model_predict(input_array, model)
        end  
      end
      
      return self.to_prediction(BigML::Laminar.sum_and_normalize(youts,
                                                                 @regression))
    end
    
    def model_predict(input_array, model)
      #
      # Prediction with one model
      #
      layers = BigML::Laminar.init_layers(model['layers'])

      y_out = BigML::Laminar.propagate(input_array, layers)

      if @regression
        y_mean, y_stdev = BigML::moments(model['output_exposition'])
        y_out = BigML::Laminar.destandardize(y_out, y_mean, y_stdev)
        return y_out[0][0]
      end
        
      return y_out
    end
    
    def to_prediction(y_out)
      #
      # Structuring prediction in a dictionary output
      #
      if @regression
        return y_out.to_f
      end    

      prediction = y_out[0].each_with_index.map { |n,i| [i,n] }.sort_by {|x| -x[1]}[0]

      prediction = {"prediction" => @class_names[prediction[0]],
                    "probability" => prediction[1].round(BigML::Util::PRECISION),
                    "distribution" => @class_names.each_with_index.map {|category,i| {"category" => category, 
                                                  "probability" => y_out[0][i].round(BigML::Util::PRECISION) }}}

      return prediction
    end
    
    def predict_probability(input_data, options={})
      return _predict_probability(input_data, options.fetch("compact", false))
    end
    
    def _predict_probability(input_data, compact=false)
      # Predicts a probability for each possible output class,
      # based on input values.  The input fields must be a dictionary
      # keyed by field name or field ID.
      # :param input_data: Input data to be predicted
      # :param compact: If False, prediction is returned as a list of maps, one
      #                per class, with the keys "prediction" and "probability"
      #                mapped to the name of the class and it's probability,
      #                respectively.  If True, returns a list of probabilities
      #                ordered by the sorted order of the class names.
      #
      
      if @regression
        return self.predict(input_data, nil, nil, true)
        prediction = self.predict(input_data, {"full" => !compact})
        if compact
          return [prediction]
        else
          return prediction
        end    
      else
        distribution = self.predict(input_data, {"full" => true})['distribution']

        distribution.sort_by!{|x| x['category']}
        
        if compact
          return distribution.map{|category| category['probability']}
        else
          return distribution  
        end  
        
      end    
    end
    
    def _sort_predictions(a, b, criteria)
      # Sorts the categories in the predicted node according to the
      # given criteria
      # 
      if a[criteria] == b[criteria]
          return sort_categories(a, b, self.objective_categories)
      end
          
      return (b[criteria] > a[criteria]) ? 1 : - 1
    end
    
    def predict_operating_kind(input_data, operating_kind=nil)
      #Computes the prediction based on a user-given operating kind.

      kind = operating_kind.downcase
      
      if kind == "probability"
          predictions = self._predict_probability(input_data, false)
      else
          raise ArgumentError.new("Only probability is allowed as operating kind for deepnets.")
      end

      prediction =  predictions.sort_by {|p| [-p[kind], p['category']]}[0]
      
      prediction["prediction"] = prediction["category"]
      prediction.delete("category")
      return prediction
    end
    
    def predict_operating(input_data, operating_point=nil)
      # Computes the prediction based on a user-given operating point.
      #
      kind, threshold, positive_class = BigML::parse_operating_point(
                    operating_point, ["probability"], @class_names)
          
      predictions = self._predict_probability(input_data, false)
      
      position = @class_names.index(positive_class)
      if predictions[position][kind] > threshold
        prediction = predictions[position]
      else
        # if the threshold is not met, the alternative class with
        # highest probability or confidence is returned
        prediction =  predictions.sort_by {|p| [-p[kind], p['category']]}[0..1]
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