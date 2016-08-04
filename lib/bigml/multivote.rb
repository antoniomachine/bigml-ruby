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
module BigML

 PLURALITY = 'plurality'
 CONFIDENCE = 'confidence weighted'
 PROBABILITY = 'probability weighted'
 THRESHOLD = 'threshold'
 PLURALITY_CODE = 0
 CONFIDENCE_CODE = 1
 PROBABILITY_CODE = 2
 THRESHOLD_CODE = 3

 PREDICTION_HEADERS = ['prediction', 'confidence', 'order', 'distribution',
                      'count']
 COMBINATION_WEIGHTS = {
    PLURALITY => nil,
    CONFIDENCE => 'confidence',
    PROBABILITY => 'probability',
    THRESHOLD => nil}
 COMBINER_MAP = {
    PLURALITY_CODE => PLURALITY,
    CONFIDENCE_CODE => CONFIDENCE,
    PROBABILITY_CODE => PROBABILITY,
    THRESHOLD_CODE => THRESHOLD}
  WEIGHT_KEYS = {
    PLURALITY => nil,
    CONFIDENCE => ['confidence'],
    PROBABILITY => ['distribution', 'count'],
    THRESHOLD => nil}

  DEFAULT_METHOD = 0
  BINS_LIMIT = 32

  NUMERICAL_COMBINATION_METHODS = {
    PLURALITY => "avg",
    CONFIDENCE => "error_weighted",
    PROBABILITY => "avg"}

  def self.ws_confidence(prediction, distribution, ws_z=1.96, ws_n=nil)
    # Wilson score interval computation of the distribution for the prediction

    #   expected arguments:
    #        prediction: the value of the prediction for which confidence is
    #                    computed
    #        distribution: a distribution-like structure of predictions and
    #                      the associated weights. (e.g.
    #                      [['Iris-setosa', 10], ['Iris-versicolor', 5]])
    #        ws_z: percentile of the standard normal distribution
    #        ws_n: total number of instances in the distribution. If absent,
    #              the number is computed as the sum of weights in the
    #              provided distribution
    if distribution.is_a?(Array)
        new_distribution = {}
        distribution.each do |it|
           new_distribution[it[0]] = it[1]
        end 
        distribution = new_distribution
    end

    ws_p = distribution[prediction]
    if ws_p < 0
        raise ArgumentError, "The distribution weight must be a positive value"
    end

    ws_norm = distribution.values.inject(:+).to_f

    if ws_norm != 1.0
        ws_p = ws_p / ws_norm
    end

    if ws_n.nil?
        ws_n = ws_norm
    else
        ws_n = ws_n.to_f
    end

    if ws_n < 1
        raise ArgumentError, "The total of instances in the distribution must be a positive integer"
    end
    ws_z = ws_z.to_f
    ws_z2 = ws_z * ws_z
    ws_factor = ws_z2 / ws_n
    ws_sqrt = Math.sqrt((ws_p * (1 - ws_p) + ws_factor / 4) / ws_n)
   
  
    result=(ws_p + ws_factor / 2 - ws_z * ws_sqrt) / (1 + ws_factor)

    return result

  end

  def self.merge_distributions(distribution, new_distribution)
    # Adds up a new distribution structure to a map formatted distribution
  
    new_distribution.each do |value, instances|
       if !distribution.key?(value)
          distribution[value] = 0
       end 
       distribution[value] += instances
    end

    return  distribution

  end

  def self.merge_bins(distribution, limit)
    # Merges the bins of a regression distribution to the given limit number

    length = distribution.size
    if limit < 1 or length <= limit or length < 2
        return distribution
    end

    index_to_merge = 2
    shortest = Float::INFINITY

    (1..(length-1)).each do |index|
      distance = distribution[index][0] - distribution[index - 1][0]
      if distance < shortest
         shortest = distance
         index_to_merge = index
      end  
    end
 
    new_distribution = distribution[0..(index_to_merge - 2)] 
    left = distribution[index_to_merge - 1]
    right = distribution[index_to_merge]
    new_bin = [(left[0] * left[1] + right[0] * right[1]) /
               (left[1] + right[1]), left[1] + right[1]]
    new_distribution << new_bin
    if index_to_merge < (length - 1)
        new_distribution.concat(distribution[(index_to_merge + 1)..-1])
    end

    return merge_bins(new_distribution, limit)

  end

  class MultiVote 
     # A multiple vote prediction
     # Uses a number of predictions to generate a combined prediction.
     #
     attr_accessor :predictions
     def initialize(predictions)
       # Init method, builds a MultiVote with a list of predictions

       # The constuctor expects a list of well formed predictions like:
       #    {'prediction' => 'Iris-setosa', 'confidence' => 0.7}
       #    Each prediction can also contain an 'order' key that is used
       #    to break even in votations. The list order is used by default.
       #
       @predictions = []

       if predictions.is_a?(Array)
          @predictions.concat(predictions)
       else
          @predictions << predictions
       end

       if !predictions.collect {|prediction| prediction.key?('order') }.all?
          (0..(@predictions.size-1)).each do |i|
             @predictions[i]["order"] = i
          end
       end

     end

     def grouped_distribution(cls, instance)
        # Returns a distribution formed by grouping the distributions of
        # each predicted node.

        joined_distribution = {}
        distribution_unit = 'counts'
       
        instance["predictions"].each do |prediction|
           joined_distribution=merge_distributions(joined_distribution, 
                                                   { prediction['distribution'][0][0] => 
                                                     prediction['distribution'][0][1] })
           # when there's more instances, sort elements by their mean
           distribution = joined_distribution.sort_by {|x| x[0]}.collect {|k, v| [k,v]}
           if distribution_unit == 'counts'
              distribution_unit = distribution.size > BINS_LIMIT ? 'bins' : 'counts'
           end
           distribution = merge_bins(distribution, BINS_LIMIT)
        end

        return {'distribution' => distribution,
                'distribution_unit' => distribution_unit}
     end

     def self.avg(instance, with_confidence=false,
                  add_confidence=false, add_distribution=false,
                  add_count=false, add_median=false, add_min=false, add_max=false)

        if !instance.predictions.empty? and with_confidence and 
            !instance.predictions.collect{|prediction| prediction.key?("confidence")}.all? 
            raise Exception, "Not enough data to use the selected prediction method. Try creating your model anew."
        end
        total = instance.predictions.size
        result = 0.0
        median_result = 0.0
        confidence = 0.0
        instances = 0
        d_min = Float::INFINITY 
        d_max = Float::INFINITY

        instance.predictions.each do |prediction|
            result += prediction['prediction']
            if add_median
                median_result += prediction['median']
            end
            if with_confidence or add_confidence
                confidence += prediction['confidence']
            end
            if add_count
                instances += prediction['count']
            end
            if add_min and d_min > prediction['min']
                d_min = prediction['min']
            end
            if add_max and d_max < prediction['max']
                d_max = prediction['max']
            end
        end

        if with_confidence
            return total > 0 ? [result / total, confidence / total] : [ Float::INFINITY , 0]
        end

        if (add_confidence or add_distribution or add_count or
                add_median or add_min or add_max)

            output = {'prediction' => total > 0 ? result / total :  Float::INFINITY} 
            if add_confidence
                 output['confidence'] = total > 0 ?  confidence / total : 0
            end

            if add_distribution
                output.merge!(cls.grouped_distribution(instance))
            end

            if add_count
                output['count'] = instances
            end

            if add_median
                output['median'] = total > 0 ?  median_result / total : Float::INFINITY
            end

            if add_min
                output['min'] = d_min
            end

            if add_max
                output['max'] = d_max
            end

            return output
        end

        return total > 0 ?  result / total : Float::INFINITY
 
     end

     def self.error_weighted(instance, with_confidence=false,
                       add_confidence=false, add_distribution=false,
                       add_count=false, add_median=false, add_min=false,
                       add_max=false)
        #  Returns the prediction combining votes using error to compute weight

        #   If with_confidences is true, the combined confidence (as the
        #   error weighted average of the confidences of the multivote
        #   predictions) is also returned
        # 

        if !instance.predictions.empty? and with_confidence and !instance.predictions.collect{|prediction| prediction.key?('confidence')}.all? 
            raise Exception "Not enough data to use the selected prediction method. Try creating your model anew."
        end

        top_range = 10
        result = 0.0
        median_result = 0.0
        instances = 0
        d_min = Float::INFINITY
        d_max = Float::INFINITY
 
        normalization_factor = MultiVote.normalize_error(instance, top_range)
        if normalization_factor == 0
            if with_confidence
               return [Float::INFINITY, 0]
            else
               return Float::INFINITY
            end
        end

        if with_confidence or add_confidence
            combined_error = 0.0
        end

        instance.predictions.each do |prediction|
            result += prediction['prediction'] * prediction['_error_weight']
            if add_median
                median_result += (prediction['median'] *
                                  prediction['_error_weight'])
            end

            if add_count
                instances += prediction['count']
            end

            if add_min and d_min > prediction['min']
                d_min = prediction['min']
            end

            if add_max and d_max < prediction['max']
                d_max = prediction['max']
            end

            if with_confidence or add_confidence
                combined_error += (prediction['confidence'] *
                                   prediction['_error_weight'])
            end

            prediction.delete('_error_weight')
        end

        if with_confidence
            return [result / normalization_factor,
                    combined_error / normalization_factor]
        end

        if (add_confidence or add_distribution or add_count or
                add_median or add_min or add_max)
            output = {'prediction' => result / normalization_factor}
            if add_confidence
                output['confidence'] =  combined_error / normalization_factor
            end

            if add_distribution
                output.merge!(cls.grouped_distribution(instance))
            end

            if add_count
                output['count'] = instances
            end

            if add_median
                output['median'] = median_result / normalization_factor
            end

            if add_min
                output['min'] = d_min
            end

            if add_max
                output['max'] = d_max
            end

            return output
        end

        return result / normalization_factor

     end

     def self.normalize_error(instance, top_range)
        # Normalizes error to a [0, top_range] and builds probabilities

        if !instance.predictions.empty? and
             !instance.predictions..collect {|prediction| prediction.key?('confidence') }.all?
            raise Exception , "Not enough data to use the selected prediction method. Try creating your model anew."
        end

        error_values = instance.predictions.collect {|prediction| prediction['confidence']}

        max_error = error_values.max
        min_error = error_values.min
        error_range = 1.0 * (max_error - min_error)
        normalize_factor = 0
        if error_range > 0
            # Shifts and scales predictions errors to [0, top_range].
            # Then builds e^-[scaled error] and returns the normalization
            # factor to fit them between [0, 1]
            instance.predictions.each do |prediction|
                delta = (min_error - prediction['confidence'])
                prediction['_error_weight'] = Math.exp(delta / error_range *
                                                       top_range)
                normalize_factor += prediction['_error_weight']
            end
        else
            instance.predictions.each do |prediction|
                prediction['_error_weight'] = 1
            end
            normalize_factor = instance.predictions.size
        end
        return normalize_factor

     end

     def is_regression()
        # Returns True if all the predictions are numbers
	return @predictions.collect{|prediction| prediction["prediction"].is_a?(Numeric) }.all?
     end

     def next_order()
        # Return the next order to be assigned to a prediction

        #    Predictions in MultiVote are ordered in arrival sequence when
        #   added using the constructor or the append and extend methods.
        #   This order is used to break even cases in combination
        #   methods for classifications.

        if !@predictions.empty?
            return @predictions[-1]['order'] + 1
        end
        return 0
     end

     def combine(method=DEFAULT_METHOD, with_confidence=false,
                add_confidence=false, add_distribution=false,
                add_count=false, add_median=false, add_min=false,
                add_max=false, options=nil)
        #  "Reduces a number of predictions voting for classification and
        #   averaging predictions for regression.

        #   method will determine the voting method (plurality, confidence
        #   weighted, probability weighted or threshold).
        #   If with_confidence is true, the combined confidence (as a weighted
        #   average of the confidences of votes for the combined prediction)
        #   will also be given.
        # 
        # there must be at least one prediction to be combined
        if @predictions.empty?
            raise Exception "No predictions to be combined."
        end

        method = COMBINER_MAP.fetch(method, COMBINER_MAP[DEFAULT_METHOD])
        keys = WEIGHT_KEYS.fetch(method, nil)
        # and all predictions should have the weight-related keys

        if !keys.nil?
            keys.each do |key|
	       if !@predictions.collect{|prediction| prediction.key?(key) }.all?
                 raise Exception, "Not enough data to use the selected prediction method. Try creating your model anew." 
               end
            end
        end

        if is_regression()
            @predictions.each do |prediction|
              if prediction['confidence'].nil?
                 prediction['confidence'] = 0
              end
            end

            function = MultiVote.method(NUMERICAL_COMBINATION_METHODS.fetch(method, "avg"))

            return function.call(self, with_confidence, add_confidence, add_distribution,
                                    add_count, add_median, add_min, add_max) 


        else
            if method == THRESHOLD
                if options.nil?
                    options = {}
                end
                predictions = single_out_category(options)
            elsif method == PROBABILITY
                predictions = MultiVote.new([])
                predictions.predictions = probability_weight()
            else
                predictions = self
            end

            return predictions.combine_categorical(
                COMBINATION_WEIGHTS.fetch(method, nil),
                with_confidence,
                add_confidence,
                add_distribution,
                add_count)
        end

     end
 
     def probability_weight()
        # Reorganizes predictions depending on training data probability
        predictions = []
        @predictions.each do |prediction|
           if !prediction.include?('distribution') or !prediction.include?('count')
              raise Exception, "Probability weighting is not available because distribution information is missing."
           end

           total = prediction['count']
           if total < 1 or !total.is_a?(Integer)
              raise Exception, "Probability weighting is not available 
                                because distribution seems to have %s as number 
                                of instances in a node" % [total]
           end
           order = prediction['order']
           prediction['distribution'].each do |prediction, instances|
             predictions << {'prediction' => prediction, 'probability' => instances.to_f/total,
                             'count' => instances, 'order' =>  order}
           end

        end

        return predictions
     end

     def combine_distribution(weight_label='probability')
        # Builds a distribution based on the predictions of the MultiVote

        #   Given the array of predictions, we build a set of predictions with
        #   them and associate the sum of weights (the weight being the
        #   contents of the weight_label field of each prediction)

        if !@predictions.collect {|prediction| prediction.include?(weight_label)}.all?
           Exception "Not enough data to use the selected  prediction method. Try creating your model anew." 
        end

        distribution = {}
        total = 0
        @predictions.each do |prediction|
            if !distribution.include?(prediction["prediction"])
               distribution[prediction['prediction']] = 0.0
            end
            distribution[prediction['prediction']] += prediction[weight_label]
            total += prediction['count']
        end 

        if total > 0
           distribution = distribution.collect{ |key, value| [key, value]}
        else
           distribution = []
        end

        return [distribution, total] 
     end

     def combine_categorical(weight_label=nil, with_confidence=false,
                             add_confidence=false, add_distribution=false,
                             add_count=false)
        # Returns the prediction combining votes by using the given weight:

        #    weight_label can be set as:
        #    nil:          plurality (1 vote per prediction)
        #    'confidence':  confidence weighted (confidence as a vote value)
        #    'probability': probability weighted (probability as a vote value)

        #    If with_confidence is true, the combined confidence (as a weighted
        #    average of the confidences of the votes for the combined
        #    prediction) will also be given.
        #
        mode = {}
        instances = 0
        if weight_label.nil?
            weight = 1
        end

        @predictions.each do |prediction|
            if !weight_label.nil?
               if !COMBINATION_WEIGHTS.values.include?(weight_label) 
                   raise Exception, "Wrong weight_label value."
               end
               if !prediction.include?(weight_label)
                   raise Exception, "Not enough data to use the selected prediction method. Try creating your model anew."
               else
                   weight = prediction[weight_label]
               end
            end
            category = prediction['prediction']
            if add_count
               instances += prediction['count']
            end
            if mode.include?(category)
                mode[category] = {"count" => mode[category]["count"] + weight,
                                 "order" => mode[category]["order"]}
            else
                mode[category] = {"count"=> weight,
                                  "order"=> prediction['order']}
            end
        end

        prediction = mode.sort_by {|key, x| [x["count"], -x["order"], key]}.collect {|key,value|
									[key, value]}.reverse[0][0]

        if with_confidence or add_confidence
            if @predictions[0].include?('confidence')
                data = weighted_confidence(prediction, weight_label)
                prediction = data[0]
                combined_confidence = data[1] 
            # if prediction had no confidence, compute it from distribution
            else
                combined_distribution = combine_distribution()
                distribution = combined_distribution[0]
                count = combined_distribution[1]
                combined_confidence = BigML::ws_confidence(prediction, distribution, 1.96,
                                                    count)
            end
        end
        
        if with_confidence
            return prediction, combined_confidence
        end

        if add_confidence or add_distribution or add_count
            output = {'prediction' => prediction}
            if add_confidence
                output['confidence']=combined_confidence
            end

            if add_distribution
               grouped_dis =  self.grouped_distribution(self)
               output["distribution"] = grouped_dis["distribution"]
               output["distribution_unit"] = grouped_dis["distribution_unit"]
            end

            if add_count
                output['count'] = instances
            end

            return output
        end

        return prediction

     end

     def weighted_confidence(combined_prediction, weight_label)
        #Compute the combined weighted confidence from a list of predictions

        predictions = []
        @predictions.each do |prediction|
          if prediction['prediction'] == combined_prediction 
              predictions << prediction
          end
        end    

        if (!weight_label.nil? and (!weight_label.is_a?(String) or 
                                    predictions.any?{|prediction| !prediction.include?("confidence") or 
                                                                  !prediction.include?(weight_label)  }  ))

           raise ArgumentError, "Not enough data to use the selected prediction method. Lacks %s information." % [weight_label]
        end

        final_confidence = 0.0
        total_weight = 0.0
        weight = 1
    
        predictions.each do |prediction|
           if !weight_label.nil?
              weight = prediction[weight_label]
           end
           final_confidence += weight * prediction['confidence']
           total_weight += weight
        end

        final_confidence = total_weight > 0 ? final_confidence / total_weight : Float::INFINITY 
        return [combined_prediction, final_confidence]
        
     end

     def append(prediction_info)
        # Adds a new prediction into a list of predictions

        #   prediction_info should contain at least:
        #   - prediction: whose value is the predicted category or value

        #   for instance:
        #       {'prediction': 'Iris-virginica'}

        #   it may also contain the keys:
        #   - confidence: whose value is the confidence/error of the prediction
        #   - distribution: a list of [category/value, instances] pairs
        #                   describing the distribution at the prediction node
        #   - count: the total number of instances of the training set in the
        #            node
        #
        if prediction_info.is_a?(Hash) and prediction_info.include?('prediction')
           order = next_order()
           prediction_info['order'] = order
           @predictions << prediction_info
        else
          puts "Failed to add the prediction.\n The minimal key for the prediction is 'prediction' :\n{'prediction': 'Iris-virginica'"
        end 

     end

     def single_out_category(options)
        # Singles out the votes for a chosen category and returns a prediction
        #   for this category iff the number of votes reaches at least the given
        #   threshold.
        #
        if options.nil? or ["threshold", "category"].any? {|option| !options.include?(option)}
            raise Exception, "No category and threshold information was  found. 
                              Add threshold and category info.
                              E.g. {\"threshold\": 6, \"category\":
                              \"Iris-virginica\"}." 
        end 
 
        length = @predictions.size

        if options["threshold"] > length
            raise Exception, "You cannot set a threshold value larger than "
                             "%s. The ensemble has not enough models to use"
                             " this threshold value." % [length]
        end

        if options["threshold"] < 1
            raise Exception, "The threshold must be a positive value"
        end

        category_predictions = []
        rest_of_predictions = []

        @predictions.each do |prediction|
          if prediction['prediction'] == options["category"]
             category_predictions << prediction
          else
             rest_of_predictions << prediction
          end
        end

        if category_predictions.size >= options["threshold"]
            return MultiVote.new(category_predictions)
        end
        return MultiVote(rest_of_predictions)
     end
   
     def append_row(prediction_row,
                    prediction_headers=PREDICTION_HEADERS)
        # Adds a new prediction into a list of predictions

        #   prediction_headers should contain the labels for the prediction_row
        #   values in the same order.

        #   prediction_headers should contain at least the following string
        #   - 'prediction': whose associated value in prediction_row
        #                   is the predicted category or value

        #   for instance:
        #       prediction_row = ['Iris-virginica']
        #       prediction_headers = ['prediction']

        #   it may also contain the following headers and values:
        #   - 'confidence': whose associated value in prediction_row
        #                   is the confidence/error of the prediction
        #   - 'distribution': a list of [category/value, instances] pairs
        #                     describing the distribution at the prediction node
        #   - 'count': the total number of instances of the training set in the
        #              node
        #

        if (prediction_row.is_a?(Array) and
                prediction_headers.is_a?(Array) and
                prediction_row.size == prediction_headers.size and
                prediction_headers.include?('prediction'))
            order = next_order()
            begin
                index = prediction_headers.index('order')
                prediction_row[index] = order
            rescue Exception
                prediction_headers << 'order'
                prediction_row << order
            end

            prediction_info = {}
            (0..prediction_row.size-1).each do |i|
               prediction_info[prediction_headers[i]] = prediction_row[i]
            end

            @predictions << prediction_info
         else
            puts "WARNING: failed to add the prediction. The row must have label 'prediction' at least."
         end
     end

     def extend(predictions_info)
        # Given a list of predictions, extends the list with another list of
        #  predictions and adds the order information. For instance,
        #  predictions_info could be:

        #      [{'prediction': 'Iris-virginica', 'confidence': 0.3},
        #      {'prediction': 'Iris-versicolor', 'confidence': 0.8}]
        #  where the expected prediction keys are: prediction (compulsory),
        #  confidence, distribution and count.
        # 

        if predictions_info.is_a?(Array)
            order = next_order()
            (0..predictions_info.size-1).each do |i|
               prediction = predictions_info[i]
               if prediction.is_a?(Hash)
                  prediction['order'] = order + i
                  append(prediction)
               else
                 puts "WARNING: failed to add the prediction. Only dict like predictions are expected"
               end
            end
        else
            puts "WARNING: failed to add the predictions Only a list of dict-like predictions are expected."
        end
     end

     def extend_rows(predictions_rows,
                    prediction_headers=PREDICTION_HEADERS)
        #  Given a list of predictions, extends the list with a list of
        #  predictions and adds the order information. For instance,
        #  predictions_info could be:

        #      [['Iris-virginica', 0.3],
        #      ['Iris-versicolor', 0.8]]
        #  and their respective labels are extracted from predition_headers,
        #  that for this example would be:
        #      ['prediction', 'confidence']

        #  The expected prediction elements are: prediction (compulsory),
        #  confidence, distribution and count.
        #
        order = next_order()
        begin 
            index = prediction_headers.index('order')
        rescue Exception
            index = prediction_headers.size
            prediction_headers.append('order')
        end

        if predictions_rows.is_a?(Array)
            range(0..predictions_rows.size-1).each do |i|
                prediction = predictions_rows[i]
                if prediction.is_a?(Array)
                   if index == len(prediction)
                      prediction << order+1
                   else
                      prediction[index] = order + i
                   end
                   append_row(prediction, prediction_headers)
                else
                   puts "WARNING: failed to add the prediction. Only row-like predictions are expected."
                end
            end
        else
            puts "WARNING: failed to add the predictions. Only a list of row-like predictions are expected."
        end
     end

  end

end  
