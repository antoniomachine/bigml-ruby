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



# An local Ensemble object.

# This module defines an Ensemble to make predictions locally using its
# associated models.

# This module can not only save you a few credits, but also enormously
# reduce the latency for each prediction and let you use your models
# offline.
require_relative 'resourcehandler'
require_relative 'multimodel'

module BigML

  ENSEMBLE_BOOSTING = 1
  OPERATING_POINT_KINDS_ENSEMBLE = ["probability", "confidence", "votes"]

  def self.use_cache(cache_get)
    #Checks whether the user has provided a cache get function to retrieve
    # local models.
    #
    return (!cache_get.nil? and cache_get.respond_to?("call"))
  end
  
  def self.boosted_list_error(boosting)
    # The local ensemble cannot be built from a list of boosted models
    #
    if boosting
       raise ArgumentError.new("Failed to build the local ensemble. Boosted
                           ensembles cannot be built from a list
                           of boosting models.")
    end
  end
  
  class Ensemble < ModelFields
      # A local predictive Ensemble.

      #  Uses a number of BigML remote models to build an ensemble local version
      #  that can be used to generate predictions locally.
      #  The expected arguments are:

      #  ensemble: ensemble object or id, list of model objects or
      #           ids or list of local model objects (see Model)
      # api: connection object. If None, a new connection object is
      #      instantiated.
      #  max_models: integer that limits the number of models instantiated and
      #              held in memory at the same time while predicting. If None,
      #             no limit is set and all the ensemble models are
      #             instantiated and held in memory permanently.
      attr_accessor :model_ids, :regression
      
      def initialize(ensemble, api=nil, max_models=nil, cache_get=nil)
         if api.nil?
            @api = BigML::Api.new(nil, nil, false, false, false, STORAGE)
         else
            @api = api
         end

         @resource_id = nil 
         #to be deprecated
         @ensemble_id = nil 
         @objective_id = nil 
         @distributions = nil
         @distribution = nil 
         @models_splits = []
         @multi_model = nil 
         @boosting = nil
         @boosting_offsets = nil
         @cache_get = nil
         @regression = false 
         @fields = nil
         @class_names=[]
         @importance = {}
         query_string = ONLY_MODEL
         no_check_fields = false

         if ensemble.is_a?(Array)
             if ensemble.collect {|model| model.is_a?(BigML::Model)}.all? 
                models = ensemble
                @model_ids = models.collect{|local_model| local_model.resource_id}
             else
                begin
                   models = ensemble.collect {|model| BigML::get_model_id(model) }
                   @model_ids = models
                rescue Exception
                   raise ArgumentError, 'Failed to verify the list of models.
                                       Check your model id values: %s' % ensemble
                end
             end 
         else
            ensemble = get_ensemble_resource(ensemble)
            @resource_id = BigML::get_ensemble_id(ensemble)
            ensemble_id = @resource_id
            
            if BigML::lacks_info(ensemble, "ensemble")
              ensemble = BigML::retrieve_resource(@api, @resource_id, '', true)
            end  

            if ensemble['object'].fetch('type', '') == ENSEMBLE_BOOSTING
              @boosting = ensemble['object']['boosting']
            end
            models = ensemble['object']['models']
            @distributions = ensemble['object'].fetch('distributions', [])
            @importance = ensemble['object'].fetch('importance', {})
            @model_ids = models
            # new ensembles have the fields structure
           if !ensemble['object'].fetch('ensemble', nil).nil?
              @fields = ensemble['object'].fetch('ensemble', {}).fetch("fields", nil)
              @objective_id = ensemble['object'].fetch("objective_field")
              query_string = EXCLUDE_FIELDS
              no_check_fields = true
           end
         end

         number_of_models = models.size
         if max_models.nil?
            @models_splits = [models]
         else
            (0..(number_of_models-1)).step(max_models).each do |index|
               @models_splits << models[index..(index + max_models)]
            end
         end
         if @models_splits.size == 1
            if !models[0].is_a?(BigML::Model)
               if BigML::use_cache(cache_get)
                  begin
                    models = @models_splits[0].collect {|model_id| cache_get.call(model_id)} 
                    @cache_get = cache_get
                  rescue Exception
                    raise Exception, 'Error while calling the user-given
                                     function cache_get'
                  end
               else
                 models = @models_splits[0].collect {|model_id| 
                                                BigML::retrieve_resource(@api,
                                                                         model_id,
                                                                         query_string,
                                                                         no_check_fields)}
               end 
            end
            model = models[0]
         else
           # only retrieving first model
           @cache_get = cache_get
           if !models[0].is_a?(BigML::Model)
              if BigML::use_cache(cache_get)
                # retrieve the models from a cache get function
                begin
                  model = cache_get.call(@models_splits[0][0])
                  @cache_get = cache_get
                rescue Exception
                   raise Exception, 'Error while calling the user-given
                                    function cache_get'  
                end 
              else
                model = BigML::retrieve_resource(@api, @models_splits[0][0], 
                                                  query_string, no_check_fields)
              end
              
              models = [model]
              
           end
         end
         
         if @distributions.nil?
           begin
             @distributions = models.collect {|m|  {'training' => {'categories' => m.tree.distribution}}}
           rescue
             @distributions =  models.collect {|m| m['object']['model']['distribution'] }
           end      
         end 

         if @boosting.nil?
            _add_models_attrs(model, max_models)
         end

         if @fields.nil?
            @fields, @objective_id = all_model_fields(max_models)
         end

         if !@fields.nil?
           summary = @fields[@objective_id]['summary']
           if summary.key?("bin")
             distribution = summary['bins']
           elsif summary.key?("counts")
             distribution = summary['counts']
           elsif summary.key?("categories")
             distribution = summary['categories']
           else
             distribution = []
           end
           
           @distribution = distribution
         end 

         @regression = @fields[@objective_id].fetch('optype', '') == 'numeric'
         if !@boosting.nil?
           @boosting_offsets = @regression ? ensemble['object'].fetch('initial_offset',0) : 
                                             Hash[*ensemble['object'].fetch('initial_offsets', []).flatten]
         end

         if !@regression
           begin
             objective_field = @fields[@objective_id]
             categories = objective_field['summary']['categories']
             classes = categories.collect {|category| category[0]}
           rescue 
             classes = []
             @distributions.each do |d|
                d['training']['categories'].each do |c|
                  if !classes.include?(c[0])
                    classes << c[0] 
                  end 
                end   
             end
           end
           
           @class_names = classes.sort
           @objective_categories = @fields[@objective_id]['summary']['categories'].map{|it|it[0]}
         end    
        
         super(@fields, @objective_id)
  
         if @models_splits.size == 1
           @multi_model = BigML::MultiModel.new(models, @api, @fields, @class_names)
         end
         
      end 

      def _add_models_attrs(model, max_models=nil)
        # Adds the boosting and fields info when the ensemble is built from
        # a list of models. They can be either Model objects
        # or the model dictionary info structure.
        if model.is_a?(BigML::Model)
          @boosting = model.boosting
           BigML::boosted_list_error(@boosting)
           @objective_id = model.objective_id
        else
          if model['object']['boosted_ensemble']
            @boosting = model['object']['boosting']
          end
          
          BigML::boosted_list_error(@boosting)
          
          if @fields.nil?
             @fields, _ = all_model_fields(max_models)
             @objective_id = model['object']['objective_field']
          end
        end
 
      end

      def get_ensemble_resource(ensemble)
        # Extracts the ensemble resource info. The ensemble argument can be
        #   - a path to a local file
        #   - an ensemble id
        #
        # the string can be a path to a JSON file
        #
        if ensemble.is_a?(String)
            begin
                ensemble_file = File.open(ensemble,"r")
                ensemble = JSON.parse(ensemble_file.read)
                ensemble_file.close
                @resource_id = BigML::get_ensemble_id(ensemble)
                if @resource_id.nil?
                   raise Exception, "The JSON file does not seen  to contain a valid BigML ensemble
                           representation."
                end
            rescue
              begin
                @resource_id = BigML::get_ensemble_id(ensemble)
                if @resource_id.nil?
                   if !ensemble.index("ensemble/").nil?
                      raise Exception, @api.error_message(ensemble, 'ensemble', 'get')
                   else
                      raise Exception, "Failed to open the expected JSON file at %s" % ensemble
                   end
                end
              rescue
                raise Exception, "Failed to interpret %s. JSON file expected. " % ensemble
              end  
            end
         
        end

        return ensemble

      end

      def  list_models()
        #
        # Lists all the model/ids that compound the ensemble.
        #
        return @model_ids 
      end

      def predict_probability(input_data, options={})
        return _predict_probability(input_data, 
                                    options.fetch("missing_strategy", LAST_PREDICTION),
                                    options.fetch("compact", false))
      end
      
      def _predict_probability(input_data,
                               missing_strategy=LAST_PREDICTION, 
                               compact=false)

       # For classification problems, Predicts a probabilistic "score" for
       # each possible output class, based on input values.  The input
       # fields must be a dictionary keyed by field name.  For
       # classifications, the output is a list with one floating point
       # element for each possible class, ordered in sorted class-name
       # ordering.
       # For regressions, the output is a single element vector
       # containing the prediction.
       # :param input_data: Input data to be predicted
       #   :param missing_strategy: LAST_PREDICTION|PROPORTIONAL missing strategy for
       #                          missing fields
       #   :param compact: If False, prediction is returned as a list of maps, one
       #                  per class, with the keys "prediction" and "probability"
       #                  mapped to the name of the class and it's probability,
       #                  respectively.  If True, returns a list of probabilities
       #                  ordered by the sorted order of the class names.
       #
       
       if @regression
         prediction = self.predict(input_data,
                                {"method" => PROBABILITY_CODE,
                                 "missing_strategy" => missing_strategy, 
                                 "full" => !compact})
         if compact
           output = [prediction]
         else
           output = prediction
         end    
       elsif !@boosting.nil?
         probabilities = self.predict(input_data,
                                      {"method" => PLURALITY_CODE,
                                       "missing_strategy" => missing_strategy,
                                       "full" => true})['probabilities']
        
         
         if compact
           output = [probabilities.sort_by{|x| x['category']}.collect {|p| p['probability']} ]
         else
           output = probabilities.sort_by{|x| x['category']}
         end                                     
 
       else
         output = self._combine_distributions(input_data, missing_strategy)
         if !compact
           
            names_probabilities = @class_names.zip(output)
            
            output = names_probabilities.collect { |class_name, probability| {'category' => class_name, 
                                                                              'probability'=> probability} }
         end
       end

       return output
                                        
      end
      
      def predict_confidence(input_data, options={})
        return _predict_confidence(input_data,
                                   options.fetch("missing_strategy", BigML::LAST_PREDICTION),
                                   options.fetch("compact",false))
      end
      
      def _predict_confidence(input_data,
                              missing_strategy=LAST_PREDICTION,
                              compact=false)

        # For classification models, Predicts a confidence for
        # each possible output class, based on input values.  The input
        # fields must be a dictionary keyed by field name or field ID.
        # For regressions, the output is a single element list
        # containing the prediction.
        # :param input_data: Input data to be predicted
        # :param missing_strategy: LAST_PREDICTION|PROPORTIONAL missing strategy
        #                          for missing fields
        # :param compact: If False, prediction is returned as a list of maps, one
        #                per class, with the keys "prediction" and "probability"
        #                mapped to the name of the class and it's probability,
        #                respectively.  If True, returns a list of probabilities
        #                ordered by the sorted order of the class names.
        #

        if !@boosting.nil?
          # we use boosting probabilities as confidences also
          return self._predict_probability(input_data, 
                                          missing_strategy,
                                          compact)
        
          
        end
                                        
        if !@regression.nil? && @regression
          prediction = self.predict(input_data, {"method" => CONFIDENCE_CODE, 
                                                 "missing_strategy" => missing_strategy,
                                                 "full" => !compact })
          if compact
            output = [prediction]
          else
            output = prediction
          end
        else  
          output= self._combine_distributions(input_data,
                                              missing_strategy,
                                              CONFIDENCE_CODE)
          if !compact
            names_confidences = @class_names.zip(output)
            
            output = names_confidences.collect { |class_name, confidence| {'category' => class_name, 
                                                                            'confidence'=> confidence} }
          end   
        end 
        
        return output   
      end
      
      def predict_votes(input_data, options={})
        return _predict_votes(input_data,
                              options.fetch("missing_strategy", BigML::LAST_PREDICTION),
                              options.fetch("compact",false))
      end
      
      def _predict_votes(input_data,
                         missing_strategy=LAST_PREDICTION,
                         compact=false)

        # For classification models, Predicts the votes for
        # each possible output class, based on input values.  The input
        # fields must be a dictionary keyed by field name or field ID.
        # For regressions, the output is a single element list
        # containing the prediction.
        # :param input_data: Input data to be predicted
        # :param missing_strategy: LAST_PREDICTION|PROPORTIONAL missing strategy
        #                         for missing fields
        # :param compact: If False, prediction is returned as a list of maps, one
        #                per class, with the keys "prediction" and "probability"
        #                mapped to the name of the class and it's probability,
        #                respectively.  If True, returns a list of probabilities
        #                ordered by the sorted order of the class names.
        #
        if @regression
          
          prediction = self.predict(input_data,
                                    {"full" => !compact,
                                     "method" => PLURALITY_CODE,
                                     "missing_strategy" => missing_strategy})
          if compact
            output = [prediction]
          else
            output = prediction
          end  
        elsif !@boosting.nil?
          raise ArgumentError.new("Voting cannot be computed for boosted ensembles")
        else
          output = self._combine_distributions(
                          input_data,
                          missing_strategy,
                          PLURALITY_CODE)
          if !compact
            names_votes = @class_names.zip(output)
            
            output = names_votes.collect { |class_name, k| {'category' => class_name, 
                                                            'votes'=> k} }

          end   
        end
        
        return output      
              
      end
      
      def _combine_distributions(input_data, missing_strategy,
                                 method=PROBABILITY_CODE)
        # Computes the predicted distributions and combines them to give the
        # final predicted distribution. Depending on the method parameter
        # probability, votes or the confidence are used to weight the models.
        #
        if @models_splits.size > 1
          # If there's more than one chunk of models, they must be
          # sequentially used to generate the votes for the prediction
           votes = MultiVoteList.new([])
           @models_splits.each do |models_split|
             models = self._get_models(models_split)
             multi_model = MultiModel(models,
                                      @api,
                                      @fields,
                                      @class_names)
                                                                            
             votes_split = multi_model.generate_votes_distribution(input_data,
                                                                   missing_strategy,
                                                                   method)

             votes.extend(votes_split)
             
           end   
        else
          # When only one group of models is found you use the
          # corresponding multimodel to predict
          votes = @multi_model.generate_votes_distribution(input_data, 
                                                           missing_strategy, method)
        end
        return votes.combine_to_distribution(false)  
              
      end
      
      def _get_models(models_split)
        
        if !models_split[0].is_a?(Model)
          if !@cache_get.nil? and @cache_get.respond_to?("call")
            # retrieve the models from a cache get function
            begin
              models = models_split.collect {|model_id| @cache_get.call(model_id)}
            rescue
              raise Exception, "Error while calling the user-given function cache"
            end  
          else
            models = models_split.collect {|model_id| retrieve_resource(@api, model_id, ONLY_MODEL)}
          end    
        end
        
        return models  
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
      
      def predict_operating(input_data,
                            missing_strategy=LAST_PREDICTION,
                            operating_point=nil)
        #
        # Computes the prediction based on a user-given operating point.
        #
        kind, threshold, positive_class = BigML::parse_operating_point(operating_point, 
                                                OPERATING_POINT_KINDS_ENSEMBLE, @class_names)
        begin
          predictions = self.send("_predict_%s" % kind, input_data, missing_strategy, false)
          position = @class_names.index(positive_class)
        rescue
          raise ArgumentError.new("The operating point needs to contain a valid
                              positive class, kind and a threshold.")
        end 
        
        if @regression
          prediction = predictions
        else
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
        end
        
        return prediction
            
      end 
      
      def predict_operating_kind(input_data,
                                 missing_strategy=LAST_PREDICTION,
                                 operating_kind=None)
        #Computes the prediction based on a user-given operating kind.
        #
        kind = operating_kind.downcase
        
        if !@boosting.nil? and kind != "probability"
           raise ArgumentError.new("Only probability is allowed as operating kind
                             for boosted ensembles.")
        end
                                     
        if (!OPERATING_POINT_KINDS_ENSEMBLE.include?(kind))
            raise ArgumentError.new("Allowed operating kinds are %s. %s found." %
                             [OPERATING_POINT_KINDS_ENSEMBLE.join(", "), kind])
        end
        
        predictions = self.send("_predict_%s" % kind, input_data, missing_strategy, false)
        
        if @regression
          prediction = predictions
        else
          prediction = predictions.sort_by {|p| [-p[kind], p['category']]}[0]
          prediction["prediction"] = prediction["category"]
          prediction.delete("category")
        end
       
        return prediction
      end     
      
      def predict(input_data, options={})
        # Makes a prediction based on the prediction made by every model.
        #    :param input_data: Test data to be used as input
        #    :param method: **deprecated**. Please check the `operating_kind`
        #                   attribute. Numeric key code for the following
        #                   combination methods in classifications/regressions:
        #          0 - majority vote (plurality)/ average: PLURALITY_CODE
        #          1 - confidence weighted majority vote / error weighted:
        #              CONFIDENCE_CODE
        #          2 - probability weighted majority vote / average:
        #              PROBABILITY_CODE
        #          3 - threshold filtered vote / doesn't apply:
        #              THRESHOLD_CODE
        #    :param options: Options to be used in threshold filtered votes.
        #    :param missing_strategy: numeric key for the individual model's
        #                             prediction method. See the model predict
        #                             method.
        #    :param operating_point: In classification models, this is the point of
        #                            the ROC curve where the model will be used at.
        #                            The operating point can be defined in terms of:
        #                              - the positive_class, the class that is
        #                                important to predict accurately
        #                              - its kind: probability, confidence or voting
        #                              - its threshold: the minimum established
        #                                for the positive_class to be predicted.
        #                                The operating_point is then defined as a
        #                                map with three attributes, e.g.:
        #                                   {"positive_class": "Iris-setosa",
        #                                    "kind": "probability",
        #                                    "threshold": 0.5}
        #    :param operating_kind: "probability", "confidence" or "votes". Sets the
        #                           property that decides the prediction.
        #                           Used only if no operating_point is used
        #    :param median: Uses the median of each individual model's predicted
        #                   node as individual prediction for the specified
        #                   combination method.
        #    :param full: Boolean that controls whether to include the prediction's
        #                 attributes. By default, only the prediction is produced.
        #                 If set to True, the rest of available information is
        #                 added in a dictionary format. The dictionary keys can be:
        #                  - prediction: the prediction value
        #                  - confidence: prediction's confidence
        #                  - probability: prediction's probability
        #                  - path: rules that lead to the prediction
        #                  - count: number of training instances supporting the
        #                           prediction
        #                  - next: field to check in the next split
        #                  - min: minim value of the training instances in the
        #                         predicted node
        #                  - max: maximum value of the training instances in the
        #                         predicted node
        #                  - median: median of the values of the training instances
        #                            in the predicted node
        #                  - unused_fields: list of fields in the input data that
        #                                   are not being used in the model
        #

         return _predict(input_data,
                        options.key?("method") ? options["method"] : nil,
                        options.key?("options") ? options["options"] : nil,
                        options.key?("missing_strategy") ? options["missing_strategy"] : LAST_PREDICTION,
                        options.key?("operating_point") ? options["operating_point"] : nil,
                        options.key?("operating_kind") ? options["operating_kind"] : nil,
                        options.key?("median") ? options["median"] : false,
                        options.key?("full") ? options["full"] : false)
                        
      end

      def _predict(input_data, method=nil,
                  options=nil, missing_strategy=LAST_PREDICTION,
                  operating_point=nil, operating_kind=nil, median=false,
                  full=false)

        # Checks and cleans input_data leaving the fields used in the model
        new_data = self.filter_input_data(input_data, full)
        unused_fields=nil
        if full
            input_data, unused_fields = new_data
        else
            input_data = new_data
        end
        
        # Strips affixes for numeric values and casts to the final field type
        BigML::Util::cast(input_data, @fields)
        
        if median and method.nil?
          # predictions with median are only available with old combiners
          method = PLURALITY_CODE
        end
        
        if method.nil? and operating_point.nil? and operating_kind.nil? and !median
          # operating_point has precedence over operating_kind. If no
          # combiner is set, default operating kind is "probability"
          operating_kind = "probability"
        end
                    
        if !operating_point.nil?
          
          if @regression
              raise ArgumentError.new("The operating_point argument can only be
                                   used in classifications.")
          end
          prediction = self.predict_operating(input_data, 
                                              missing_strategy,operating_point)
              
          if full
            return prediction
          else
            return prediction["prediction"]
          end
          
        end
        
        if !operating_kind.nil?
          if @regression
            # for regressions, operating_kind defaults to the old
            # combiners
            method = operating_kind == "confidence" ? 1 : 0
            return self.predict(input_data, 
                                {"method" => method, 
                                 "options" => options,
                                 "missing_strategy" => missing_strategy, 
                                 "operating_point" => nil, 
                                 "operating_kind" => nil, 
                                 "full" => full})
                                        
          else
            prediction = self.predict_operating_kind(
                                input_data,
                                missing_strategy,
                                operating_kind)
            return prediction
          end    
        end  

          if @models_splits.size > 1
            # If there's more than one chunck of models, they must be
            # sequentially used to generate the votes for the prediction
            votes = BigML::MultiVote.new([], @boosting_offsets)
            @models_splits.each do|models_split|
               
              models = self._get_models(models_split)
              multi_model = BigML::MultiModel.new(models, @api, @fields)
              votes_split = multi_model._generate_votes(
                                        input_data,
                                        missing_strategy, 
                                        unused_fields)
                                                                 
              if median
                 votes_split.predictions.each do|prediction|
                   prediction['prediction'] = prediction['median']
                 end
              end
              votes.concat(votes_split.predictions)
            
            end

          else
            # When only one group of models is found you use the
            # corresponding multimodel to predict
            votes_split = @multi_model._generate_votes(input_data,
                                                     missing_strategy, 
                                                     unused_fields)
            votes = BigML::MultiVote.new(votes_split.predictions, @boosting_offsets)
            if median
               votes.predictions.each do |prediction|
                 prediction['prediction'] = prediction['median']
               end
            end

          end

          if !@boosting.nil? and !@regression
            categories = @fields[@objective_id]["summary"]["categories"].collect {|d| d[0]}
            options = {"categories" => categories}
          end
           
          result = votes.combine(method, options, full)

          if full
             unused_fields = input_data.keys.uniq
 
             votes.predictions.each_with_index do |prediction, index|
                 unused_fields = unused_fields & prediction["unused_fields"].uniq
             end

             if !result.is_a?(Hash)
                 result = {"prediction" => result}
             end

             result['unused_fields'] = unused_fields
  
          end


          return result
      end


      def field_importance_data()
        #
        # Computes field importance based on the field importance information
        # of the individual models in the ensemble.
        #
        field_importance = {}
        field_names = {}
              
        if !@importance.empty?
            field_importance = @importance
            field_names = field_importance.keys.collect {|field_id| {field_id => 
                                     {'name' => @fields[field_id]["name"] }}}
 
            return [field_importance.sort_by{|k,v| -v}, field_names]

        end
        if (!@distributions.nil? and @distributions.is_a?(Array) and 
            @distributions.collect {|item| item.key?('importance')}.all?)
           # Extracts importance from ensemble information
           importances = @distributions.collect {|info| info['importance'] }
           (0..(importances.size()-1)).each do |index|
              model_info = importances[index]
              model_info.each do |field_info|
                 field_id = field_info[0]
                 if !field_importance.include?(field_id)
                    field_importance[field_id] = 0.0
                    name = @fields[field_id]['name']
                    field_names[field_id] = {'name' => name}
                 end
                 field_importance[field_id] += field_info[1]
              end
           end 
        else
           # Old ensembles, extracts importance from model information
           @model_ids.each do |model_id|
              local_model = BigML::BaseModel.new(model_id, @api)
              local_model.field_importance.each do |field_info|
                 field_id = field_info[0]
                 if !field_importance.include?(field_id)
                    field_importance[field_id] = 0.0
                    name = @fields[field_id]['name']
                    field_names[field_id] = {'name' => name}
                 end
                 field_importance[field_id] += field_info[1]
              end
           end          
        end

        number_of_models = @model_ids.size
 
        field_importance.keys.each do |field_id|
          field_importance[field_id] /= number_of_models
        end

        return [field_importance.sort_by{|k,v| -v}, field_names] 

      end

      def print_importance(out=$STDOUT)
        # Prints ensemble field importance
        print_importance(out)
      end

      def get_data_distribution(distribution_type="training")
        # Returns the required data distribution by adding the distributions
        #   in the models
        ensemble_distribution = []
        categories = []
        distribution = []
        @distributions.each do |model_distribution|
           summary = model_distribution[distribution_type]
           if summary.include?('bins')
              distribution = summary['bins']
           elsif summary.include?('counts')
              distribution = summary['counts']
           elsif summary.include?('categories')
              distribution = summary['categories']
           else
              distribution = [] 
           end     
      
           distribution.each do|point,instances|
              if categories.include?(point)
                 ensemble_distribution[categories.index(point)] += instances
              else
                 categories << point
                 ensemble_distribution << [point, instances]
              end
           end 
 
        end

        return ensemble_distribution.sort_by {|x| x[0] }

      end

      def summarize(out=$STDOUT)
        # Prints ensemble summary. Only field importance at present.
        distribution = get_data_distribution("training")

        unless !distribution.nil?
          out.puts "Data distribution:"
          print_distribution(distribution, out)
          out.puts 
          out.puts
        end

        predictions = get_data_distribution("predictions")

        unless predictions.nil?
          out.puts "Predicted distribution:"
          print_distribution(predictions, out)
          out.puts
          out.puts 
        end

        out.puts "Field importance:"
        print_importance(out)
        out.flush
      end

      def all_model_fields(max_models=nil)
        # Retrieves the fields used as predictors in all the ensemble
        #   models

        fields = {}
        models = []
        objective_id = nil 
        no_objective_id = false

        if @models_splits[0][0].is_a?(BigML::Model)
           @models_splits.each do |split|
              models.concat(split)
           end 
        else
           models = @model_ids
        end
        models.each_with_index do |model_id,index|
           if model_id.is_a?(BigML::Model)
             local_model = model_id
           elsif BigML::use_cache(@cache_get)
             local_model = @cache_get.call(model_id)
           else
             local_model = BigML::Model.new(model_id, @api)
           end

           if (!max_models.nil? and index > 0 and 
               (index % max_models == 0))
             GC.start
           end
	   fields.merge!(local_model.fields)
           if (!objective_id.nil? and 
               objective_id != local_model.objective_id)
              # the models' objective field have different ids, no global id
              no_objective_id = true
           else
              objective_id = local_model.objective_id
           end
        end

        if no_objective_id
          objective_id = nil 
        end

        GC.start()

        return [fields, objective_id]

      end
 
  end

end

