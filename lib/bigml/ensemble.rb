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
 
  def self.use_cache(cache_get)
     # Checks whether the user has provided a cache get function to retrieve
     # local models.
     #
     return (!cache_get.nil? and cache_get.respond_to?("call"))
  end

  class Ensemble 
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
         @models_splits = []
         @multi_model = nil 
         @cache_get = nil

         if ensemble.is_a?(Array)
             if ensemble.collect {|model| model.is_a?(BigML::Model)}.all? 
                models = ensemble
                @model_ids = models.collect{|local_model| local_model.resource_id}
             else
                begin
                   models = ensemble.collect {|model| BigML::get_model_id(model) }
                   @model_ids = models
                rescue Exception
                   raise ArgumentError 'Failed to verify the list of models.
                                       Check your model id values: %s' % ensemble
                end
             end 
             @distributions=nil
         else
            ensemble = get_ensemble_resource(ensemble)
            @resource_id = BigML::get_ensemble_id(ensemble)
            ensemble_id = @resource_id
            ensemble = BigML::retrieve_resource(@api, @resource_id, nil)
            models = ensemble['object']['models']
            @distributions = ensemble['object'].fetch('distributions', nil)
            @model_ids = models
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
                    raise Exception 'Error while calling the user-given
                                     function cache_get'
                  end
               else
                  models = @models_splits[0].collect {|model_id| BigML::retrieve_resource(@api, 
                                                                        model_id, 
                                                                        ONLY_MODEL ) } 
               end 
            end
            @multi_model = BigML::MultiModel.new(models, @api)

         else
           @cache_get = cache_get
         end

         @fields, @objective_id = all_model_fields(max_models)

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
                   raise ArgumentError "The JSON file does not seen 
                                       to contain a valid BigML ensemble
                                       representation."
                end
            rescue IOError
                @resource_id = BigML::get_ensemble_id(ensemble)
                if @resource_id.nil?
                   if !ensemble.index("ensemble/").nil?
                      raise Exception @api.error_message(ensemble, 
                                                         'ensemble',
                                                         'get')
                   else
                      raise IOError "Failed to open the expected
                                     JSON file at %s" % ensemble
                   end
                end
            rescue Exception
               raise ArgumentError "Failed to interpret %s.
                                    JSON file expected. " % ensemble
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

      def predict(input_data, options={})
        # Makes a prediction based on the prediction made by every model.

        # :param input_data: Test data to be used as input
        # :param by_name: Boolean that is set to True if field_names (as
        #                alternative to field ids) are used in the
        #                input_data dict
        # :param method: numeric key code for the following combination
        #               methods in classifications/regressions:
        #      0 - majority vote (plurality)/ average: PLURALITY_CODE
        #      1 - confidence weighted majority vote / error weighted:
        #          CONFIDENCE_CODE
        #      2 - probability weighted majority vote / average:
        #          PROBABILITY_CODE
        #      3 - threshold filtered vote / doesn't apply:
        #          THRESHOLD_CODE
        # The following parameter causes the result to be returned as a list
        # :param with_confidence: Adds the confidence, distribution, counts
        #                        and median information to the node prediction.
        #                        The result is given in a list format output.
        # The following parameters cause the result to be returned as a dict
        # :param add_confidence: Adds confidence to the prediction
        # :param add_distribution: Adds the predicted node's distribution to the
        #                         prediction
        # :param add_count: Adds the predicted nodes' instances to the
        #                   prediction
        # :param add_median: Adds the median of the predicted nodes' distribution
        #                   to the prediction
        # :param add_min: Boolean, if True adds the minimum value in the
        #                prediction's distribution (for regressions only)
        # :param add_unused_fields: Boolean, if True adds the information about
        #                the fields in the input_data that are not
        #                 being used in the model as predictors. 
        # :param add_max: Boolean, if True adds the maximum value in the
        #                prediction's distribution (for regressions only)
        # :param options: Options to be used in threshold filtered votes.
        # :param missing_strategy: numeric key for the individual model's
        #                         prediction method. See the model predict
        #                         method.
        # :param median: Uses the median of each individual model's predicted
        #               node as individual prediction for the specified
        #               combination method.
        #  
         return _predict(input_data,
                        options.key?("by_name") ? options["by_name"] : true,
                        options.key?("method") ? options["method"] : PLURALITY_CODE,
                        options.key?("with_confidence") ? options["with_confidence"] : false,
                        options.key?("add_confidence") ? options["add_confidence"] : false,
                        options.key?("add_distribution") ? options["add_distribution"] : false,
                        options.key?("add_count") ? options["add_count"] : false,
                        options.key?("add_median") ? options["add_median"] : false,
                        options.key?("add_min") ? options["add_min"] : false,
                        options.key?("add_max") ? options["add_max"] : false,
                        options.key?("add_unused_fields") ? options["add_unused_fields"] : false,
                        options.key?("options") ? options["options"] : nil,
                        options.key?("missing_strategy") ? options["missing_strategy"] : LAST_PREDICTION,
                        options.key?("median") ? options["median"] : false)
      end

      def _predict(input_data, by_name=true, method=PLURALITY_CODE,
                with_confidence=false, add_confidence=false,
                add_distribution=false, add_count=false, add_median=false,
                add_min=false, add_max=false, add_unused_fields=false,
                options=nil, missing_strategy=LAST_PREDICTION, median=false)

          if @models_splits.size > 1
            # If there's more than one chunck of models, they must be
            # sequentially used to generate the votes for the prediction
            votes = BigML::MultiVote.new([])
            @models_splits.each do|models_split|
               if !models_split[0].is_a?(BigML::Model)
                 if BigML::use_cache(@cache_get)
                    begin
                      models = models_split.collect {|model_id| @cache_get.call(model_id)}
                    rescue Exception
                       raise Exception "Error while calling 
                                       the user-given function cache "
                    end
                 else
                   models = models_split.collect {|model_id| BigML::retrieve_resource(
						   @api, model_id, ONLY_MODEL)}
                 end          
               end
               multi_model = BigML::MultiModel.new(models, @api)
               votes_split = multi_model.generate_votes(
                                         input_data, by_name,
                                         missing_strategy, 
                                         (add_median or median),
                                         add_min, add_max, add_unused_fields)
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
            votes_split = @multi_model.generate_votes(input_data, by_name,
                                                     missing_strategy, 
                                                     (add_median or median),
                                                     add_min, add_max, add_unused_fields)
            
            votes = BigML::MultiVote.new(votes_split.predictions)
            if median
               votes.predictions.each do |prediction|
                 prediction['prediction'] = prediction['median']
               end
            end

          end

          result = votes.combine(method, with_confidence,
                               add_confidence, add_distribution,
                               add_count, add_median, add_min,
                               add_max, options)

          if add_unused_fields
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
        # Prints ensemble field importance
        print_importance(out)
      end

      def get_data_distribution(distribution_type="training")
        # Returns the required data distribution by adding the distributions
        #   in the models
        ensemble_distribution = []
        categories = []
        @distributions.each do |model_distribution|
           summary = model_distribution[distribution_type]
           if summary.include?('bins')
              distribution = summary['bins']
           elsif summary.include?('counts')
              distribution = summary['counts']
           elsif summary.include?('categories')
              distribution = summary['categories']
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

        out.puts "Data distribution:"
        print_distribution(distribution, out)
        out.puts 
        out.puts

        predictions = get_data_distribution("predictions")

        out.puts "Predicted distribution:"
        print_distribution(predictions, out)
        out.puts
        out.puts 

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

