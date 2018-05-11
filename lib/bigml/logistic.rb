# encoding: utf-8
#
# Copyright 2014-2016 BigML
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

#require_relative 'util'

EXPANSION_ATTRIBUTES = {"categorical" => "categories", 
                        "text" => "tag_cloud",
                       "items" => "items"}

require_relative 'resourcehandler'
require_relative 'util'
require_relative 'model'
require_relative 'predicate'
require_relative 'modelfields'
require_relative 'cluster'

module BigML
   
   def self.balance_input(input_data, fields)
     # Balancing the values in the input_data using the corresponding
     # field scales
     #
     input_data.each do |field, value|
       if fields[field]['optype'] == 'numeric'
          mean = fields[field]['summary'].fetch('mean', 0)
          stddev = fields[field]['summary'].fetch('standard_deviation',0)
          
          if mean.nil?
            mean=0
          end
          
          if stddev.nil?
            stddev=0
          end  
          # if stddev is not positive, we only substract the mean
          input_data[field] = (stddev <=0) ? (input_data[field] - mean) : 
                                   (input_data[field] - mean) / stddev
       end
     end
   end

   class Logistic < ModelFields
      # A lightweight wrapper around a logistic regression model.

      # Uses a BigML remote logistic regression model to build a local version
      # that can be used to generate predictions locally.

      def initialize(logistic_regression, api=nil)
         @resource_id = nil
         @class_names = nil
         @input_fields = []
         @term_forms = {}
         @tag_clouds = {}
         @term_analysis = {}
         @items = {}
         @item_analysis = {}
         @categories = {}
         @coefficients = {}
         @data_field_types = {}
         @field_codings = {}
         @numeric_fields = {}
         @bias = nil
         @missing_numerics = nil
         @c = nil
         @eps = nil
         @lr_normalize = nil
         @balance_fields = nil
         @regularization = nil
         old_coefficients = false

         # checks whether the information needed for local predictions is in
         # the first argument
         if logistic_regression.is_a?(Hash)  and !BigML::check_model_fields(logistic_regression)
           # if the fields used by the logistic regression are not
           # available, use only ID to retrieve it again
           logistic_regression = BigML::get_logistic_regression_id(logistic_regression)
           @resource_id = logistic_regression
         end

         if !(logistic_regression.is_a?(Hash) and 
             logistic_regression.include?('resource') and
              !logistic_regression['resource'].nil?)

            if api.nil?
               api = BigML::Api.new(nil, nil, false, false, false, BigML::STORAGE)
            end

            @resource_id = BigML::get_logisticregression_id(logistic_regression)
            if @resource_id.nil?
                raise Exception,
                    api.error_message(logistic_regression,
                                      'logistic_regression',
                                      'get')
            end
            query_string = BigML::ONLY_MODEL
            logistic_regression = BigML::retrieve_resource(
                api, @resource_id, query_string)
            
         else
            @resource_id = BigML::get_logisticregression_id(logistic_regression)
         end

         if logistic_regression.include?('object') and 
             logistic_regression['object'].is_a?(Hash) 
           logistic_regression = logistic_regression['object']
         end
 
         begin
            @input_fields =  logistic_regression.fetch("input_fields", [])
            @dataset_field_types =  logistic_regression.fetch("dataset_field_types", {})
            if !logistic_regression['objective_fields'].nil?
               objective_field = logistic_regression['objective_fields']
            else
               objective_field = logistic_regression['objective_field']
            end

         rescue Exception
            raise ArgumentError, "Failed to find the logistic regression expected
                                JSON structure. Check your arguments."
         end
 
         if logistic_regression.include?('logistic_regression') and 
               logistic_regression['logistic_regression'].is_a?(Hash)

            status = BigML::Util::get_status(logistic_regression)
            if status.include?('code') and status['code'] == FINISHED
              logistic_regression_info = logistic_regression['logistic_regression']
              fields = logistic_regression_info.fetch('fields', {})

              if @input_fields.nil? or @input_fields.empty?
                 @input_fields = @fields.sort_by {|field_id,x|  
                                      x["column_number"] }.collect {|field_id,v| field_id}
              end

              @coefficients = {}

              logistic_regression_info.fetch('coefficients', []).each do |c|
                 @coefficients[c[0]] = c[1]
              end

              if !@coefficients.values()[0][0].is_a?(Array)
                  old_coefficients = true
              end

              @bias = logistic_regression_info.fetch('bias', true)
              @c = logistic_regression_info.fetch('c')
              @eps = logistic_regression_info.fetch('eps')
              @lr_normalize = logistic_regression_info.fetch('normalize')
              @balance_fields = logistic_regression_info.fetch('balance_fields')
              @regularization = logistic_regression_info.fetch('regularization')

              @field_codings = logistic_regression_info.fetch('field_codings', {})
              # old models have no such attribute, so we set it to False in
              # this case
              @missing_numerics = logistic_regression_info.fetch('missing_numerics', false)
              objective_id = BigML::extract_objective(objective_field)
                                  
              super(fields, objective_id, nil, nil, true, true, true)
               
              @field_codings = logistic_regression_info.fetch('field_codings', {})
              format_field_codings() 
              @field_codings.each do |field_id|
                 if (!fields.include?(field_id) and 
                      @inverted_fields.include?(field_id))
                   @field_codings[@inverted_fields[field_id]] = @field_codings[field_id].clone
                   @field_codings.delete(field_id)
                 end
              end

              if old_coefficients
                 map_coefficients()
              end
              
              categories =@fields[@objective_id].fetch("summary", {}).fetch('categories')

              if @coefficients.keys.size > categories.size
                @class_names = [""]
              else
                @class_names = []
              end    
              
              @class_names += categories.collect {|category| category[0]}.sort
              

            else
               raise Exception, "The logistic regression isn't finished yet"
            end
         else
            raise Exception, "Cannot create the LogisticRegression instance.
                             Could not find the 'logistic_regression' key
                             in the resource:\n\n%s" % logistic_regression
         end

      end
      
      def _sort_predictions(a, b, criteria)
        # Sorts the categories in the predicted node according to the
        # given criteria
      
        if a[criteria] == b[criteria]
          return sort_categories(a, b, @objective_categories)
        end  
        
        return  b[criteria] > a[criteria] ? 1 : - 1
      
      end

      def predict_probability(input_data, compact=false)
        
        # Predicts a probability for each possible output class,
        # based on input values.  The input fields must be a dictionary
        # keyed by field name or field ID.
        # :param input_data: Input data to be predicted
        # input_data dict
        # :param compact: If False, prediction is returned as a list of maps, one
        # per class, with the keys "prediction" and "probability"
        # mapped to the name of the class and it's probability,
        # respectively.  If True, returns a list of probabilities
        # ordered by the sorted order of the class names.
        distribution = self.predict(input_data, {"full" => true})['distribution']
        distribution = distribution.sort_by{|x| x['category']}
        
        if compact
          return distribution.collect {|category| category['probability']}
        else
          return distribution
        end
        
      end
      
      def predict_operating(input_data,
                            operating_point=nil)
        #                    
        # Computes the prediction based on a user-given operating point.
        #

        kind, threshold, positive_class = BigML::parse_operating_point(
            operating_point, ["probability"], @class_names)
            
        predictions = self.predict_probability(input_data, false)
        
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
      
      def predict_operating_kind(input_data,
                                 operating_kind=nil)
        #
        # Computes the prediction based on a user-given operating kind.
        #
      
        kind = operating_kind.downcase
        
        if kind == "probability"
            predictions = self.predict_probability(input_data,
                                                   false)
        else
          raise ArgumentError.new("Only probability is allowed as operating kind
                              for logistic regressions.")
        end
        
        prediction = predictions.sort_by {|p| [-p[kind], p['category']]}[0]
        
        prediction["prediction"] = prediction["category"]
        prediction.delete("category")
        
        return prediction
     end
     
     def predict(input_data, options={})
       return _predict(input_data,
                      options.key?("operating_point") ? options["operating_point"] : nil,
                      options.key?("operating_kind") ? options["operating_kind"] : nil,
                      options.key?("full") ? options["full"] : false)
     end 
      
     def _predict(input_data, operating_point=nil, operating_kind=nil, full=false)
         #
         # Returns the class prediction and the probability distribution
         # By default the input fields must be keyed by field name but you can use
         # `by_name` to input them directly keyed by id.
         
         # input_data: Input data to be predicted
         # operating_point: In classification models, this is the point of the
         #                          ROC curve where the model will be used at. The
         #                          operating point can be defined in terms of:
         #                          - the positive_class, the class that is important to
         #                            predict accurately
         #                          - the probability_threshold,
         #                            the probability that is stablished
         #                            as minimum for the positive_class to be predicted.
         #                          The operating_point is then defined as a map with
         #                          two attributes, e.g.:
         #                            {"positive_class": "Iris-setosa",
         #                             "probability_threshold": 0.5}
         # operating_kind: "probability". Sets the
         #                  property that decides the prediction. Used only if
         #                 no operating_point is used
         #  full: Boolean that controls whether to include the prediction's
         #              attributes. By default, only the prediction is produced. If set
         #              to True, the rest of available information is added in a
         #              dictionary format. The dictionary keys can be:
         #                  - prediction: the prediction value
         #                  - probability: prediction's probability
         #                  - distribution: distribution of probabilities for each
         #                                  of the objective field classes
         #                  - unused_fields: list of fields in the input data that
         #                                   are not being used in the model
         # Checks and cleans input_data leaving the fields used in the model
         unused_fields = []
         new_data = filter_input_data(input_data, full)
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
            return self.predict_operating(input_data, operating_point)
         end
         
         if !operating_kind.nil?
           return self.predict_operating_kind(input_data, operating_kind)
         end 

         # In case that missing_numerics is False, checks that all numeric
         # fields are present in input data.
         if @missing_numerics == false
            @fields.each do |field_id, field|
               if !OPTIONAL_FIELDS.include?(field['optype']) and 
                  !input_data.include?(field_id)
                  raise Exception, "Failed to predict. Input 
                                  data must contain values for all numeric
                                  fields to get a logistic regression prediction."
               end      
            end 

         end

         if !@balance_fields.nil? and @balance_fields
           BigML::balance_input(input_data, @fields)
         end

         # Compute text and categorical field expansion
         unique_terms = get_unique_terms(input_data)
         probabilities = {}
         total = 0
         # Computes the contributions for each category
         @coefficients.keys.each do |category|
           
            probability = category_probability(input_data,
                                         unique_terms, category)
            begin   
              order = @categories[@objective_id].index(category)
              order
            rescue
              if category == ""
                 order =  @categories[@objective_id].size
              end    
            end
            probabilities[category] = {"category" => category,
                                       "probability" => probability, 
                                       "order" => order} 

            total += probabilities[category]["probability"]
                             
         end
         
         # Normalizes the contributions to get a probability
         probabilities.keys.each do |category| 
           probabilities[category]["probability"] /= total
           probabilities[category]["probability"]=probabilities[category]["probability"].round(BigML::Util::PRECISION) 
         end
         
         # Chooses the most probable category as prediction
         predictions = probabilities.sort_by {|i,x| [x["probability"],-x["order"]] }.reverse


         predictions.each do |prediction, probability|
            probability.delete('order')
         end
         prediction, probability = predictions[0]

         result = {"prediction" => prediction,
                   "probability" => probability["probability"],
                   "distribution" => predictions.collect {|category,probability| 
							  {"category" => category,  
                                                           "probability" => probability["probability"]}}}

         if full
           result['unused_fields'] = unused_fields
         else
           result = result["prediction"]
         end

         return result

      end

      def category_probability(numeric_inputs, unique_terms, category)
         #
         # Computes the probability for a concrete category
         #
         probability = 0
         norm2 = 0
         # numeric input data
         numeric_inputs.each do |field_id, value|
            coefficients = get_coefficients(category, field_id)
            probability += coefficients[0] * numeric_inputs[field_id]
            if @lr_normalize
              norm2 += numeric_inputs[field_id] ** 2
            end  
         end

         unique_terms.each do |field_id, value|
            if @input_fields.include?(field_id)
               coefficients = get_coefficients(category, field_id)
               unique_terms[field_id].each do |term,occurrences|
                
                  begin
                     one_hot = true
                     if @tag_clouds.include?(field_id)
                        index = @tag_clouds[field_id].index{|it| it == term}
                     elsif @items.include?(field_id)
                        index = @items[field_id].index{|it| it == term}
                     elsif  @categories.include?(field_id) and (
                            !@field_codings.include?(field_id) or 
                            @field_codings[field_id].keys[0] == "dummy")
                        index = @categories[field_id].index(term) 
                     elsif @categories.include?(field_id)
                         one_hot = false
                         index = @categories[field_id].index(term)
                         coeff_index = 0
                         @field_codings[field_id].values[0].each do |contribution|
                            probability += coefficients[coeff_index] * 
                                            contribution[index] * occurrences
                            coeff_index += 1
                         end
                     end

                     if one_hot
                        probability += coefficients[index] * occurrences
                     end
                     norm2 += occurrences ** 2
                  #rescue Exception
                  #   next
                  end
               end

            end

         end
         
         # missings
         @input_fields.each do |field_id, value|
           contribution = false
           coefficients = get_coefficients(category, field_id)
           if @numeric_fields.include?(field_id) and 
              !numeric_inputs.include?(field_id)
              probability += coefficients[1]
              contribution=true
           elsif @tag_clouds.include?(field_id) && 
                  (!unique_terms.include?(field_id) or (unique_terms[field_id].nil? or 
                                                        unique_terms[field_id].empty?))
              probability += coefficients[@tag_clouds[field_id].size]
              contribution = true
           elsif @items.include?(field_id) && 
                  (!unique_terms.include?(field_id) or (unique_terms[field_id].nil? or 
                                                        unique_terms[field_id].empty?))
                                      
               probability += coefficients[@items[field_id].size]
               contribution = true
               
           elsif @categories.include?(field_id) && field_id != @objective_id && 
                 !unique_terms.include?(field_id)
             
             if !@field_codings.include?(field_id) or 
                @field_codings[field_id].keys[0] == "dummy"
                probability += coefficients[@categories[field_id].size]
             else
                # codings are given as arrays of coefficients. The
                # last one is for missings and the previous ones are
                # one per category as found in summary
                #
                coeff_index = 0
                @field_codings[field_id].values[0].each do |contribution|
                   probability += coefficients[coeff_index] * contribution[-1]
                   coeff_index += 1
                end 
             end
             
             contribution = true
           end 
           
           if contribution and @lr_normalize
              norm2 += 1
           end
         end 
         
          # the bias term is the last in the coefficients list
         probability += @coefficients[category][@coefficients[category].size - 1][0]
                      
         if @bias
           norm2 += 1
         end

         if !@lr_normalize.nil? and @lr_normalize
            begin 
                probability /= Math.sqrt(norm2)
            rescue 
                # this should never happen
                probability = Float::INFINITY
            end
         end

         begin
            probability = 1 / (1 + Math.exp(-probability))
         rescue 
            probability = probability < 0 ? 0 : 1
         end

         # truncate probability to 5 digits, as in the backend
         probability = probability.round(5)
         
         return probability
 
      end

      def map_coefficients()
         #
         # Maps each field to the corresponding coefficients subarray 
         #
         field_ids = @input_fields.select {|field_id| field_id != @objective_id}
         shift = 0
         field_ids.each do |field_id|
            optype = @fields[field_id]['optype']
            if EXPANSION_ATTRIBUTES.keys.include?(optype)
               # text and items fields have one coefficient per
               # text plus a missing terms coefficient plus a bias
               # coefficient
               # categorical fields too, unless they use a non-default
               # field coding.
               if optype != 'categorical' or @field_coding.include?(field_id) or 
                  @field_codings[field_id].keys[0] == "dummy"
                  length = @fields[field_id]['summary'][EXPANSION_ATTRIBUTES[optype]].size
                  # missing coefficient
                  length += 1
               else
                  length = @field_codings[field_id].values[0]
               end
            else
               # numeric fields have one coefficient and an additional one
               # if self.missing_numerics is True
               length = @missing_numerics ? 2 : 1
            end
            
            @fields[field_id]['coefficients_shift'] = shift
            @fields[field_id]['coefficients_length'] = length
            shift += length
         end

         group_coefficients()

      end

      def get_coefficients(category, field_id)
        # Returns the set of coefficients for the given category and fieldIds
        return  @coefficients[category][@input_fields.index(field_id)]
      end

      def group_coefficients()
         # Groups the coefficients of the flat array in old formats to the
         # grouped array, as used in the current notation
         # 
         coefficients = @coefficients.clone
         @flat_coefficients = coefficients
         coefficients.each do |category|
            @coefficients[category] = []
            @input_fields.each do |field_id|
              shift = @fields[field_id]['coefficients_shift']
              length = @fields[field_id]['coefficients_length']
              coefficients_group = coefficients[category][shift..(length+shift-1)]
              @coefficients[category] << coefficients_group
            end

            @coefficients[category] << [coefficients[category][coefficients[category].size- 1]]
         end

      end

      def format_field_codings()
        #
        # Changes the field codings format to the dict notation
        #
        if @field_codings.is_a?(Array)
           @field_codings_list = @field_codings[0..-1]
           @field_codings = @field_codings[0..-1]
           @field_codings = {}
           @field_codings.each_with_index do |element,index|
              field_id = element['field']
              if element["coding"] == "dummy"
                 @field_codings[field_id] = {element["coding"] => element['dummy_class']}
              else
                 @field_codings[field_id] = {element["coding"] => element['coefficients']}
              end    
           end 

        end
      end
   end

end

