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

# A Multiple Local Predictive Model.

# This module defines a Multiple Model to make predictions locally using multiple
# local models.

# This module cannot only save you a few credits, but also enormously
# reduce the latency for each prediction and let you use your models
# offline.

# api = BigML::Api.new()
# models =api.list_models("tags__in=my_tag")["objects"].collect {|model| api.get_model(model["resource"])}
# model = MultiModel(models)
# model.predict({"petal length" => 3, "petal width" => 1})
require_relative 'multivote'
require_relative 'model'
require_relative 'multivotelist'

module BigML
					
  def self.read_votes(votes_files, model, data_locale=nil)
    # Reads the votes found in the votes' files.

    #  Returns a list of MultiVote objects containing the list of predictions.
    #  votes_files parameter should contain the path to the files where votes
    #  are stored
    #  In to_prediction parameter we expect the method of a local model object
    #  that casts the string prediction values read from the file to their
    #  real type. For instance
    #       local_model = Model.new(model)
    #       prediction = local_model.to_prediction("1")
    #       prediction.is_a?(Integer)
    #       true
    #       read_votes(["my_predictions_file"], local_model.to_prediction)
    #  data_locale should contain the string identification for the locale
    #  used in numeric formatting.
    #
    votes = []
    (0..(votes_files.size-1)).each do |order|
       votes_file = votes_files[order]
       index = 0
       CSV.foreach(votes_file) do |row|
          #TODO build method to_prediction
          prediction = model.to_prediction(row[0], data_locale) 
          if (index > (votes.size-1))
             votes << MultiVote.new([])
          end
          distribution = nil
          instances = nil

          if row.size > 2
             distribution = JSON.parse(row[2])
             instances = int(row[3])
             begin
                confidence = row[1].to_f
             rescue Exception
                confidence = 0.0
             end
          end
          prediction_row = [prediction, confidence, order,
                            distribution, instances]
          votes[index].append_row(prediction_row)
          index += 1
       end 

       return votes

    end

   end
  
   class MultiModel
      # A multiple local model.

      # Uses a number of BigML remote models to build a local version that can be
      # used to generate predictions locally.

      def initialize(models, api=nil, fields=nil, class_names=nil)
        @models = []
        @class_names = class_names
        if models.is_a?(Array)
            if models.collect {|model| model.is_a?(BigML::Model) }.all?
                @models = models
            else
                models.each do |model|
                  @models << BigML::Model.new(model, api, fields)
                end
            end
        else
            @models << BigML::Model.new(models, api, fields)
        end
      end 

      def list_models()
        # Lists all the model/ids that compound the multi model.
        return @models.collect {|model| model.resource() }
      end

      def predict(input_data, method=PLURALITY_CODE, options=nil,
                  missing_strategy=LAST_PREDICTION, full=false)
        # Makes a prediction based on the prediction made by every model.
        #         The method parameter is a numeric key to the following combination
        #         methods in classifications/regressions:
        #            0 - majority vote (plurality)/ average: PLURALITY_CODE
        #            1 - confidence weighted majority vote / error weighted:
        #                CONFIDENCE_CODE
        #            2 - probability weighted majority vote / average:
        #                PROBABILITY_CODE
        #            3 - threshold filtered vote / doesn't apply:
        #                THRESHOLD_CODE
        #
      end
      
      def predict(input_data, options={})
        # Makes a prediction based on the prediction made by every model.

        # The method parameter is a numeric key to the following combination
        #  methods in classifications/regressions:
        #     0 - majority vote (plurality)/ average: PLURALITY_CODE
        #     1 - confidence weighted majority vote / error weighted:
        #         CONFIDENCE_CODE
        #     2 - probability weighted majority vote / average:
        #         PROBABILITY_CODE
        #     3 - threshold filtered vote / doesn't apply:
        #         THRESHOLD_CODE
        # 
                                                                          
        return _predict(input_data,
                        options.key?("method") ? options["method"] : PLURALITY_CODE,
                        options.key?("options") ? options["options"] : nil,
                        options.key?("missing_strategy") ? options["missing_strategy"] : LAST_PREDICTION, 
                        options.key?("full") ? options["full"] : false)
      end

      def _predict(input_data, method=PLURALITY_CODE, options=nil,
                  missing_strategy=LAST_PREDICTION, full=false)
        # Makes a prediction based on the prediction made by every model.

        # The method parameter is a numeric key to the following combination
        #  methods in classifications/regressions:
        #     0 - majority vote (plurality)/ average: PLURALITY_CODE
        #     1 - confidence weighted majority vote / error weighted:
        #         CONFIDENCE_CODE
        #     2 - probability weighted majority vote / average:
        #         PROBABILITY_CODE
        #     3 - threshold filtered vote / doesn't apply:
        #         THRESHOLD_CODE
        # 

        votes = generate_votes(input_data,
                               missing_strategy)
        
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
      
      def generate_votes_distribution(input_data,
                                      missing_strategy=LAST_PREDICTION,
                                      method=PROBABILITY_CODE)
        votes = []
        @models.each do|model|
          model.class_names = @class_names
          if method == PLURALITY_CODE 
            prediction_info = [0.0] * @class_names.size
            prediction = model.predict(input_data, {"missing_strategy" => missing_strategy, "full" => false})
            prediction_info[@class_names.index(prediction)] = 1.0

          else
            if method == CONFIDENCE_CODE
              prediction_info = model.predict_confidence(input_data, missing_strategy, true)
            else
              prediction_info = model.predict_probability(input_data, {"missing_strategy" => missing_strategy, "compact" => true})
            end

          end  
          
          votes << prediction_info
        end  
                
        return MultiVoteList.new(votes)

      end  

      def generate_votes(input_data,
                         missing_strategy=LAST_PREDICTION)

         # Generates a MultiVote object that contains the predictions
         #   made by each of the models.
         votes = MultiVote.new([])
         (0..(@models.size-1)).each do |order|
           model = @models[order]
           prediction_info = model.predict(input_data, 
                                  {'missing_strategy' => missing_strategy,
                                   'full' => true})
           if !model.boosting.nil?
             votes.boosting = true
             prediction_info.merge!({"weight" => model.boosting.fetch("weight") })
             if !model.boosting.fetch("objective_class", nil).nil?
                prediction_info.merge!({"class" => model.boosting.fetch("objective_class")})
             end
           end
           
            votes.append(prediction_info)
         end 
         
         return votes
         
      end
      
      def _generate_votes(input_data,
                          missing_strategy=LAST_PREDICTION,
                          unused_fields=false)

         # Generates a MultiVote object that contains the predictions
         # made by each of the models. Please note that this function
         # calls a _predict method which assumes input data has been
         # properly checked against the model fields Only casting
         # to the correct type will be applied.

         votes = MultiVote.new([])
         (0..(@models.size-1)).each do |order|
           model = @models[order]

           prediction_info = model._predict(input_data, missing_strategy, nil, nil, unused_fields)
           if !model.boosting.nil?
             votes.boosting = true
             prediction_info.merge!({"weight" => model.boosting.fetch("weight") })
             if !model.boosting.fetch("objective_class", nil).nil?
                prediction_info.merge!({"class" => model.boosting.fetch("objective_class")})
             end
           end
           
            votes.append(prediction_info)
            
         end 
         
         return votes
         
      end

      def batch_predict(input_data_list, output_file_path=nil,
                       reuse=false,
                      missing_strategy=LAST_PREDICTION, headers=nil,
                      to_file=true, use_median=false)
         # "Makes predictions for a list of input data.

         #  When the to_file argument is set to True, the predictions
         #  generated for each model are stored in an output
         #  file. The name of the file will use the following syntax:
         #       model_[id of the model]__predictions.csv
         #  For instance, when using model/50c0de043b563519830001c2 to predict,
         #  the output file name will be
         #       model_50c0de043b563519830001c2__predictions.csv
         #   On the contrary, if it is False, the function returns a list
         #   of MultiVote objects with the model's predictions.

         add_headers = (input_data_list[0].is_a?(Array)) and 
                        !headers.nil and 
                        headers.size == input_data_list[0].size

         if !add_headers and !input_data_list[0].is_a?(Hash)
            raise ArgumentError, "Input data list is not a dictionary or the
                                headers and input data information are not
                                consistent."
         end

         order = 0
         if !to_file
            votes = []
         end

         @models.each do |model|
            order += 1
            out = nil
            if to_file
               output_file = BigML::Util::get_predictions_file_name(model.resource_id,
                                                       output_file_path)
               if reuse
                  begin
                     predictions_file = File.open(output_file, "w")
                     predictions_file.close
                  rescue Exception
                     pass
                  end
               end

               begin 
                 out = File.new(output_file, "w") 
               rescue Exception 
                  raise Exception, "Cannot find %s directory." % output_file_path
               end 
            end

            input_data_list.each_with_index do|input_data,index|

               if add_headers
                   input_data = Hash[headers.zip(input_data).collect { |item| [item[0], item[1]] } ]
               end

               prediction = model.predict(input_data, {'full' => true,
                                                       'missing_strategy' => missing_strategy})

               if use_median and model.tree.regression
                  # if median is to be used, we just place it as prediction
                  # starting the list
                  prediction["prediction"] = prediction["median"]
               end           
             
               if to_file
                 prediction = BigML::cast_prediction(prediction, "list", true, false, false, true, true)

                 out.puts "%s" % prediction 
               else
                 if votes.size <= index
                   votes << MultiVote.new([])
                 end
                 votes[index].append(prediction)
               end
            end

            if !out.nil?
               out.close
            end
         end

         if !to_file
           return votes
         end

      end

      def batch_votes(predictions_file_path, data_locale=nil)
        # Adds the votes for predictions generated by the models.

        #   Returns a list of MultiVote objects each of which contains a list
        #   of predictions.

        votes_files = []
        @models.each do |model|
           votes_files << BigML::Util::get_predictions_file_name(model.resource_id, predictions_file_path)
        end

        return BigML::read_votes(votes_files, @models[0], data_locale)

      end

  end

end

