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

#"""A local Predictive Model.   

require_relative 'basemodel'
require_relative 'api' 
require_relative 'tree'
require_relative 'multivote'
require_relative 'path'
require_relative 'util'
require_relative 'boostedtree'

module BigML

   DEFAULT_IMPURITY = 0.2
   OPERATING_POINT_KINDS = ["probability", "confidence"]
   DICTIONARY = "hash"
   OUT_FORMATS = [DICTIONARY, "array"]
   
   def self.init_structure(to)
     # Creates the empty structure to store predictions depending on the
     # chosen format.
     if to.nil? and !OUT_FORMATS.include?(to)
       raise ArgumentError.new("The allowed formats are %s." % OUT_FORMATS.join(", "))
     end
     
     return to == DICTIONARY ? {} : to.nil? ? () : []
    
   end
   
   def self.cast_prediction(full_prediction, to=nil, confidence=false,
                       probability=false,path=false, distribution=false, 
                       count=false, _next=false, d_min=false, d_max=false, 
                       median=false,unused_fields=false)
       # Creates the output filtering the attributes in a full
       # prediction.
       #     to: defines the output format. The current
       #        values are: None, `list` and `dict`. If not set, the result
       #         will be expressed as a tuple. The other two options will
       #         produce a list and a dictionary respectively. In the case of lists,
       #         the attributes are stored in the same order used in
       #         the signature of the function.
       #     confidence: Boolean. If True, adds the confidence to the output
       #    probability: Boolean. If True, adds the probability to the output
       #     path: Boolean. If True adds the prediction path to the output
       #     distribution: distribution of probabilities for each
       #                   of the objective field classes
       #     count: Boolean. If True adds the number of training instances in the
       #            prediction node to the output
       #     next: Boolean. If True adds the next predicate field to the output
       #     d_min: Boolean. If True adds the predicted node distribution
       #           minimum to the output
       #     d_max: Boolean. If True adds the predicted node distribution
       #            maximum to the output
       #    median: Boolean. If True adds the median of the predicted node
       #             distribution to the output
       #   unused_fields: Boolean. If True adds the fields used in the input
       #                    data that have not been used by the model.
       #
       prediction_properties = ["prediction", "confidence", "probability", "path", "distribution",
                                "count", "next", "d_min", "d_max", "median", "unused_fields"]
       result = init_structure(to)
       prediction=true
       prediction_properties.each do |prop|
         value = full_prediction.fetch(prop, nil)
         if (prop != "next" && eval(prop) or (prop=="next" && _next))
           if to.nil?
             result = result+value
           elsif to == DICTIONARY
             result.merge!({"prop" => value})
           else
             result << value
           end     
         end 
         
       end
       
       return result
       
   end
 
   def self.sort_categories(a, b, categories_list)
     
     # Sorts a list of dictionaries with category keys according to their
     # value and order in the categories_list. If not found, alphabetic order is
     # used.
     
     index_a = categories_list.index(a["category"])
     index_b = categories_list.index(b["category"])
     
     if index_a < 0 and index_b < 0
       
         index_a = a['category']
         index_b = b['category']
     end
     
     if index_b < index_a
         return 1
     end
     
     if index_b > index_a
         return -1
     end
    
     return 0
   end
        
   def self.print_distribution(distribution, out=$STDOUT)
     # Prints distribution data

     total = distribution.collect {|group| group[1] }.inject {|x,y| x + y}

     distribution.each do |group|
        out.puts "    %s: %.2f%% (%d instance%s)" % [group[0],
                                                     (group[1] * 1.0 / total).round(4)*100,
                                                     group[1],
                                                     group[1] == 1 ? "" : "s"]
     end

   end
   
   def self.parse_operating_point(operating_point, operating_kinds, class_names)
       #
       # Checks the operating point contents and extracts the three defined
       # variables
       #
       if !operating_point.key?("kind")
           raise ArgumentError.new("Failed to find the kind of operating point.")
       elsif !operating_kinds.include?(operating_point["kind"])
           raise ArgumentError.new("Unexpected operating point kind. Allowed 
                               values are: %s." % ", ".join(operating_kinds))
       end
       
       if !operating_point.key?("threshold")
           raise ArgumentError.new("Failed to find the threshold of the operating point.")
       end
       
       if operating_point["threshold"] > 1 or operating_point["threshold"] < 0
           raise ArgumentError.new("The threshold value should be in the 0 to 1 range.")
       end
                          
       if !operating_point.key?("positive_class")
           raise ArgumentError.new("The operating point needs to have a positive_class attribute.")
       else
           positive_class = operating_point["positive_class"]
           if !class_names.include?(positive_class)
               raise ArgumentError.new("The positive class must be one of the
                                    objective field classes: %s." % ", ".join(class_names))
           end
       end
       
       kind = operating_point["kind"]
       threshold = operating_point["threshold"]

       return [kind, threshold, positive_class]
    
   end
     
   class Model < BaseModel
     #  A lightweight wrapper around a Tree model.

     #  Uses a BigML remote model to build a local version that can be used
     #  to generate predictions locally.
     #
     attr_accessor :tree, :fields, :objective_id, :boosting, :class_names, :regression

     def initialize(model, api=nil, fields=nil)
        # The Model constructor can be given as first argument
        #  a model structure or a model id or  a path to 
        #  a JSON file containing a model structure
        @resource_id = nil 
        @ids_map = {}
        @terms = {}
        @regression = false
        @boosting = nil 
        @class_names = nil
        
        if api.nil?
          api = BigML::Api.new(nil, nil, false, false, false, STORAGE)
        end
        
        # the string can be a path to a JSON file
        if model.is_a?(String) 
           if File.file?(model)
              begin
                File.open(model, "r") do |f|
                    model = JSON.parse(f.read)
                end
                @resource_id =  BigML::get_model_id(model)
                if @resource_id.nil?
                   raise ArgumentError.new("The JSON file does not seem to contain a valid BigML model representation")
                end
              rescue Exception
                  raise Exception, "The JSON file does not seem to contain a valid BigML model representation"
              end
           else
              # if it is not a path, it can be a model id
             @resource_id =  BigML::get_model_id(model)
             if @resource_id.nil?
               if !model.index('model/').nil?
                   raise Exception, api.error_message(model, 'model', 'get')
               else
                   raise Exception, "Failed to open the expected JSON file at %s" % [model]
               end
             end
           end 
        end

        # checks whether the information needed for local predictions is in
        # the first argument
        has_model_fields = BigML::check_model_fields(model)
        if model.is_a?(Hash) and fields.nil? and !has_model_fields
           # if the fields used by the model are not available, use only ID
           # to retrieve it again
           model = BigML::get_model_id(model)
           @resource_id = model
        end

        if !(model.is_a?(Hash) and model.key?('resource') and !model['resource'].nil?) 
          
           if !fields.nil? and fields.is_a?(Hash)
             query_string = EXCLUDE_FIELDS
           else
             query_string = ONLY_MODEL
           end

           model = BigML::retrieve_resource(api, @resource_id, query_string, !fields.nil?)
        else
           @resource_id =  BigML::get_model_id(model)
        end

        super(model, api, fields)

        if model.key?('object') and model['object'].is_a?(Hash)
            model = model['object']
        end

        if model.key?("model") and model['model'].is_a?(Hash)
           status = BigML::Util::get_status(model)
           if status.key?('code') and status['code'] == FINISHED
              # boosting models are to be handled using the BoostedTree class
              
              if model.fetch("boosted_ensemble", nil).nil?
                @boosting = model.fetch('boosting', false)
              end
               
              if !model.fetch("boosted_ensemble", nil).nil? and model["boosted_ensemble"]
                @boosting = model.fetch('boosting', false)
              end

              if @boosting == {}
                @boosting = false
              end
            
              @regression = (@boosting.nil? and self.fields[self.objective_id]['optype'] == 'numeric') or (@boosting and @boosting.fetch("objective_class",nil).nil?)
                                  
              if !defined?(@tree_class)
                 @tree_class = (@boosting.nil? or !@boosting) ? BigML::Tree : BigML::BoostedTree
              end
               
              if @boosting
                @tree = @tree_class.new(model['model']['root'], @fields, @objective_id)
              else
                distribution = model['model']['distribution']['training']
                # will store global information in the tree: regression and
                # max_bins number
                tree_info = {'max_bins' => 0}
                @tree = @tree_class.new(model['model']['root'],
                                        @fields,
                                        @objective_id,
                                        distribution,
                                        nil,
                                        @ids_map,
                                        true,
                                        tree_info)

                @tree.regression = tree_info['regression']
                if @tree.regression
                   @_max_bins = tree_info['max_bins']
                   @regression_ready = true
                else
                  root_dist = self.tree.distribution
                  @class_names = root_dist.collect {|category| category[0]}.sort
                  @objective_categories = self.fields[self.objective_id]["summary"]["categories"].map{|i| i[0]}
                end
              end
              
              if @regression.nil? and @boosting.nil?
                @laplacian_term = self._laplacian_term()
              end
                
           else
             raise Exception, "Cannot create the Model instance. Only correctly finished models 
                               can be used. The model status is currently: %s\n" % STATUSES[status['code']]
           end 
        else
           raise Exception, "Cannot create the Model instance. Could not find the 'model' key in the resource:\n\n %s " % [model]
        end

     end

     def list_fields(out=STDOUT)
        # Prints descriptions of the fields for this model.
       @tree.list_fields(out)
     end

     def get_leaves(filter_function=nil)
        # Returns a list that includes all the leaves of the model.

        #   filter_function should be a function that returns a boolean
        #   when applied to each leaf node.
        return @tree.get_leaves(nil, filter_function)
     end
     
     def _to_output(output_map, compact, value_key)
       
       if compact
         return @class_names.map {|name| output_map.fetch(name, 0.0).round(BigML::Util::PRECISION) }
       else
         output = []
         @class_names.each do |name|
           output << {'category' => name, 
                      value_key =>  output_map.fetch(name, 0.0).round(BigML::Util::PRECISION)}
         end
         
         return output               
       end
       
     end
     
     def predict_confidence(input_data,
                            missing_strategy=LAST_PREDICTION,
                            compact=false)
                            
       # For classification models, Predicts a one-vs.-rest confidence value
       # for each possible output class, based on input values.  This
       # confidence value is a lower confidence bound on the predicted
       # probability of the given class.  The input fields must be a
       # dictionary keyed by field name for field ID.
       # For regressions, the output is a single element list
       # containing the prediction.
       # :param input_data: Input data to be predicted
       # :param missing_strategy: LAST_PREDICTION|PROPORTIONAL missing strategy
       #                        for missing fields
       # :param compact: If False, prediction is returned as a list of maps, one
       #                 per class, with the keys "prediction" and "probability"
       #                 mapped to the name of the class and it's probability,
       #                respectively.  If True, returns a list of probabilities
       #                 ordered by the sorted order of the class names.
       #
       
       if @regression
         prediction = self.predict(input_data,
                                   {"missing_strategy" => missing_strategy,
                                    "full" => !compact})

         if compact
            output = [prediction]
         else
            output = cast_prediction(prediction, DICTIONARY, true)
         end
         
         return output
         
       elsif @regression 
         raise ArgumentError.new("This method is available for non-boosting categorization models only.")
       end                          

       root_dist = @tree.distribution
       category_map=root_dist.collect {|category| {category[0] => 0.0} }.reduce({}, :merge)
       prediction = self.predict(input_data,
                                 {"missing_strategy" => missing_strategy,
                                  "full" => true})

       distribution = prediction['distribution']

       distribution.each do |class_info|
         name = class_info[0]
         category_map[name.to_s] = BigML::ws_confidence(name, distribution)
       end 

       return self._to_output(category_map, compact, "confidence")
     
     end
     
     def _laplacian_term()
       # Correction term based on the training dataset distribution
       #
       root_dist = @tree.distribution
       category_map={}
       if @tree.weighted
          root_dist.each do |category| 
            category_map[category[0]] = 0.0
          end
       else
         total = root_dist.map{|category| category[1]}.sum.to_f
         root_dist.each do |category| 
           category_map[category[0]] = category[1]/total
         end
       end 
       
       return category_map   
     end
     
     def _probabilities(distribution)
       # Computes the probability of a distribution using a Laplacian
       # correction.
       #
       total =  @tree.weighted ? 0 : 1
       category_map = {}
       category_map.merge!(self._laplacian_term())

       distribution.each do |class_info|
         category_map[class_info[0]] += class_info[1]
         total += class_info[1]
       end
       
       category_map.each do|k,v|
         category_map[k] /= total
       end   
       
       return category_map

     end
     
     def predict_probability(input_data, options={})
        return _predict_probability(input_data,
                                    options.fetch("missing_strategy", BigML::LAST_PREDICTION),
                                    options.fetch("compact",false))
     end
     
     def _predict_probability(input_data, 
                             missing_strategy=LAST_PREDICTION, 
                             compact=false)
                             
       # For classification models, Predicts a probability for
       # each possible output class, based on input values.  The input
       # fields must be a dictionary keyed by field name for field ID.
       # For regressions, the output is a single element list
       # containing the prediction.
       # :param input_data: Input data to be predicted
       # :param missing_strategy: LAST_PREDICTION|PROPORTIONAL missing strategy
       #                          for missing fields
       # :param compact: If False, prediction is returned as a list of maps, one
       #                 per class, with the keys "prediction" and "confidence"
       #                 mapped to the name of the class and it's confidence,
       #                 respectively.  If True, returns a list of confidences
       #                 ordered by the sorted order of the class names.
       #         
        
        if @regression or !@boosting.nil?
          prediction = self.predict(input_data, {"missing_strategy" => missing_strategy,
                                              "full" => !compact})
          if compact
            output = [prediction]
          else
            output = prediction
          end    
        else
          prediction = self.predict(input_data,
                                    {"missing_strategy" => missing_strategy, 
                                     "full" => true})
                        
          category_map = self._probabilities(prediction['distribution'])
          output = self._to_output(category_map, compact, "probability")
        end
        
        return output    

     end
     
     def predict_operating(input_data,
                           missing_strategy=LAST_PREDICTION,
                           operating_point=nil)
                           
         kind, threshold, positive_class = BigML::parse_operating_point(operating_point, 
                                                                        OPERATING_POINT_KINDS, 
                                                                        self.class_names)
         if kind == "probability"
           predictions = self._predict_probability(input_data,
                                                   missing_strategy, false)
         else
           predictions = self.predict_confidence(input_data,
                                                 missing_strategy, false)
         end 
                                              
         position = self.class_names.index(positive_class)
         if predictions[position][kind] > threshold
             prediction = predictions[position]
         else
             # if the threshold is not met, the alternative class with
             # highest probability or confidence is returned
             
             #prediction = predictions.sort_by {|a,b|   self._sort_predictions(a, b, kind)}[0..2]
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
     
     def _sort_predictions(a, b, criteria)
       # Sorts the categories in the predicted node according to the
       # given criteria
       #
       if a[criteria] == b[criteria]
          return sort_categories(a, b, self.objective_categories)
       end
       
       return b[criteria] > a[criteria] ? 1 : -1
     end
     
     def predict_operating_kind(input_data,
                                missing_strategy=LAST_PREDICTION,
                                operating_kind=None)
       #Computes the prediction based on a user-given operating kind.
       #
       kind = operating_kind.downcase
       if (!OPERATING_POINT_KINDS.include?(kind))
           raise ArgumentError.new("Allowed operating kinds are %s. %s found." %
                            [", ".join(OPERATING_POINT_KINDS), kind])
       end
       if kind == "probability"
         predictions = self._predict_probability(input_data,
                                                 missing_strategy, false)
       else
         predictions = self.predict_confidence(input_data,
                                               missing_strategy, false)
       end
       
       if self.regression
         prediction = predictions
       else
         prediction = predictions.sort_by {|p| [-p[kind], p['category']]}[0]
                               
         prediction["prediction"] = prediction["category"]
         prediction.delete("category")
       end
       
       return prediction
     end
     
     def predict(input_data, options={})
        # Makes a prediction based on a number of field values.

        # input_data: Input data to be predicted
        # missing_strategy: LAST_PREDICTION|PROPORTIONAL missing strategy for
        #                  missing fields
        # operating_point: In classification models, this is the point of the
        #                 ROC curve where the model will be used at. The
        #                 operating point can be defined in terms of:
        #                 - the positive_class, the class that is important to
        #                   predict accurately
        #                 - the probability_threshold (or confidence_threshold),
        #                   the probability (or confidence) that is stablished
        #                   as minimum for the positive_class to be predicted.
        #                 The operating_point is then defined as a map with
        #                 two attributes, e.g.:
        #                   {"positive_class": "Iris-setosa",
        #                    "probability_threshold": 0.5}
        #                 or
        #                   {"positive_class": "Iris-setosa",
        #                    "confidence_threshold": 0.5}
        # operating_kind: "probability" or "confidence". Sets the
        #                property that decides the prediction. Used only if
        #                no operating_point is used
        # full: Boolean that controls whether to include the prediction's
        #      attributes. By default, only the prediction is produced. If set
        #      to True, the rest of available information is added in a
        #      dictionary format. The dictionary keys can be:
        #          - prediction: the prediction value
        #          - confidence: prediction's confidence
        #          - probability: prediction's probability
        #          - path: rules that lead to the prediction
        #          - count: number of training instances supporting the
        #                   prediction
        #          - next: field to check in the next split
        #          - min: minim value of the training instances in the
        #                 predicted node
        #          - max: maximum value of the training instances in the
        #                 predicted node
        #          - median: median of the values of the training instances
        #                    in the predicted node
        #          - unused_fields: list of fields in the input data that
        #                           are not being used in the model
        
        # Checks and cleans input_data leaving the fields used in the model
        

        full = options.key?("full") ? options["full"] : false
        missing_strategy = options.key?("missing_strategy") ? options["missing_strategy"] : LAST_PREDICTION
        operating_point = options.key?("operating_point") ? options["operating_point"] : nil
        operating_kind = options.key?("operating_kind") ? options["operating_kind"] : nil
   
        unused_fields = []
        new_data = self.filter_input_data(input_data, full)
        if full
          input_data, unused_fields = new_data
        else
          input_data = new_data
        end
        
        # Strips affixes for numeric values and casts to the final field type
        BigML::Util::cast(input_data, self.fields)
        
        full_prediction = _predict(input_data,
                                   missing_strategy,
                                   operating_point,
                                   operating_kind,
                                   unused_fields) 

        if full
           
           result = {}
           full_prediction.each do |key,value|
             if !value.nil?
               result[key] = value
             end 
           end 
           
           return result
      
        end 
         
        return full_prediction['prediction']
        
     end
                      
     def _predict(input_data, missing_strategy=LAST_PREDICTION,
                 operating_point=nil, operating_kind=nil, unused_fields=nil)
        # Makes a prediction based on a number of field values.
 
        # input_data: Input data to be predicted
        # missing_strategy: LAST_PREDICTION|PROPORTIONAL missing strategy for
        #                  missing fields
        # operating_point: In classification models, this is the point of the
        #                 ROC curve where the model will be used at. The
        #                 operating point can be defined in terms of:
        #                 - the positive_class, the class that is important to
        #                   predict accurately
        #                 - the probability_threshold (or confidence_threshold),
        #                   the probability (or confidence) that is stablished
        #                   as minimum for the positive_class to be predicted.
        #                 The operating_point is then defined as a map with
        #                 two attributes, e.g.:
        #                   {"positive_class": "Iris-setosa",
        #                    "probability_threshold": 0.5}
        #                 or
        #                   {"positive_class": "Iris-setosa",
        #                    "confidence_threshold": 0.5}
        # operating_kind: "probability" or "confidence". Sets the
        #                property that decides the prediction. Used only if
        #                no operating_point is used
        # full: Boolean that controls whether to include the prediction's
        #      attributes. By default, only the prediction is produced. If set
        #      to True, the rest of available information is added in a
        #      dictionary format. The dictionary keys can be:
        #          - prediction: the prediction value
        #          - confidence: prediction's confidence
        #          - probability: prediction's probability
        #          - path: rules that lead to the prediction
        #          - count: number of training instances supporting the
        #                   prediction
        #          - next: field to check in the next split
        #          - min: minim value of the training instances in the
        #                 predicted node
        #          - max: maximum value of the training instances in the
        #                 predicted node
        #          - median: median of the values of the training instances
        #                    in the predicted node
        #          - unused_fields: list of fields in the input data that
        #                           are not being used in the model
                                           
        #
        # Strips affixes for numeric values and casts to the final field type
        #BigML::Util::cast(input_data, self.fields)
        
        # When operating_point is used, we need the probabilities
        # (or confidences) of all possible classes to decide, so se use
        # the `predict_probability` or `predict_confidence` methods
        if !operating_point.nil?
          if @regression
            raise  ArgumentError.new("The operating_point argument can only be used in classifications.")
          end
          prediction = self.predict_operating(input_data, missing_strategy, operating_point)
          return prediction
        end  
                                        
        if !operating_kind.nil?
          if @regression
            raise  ArgumentError.new("The operating_kind argument can only be used in classifications.")
          end
          prediction = self.predict_operating_kind(input_data,
                                                   missing_strategy,
                                                   operating_kind)
          return prediction
          
        end
                        
        if (@boosting.nil? and @regression and 
             missing_strategy == PROPORTIONAL and !@regression_ready) 

            raise ArgumentError.new("Failed,
                               needed to use proportional missing strategy
                               for regressions. Please install them before
                               using local predictions for the model.")
        end

        prediction = @tree.predict(input_data, nil,
                                   missing_strategy)

        if @boosting and missing_strategy == PROPORTIONAL
           # output has to be recomputed and comes in a different format
           g_sum, h_sum, population, path = prediction

           prediction = BigML::Prediction.new(- g_sum / (h_sum +  @boosting.fetch("lambda", 1)),
                                              path,nil,nil, population)
        end
        
        result = prediction.instance_variables.each_with_object({}) { |var, result| result[var.to_s.delete("@")] = prediction.instance_variable_get(var) }
        # changing key name to prediction
        result['prediction'] = result['output']
        result.delete("output")
        
        #next
        field = prediction.children.size == 0 ? nil : prediction.children[0].predicate.field
        
        if !field.nil? and @fields.key?(field)
          field = @fields[field]['name']
        end 
        
        result['next'] = field
        result.delete('children')
        
        
        if @regression.nil? and @boosting.nil?
          probabilities = self._probabilities(result['distribution'])
          result['probability'] = probabilities[result['prediction']]
        end
        
        if unused_fields
          result.merge!({'unused_fields' => unused_fields})
        end  
        
        return result
     end

     def get_ids_path(filter_id)
        #
        # Builds the list of ids that go from a given id to the tree root
        #
        ids_path = nil
        if !filter_id.nil? and !@tree.id.nil?
            if !@ids_map.include?(filter_id) 
                raise ArgumentError.new("The given id does not exist.")
            else
                ids_path = [filter_id]
                last_id = filter_id
                while !@ids_map[last_id].parent_id.nil? do
                    ids_path << @ids_map[last_id].parent_id
                    last_id = @ids_map[last_id].parent_id
                end
            end
        end
        return ids_path
     end

     def rules(out=$STDOUT, filter_id=nil, subtree=true)
        #
        # Returns a IF-THEN rule set that implements the model.
        # `out` is file descriptor to write the rules.
        #
        if @boosting
          raise ArgumentError.new("This method is not available for boosting models.")
        end
        ids_path = get_ids_path(filter_id)
        return @tree.rules(out, ids_path, subtree)
     end
 
     def group_prediction()
        # Groups in categories or bins the predicted data

        # dict - contains a dict grouping counts in 'total' and 'details' lists.
        # 'total' key contains a 3-element list.
        #    - common segment of the tree for all instances
        #    - data count
        #    - predictions count
        #        'details' key contains a list of elements. Each element is a
        #              3-element list:
        #    - complete path of the tree from the root to the leaf
        #    - leaf predictions count
        #    - confidence
        #
 
       if @boosting
          raise ArgumentError.new("This method is not available for boosting models.")
       end
       groups = {}
       tree = @tree
       distribution = tree.distribution

       distribution.each do |group|
           groups[group[0]] = {'total' => [[], group[1], 0],
                               'details' => []}
       end

       path = []

       def self.add_to_groups(groups, output, path, count, confidence,
                          impurity=nil)
            #Adds instances to groups array

            group = output
            if !groups.include?(output)
                groups[group] = {'total' => [[], 0, 0],
                                 'details' => []}
            end

            groups[group]['details'] << [path, count, confidence,
                                         impurity]
            groups[group]['total'][2] += count

       end

       def self.depth_first_search(groups, tree, path)
            # Search for leafs' values and instances

            if tree.predicate.is_a?(Predicate)
                path << tree.predicate
                if tree.predicate.term
                    term = tree.predicate.term
                    if !@terms.include?(tree.predicate.field) 
                        @terms[tree.predicate.field] = []
                    end
                    if !@terms[tree.predicate.field].include?(term)
                        @terms[tree.predicate.field] << term
                    end
                end
            end

            if tree.children.size() == 0
                add_to_groups(groups, tree.output,
                              path, tree.count, tree.confidence, tree.impurity)
                return tree.count
            else
                children = tree.children[0..-1]
                children.reverse!

                children_sum = 0
                children.each do |child|
                   children_sum += depth_first_search(groups, child, path[0..-1])
                end
                if children_sum < tree.count
                    add_to_groups(groups, tree.output, path,
                                  tree.count - children_sum, tree.confidence,
                                  tree.impurity)
                end
                return tree.count
            end
       end

       depth_first_search(groups, tree, path)
       return groups

     end

     def get_data_distribution()
       #
       # Returns training data distribution
       #

       if @boosting
          raise ArgumentError.new("This method is not available for boosting models.")
       end

       tree = @tree
       distribution = tree.distribution
        
       return distribution.sort_by {|x| x[0]}
     end

     def get_prediction_distribution(groups=nil)
       #
       # Returns model predicted distribution
       #
       if @boosting
          raise ArgumentError.new("This method is not available for boosting models.")
       end

       if groups.nil?
            groups = group_prediction()
       end

       predictions = groups.collect {|groupId, group| [groupId,group['total'][2]]}
       # remove groups that are not predicted
       predictions.reject! {|prediction| prediction[1] <= 0 }

       return predictions.sort_by {|x| x[0]}
     end

     def summarize(out=$STDOUT, format=BigML::BRIEF)
        #
        #Prints summary grouping distribution as class header and details
        #
        if @boosting
          raise ArgumentError.new("This method is not available for boosting models.")
        end
        tree = @tree

        def extract_common_path(groups)
            #
            # Extracts the common segment of the prediction path for a group
            #
            groups.each do |group, value|
              details = groups[group]['details']
              common_path = []
              if details.size > 0
                mcd_len=details.collect {|x| x[0].size}.min
                (0..(mcd_len-1)).each do |i|
                   test_common_path=details[0][0][i]
                   details.each do |subgroup|
                      if subgroup[0][i] != test_common_path
                          i = mcd_len
                          break
                      end
                   end
                   if i < mcd_len
                      common_path << test_common_path
                   end
                end  
              end

              groups[group]['total'][0] = common_path

              if details.size > 0
                 groups[group]['details'] = details.sort_by {|x| -x[1]}
              end 
            end
        end

        def confidence_error(value, impurity=nil)
            # Returns confidence for categoric objective fields
            #   and error for numeric objective fields
            #
            if value.nil?
                return ""
            end
            impurity_literal = ""
            if !impurity.nil? and impurity > 0
                impurity_literal = "; impurity: %.2f%%" % [impurity.round(4)]
            end

            objective_type = @fields[tree.objective_id]['optype']
            if objective_type == 'numeric'
                return " [Error: %s]" % (value)
            else
                return " [Confidence: %.2f%%%s]" % [(value.round(4) * 100),
                                                     impurity_literal]
            end
        end

        distribution = get_data_distribution()

        out.puts "Data distribution:"
        BigML::print_distribution(distribution, out)
        out.puts
        out.puts

        groups = group_prediction()
        predictions = get_prediction_distribution(groups)

        out.puts "Predicted distribution:"
        BigML::print_distribution(predictions, out)
        out.puts 
        out.puts

        if @field_importance
          out.puts "Field importance:"
          print_importance(out)
        end

        extract_common_path(groups)
        out.puts
        out.puts
        out.puts "Rules summary:"

        predictions.collect {|x| x[0] }.each do |group|
          details = groups[group]['details']
          path = Path.new(groups[group]['total'][0])
          data_per_group = groups[group]['total'][1] * 1.0 / tree.count
          pred_per_group = groups[group]['total'][2] * 1.0 / tree.count
          out.puts
          out.print "%s : (data %.2f%% / prediction %.2f%%) %s" % [group,
                                                                  data_per_group.round(4)*100,
                                                                  pred_per_group.round(4)*100,
                                                                  path.to_rules(@fields, 'name', format)]
          if details.size == 0
             out.puts
             out.puts "    The model will never predict this class\n"
          elsif details.size == 1
             subgroup = details[0]
             out.print "%s\n" % confidence_error(subgroup[2], subgroup[3])
          else
             out.puts 
             (0..(details.size-1)).each do |j|
                subgroup = details[j]
                pred_per_sgroup = subgroup[1] * 1.0 / groups[group]['total'][2]
                path = Path.new(subgroup[0])

                if (path.predicates.nil? or path.predicates.empty?)
                  path_chain = "(root node)"
                else
                  path_chain = path.to_rules(@fields, 'name', format)
                end 
                out.puts "    · %.2f%%: %s%s" % [pred_per_sgroup.round(4)*100, path_chain, confidence_error(subgroup[2], subgroup[3])]
             end

          end
          out.puts
        end

        out.flush

     end

     def to_prediction(value_as_string, data_locale="UTF-8")
        #
        # Given a prediction string, returns its value in the required type
        #

        objective_id = @tree.objective_id
        if @fields[objective_id]['optype'] == 'numeric'
            if data_locale.nil? 
               data_locale = @locale
            end
            datatype = @fields[objective_id]['datatype']
            BigML::Util::find_locale(data_locale)

            if ["double", "float"].include?(datatype)
               return value_as_string.to_f
            else
               return value_as_string.to_i
            end

        end

        return value_as_string
     end

   end

end

