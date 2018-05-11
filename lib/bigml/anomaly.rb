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

# A local Predictive Anomaly Detector.

# This module defines an Anomaly Detector to score anomlies in a dataset locally
# or embedded into your application without needing to send requests to
# BigML.io.

# This module cannot only save you a few credits, but also enormously
# reduce the latency for each prediction and let you use your models
# offline.

# Example usage (assuming that you have previously set up the BIGML_USERNAME
# and BIGML_API_KEY environment variables and that you own the model/id below):

# api = BigML::Api.new()

# anomaly = Anomaly('anomaly/5126965515526876630001b2')
# anomaly.anomaly_score({"src_bytes" => 350})

require_relative 'modelfields'
require_relative 'resourcehandler'
require_relative 'util'
require_relative 'model'
require_relative 'anomalytree'

module BigML
 
  DEPTH_FACTOR = 0.5772156649

  class Anomaly < ModelFields
      #
      # A lightweight wrapper around an anomaly detector.
      # Uses a BigML remote anomaly detector model to build a local version that
      # can be used to generate anomaly scores locally.
      #
      def initialize(anomaly, api=nil)
        
         @resource_id = nil
         @sample_size = nil 
         @input_fields = nil
         @mean_depth = nil
         @expected_mean_depth = nil
         @iforest = nil 
         @top_anomalies = nil 
         @id_fields = []

         # checks whether the information needed for local predictions is in
	 # the first argument

         if (anomaly.is_a?(Hash) and !BigML::check_model_fields(anomaly))
            anomaly = BigML::get_anomaly_id(anomaly)
            @resource_id = anomaly
         end
	 
         if !(anomaly.is_a?(Hash) and anomaly.include?('resource') and 
              !anomaly['resource'].nil?)
 
            if api.nil?
                api = BigML::Api.new(nil, nil, false, false, false, STORAGE)
            end

            @resource_id = BigML::get_anomaly_id(anomaly)
            if @resource_id.nil?
                raise Exception, api.error_message(anomaly,
                                                  'anomaly',
                                                  'get')
            end

            query_string = BigML::ONLY_MODEL
            anomaly = BigML::retrieve_resource(api, @resource_id,
                                               query_string)
         else
            @resource_id = BigML::get_anomaly_id(anomaly)
         end
         
         if anomaly.include?('object') and anomaly['object'].is_a?(Hash)
            anomaly = anomaly['object']
            @sample_size = anomaly.fetch('sample_size')
            @input_fields = anomaly.fetch('input_fields')
            @id_fields = anomaly.fetch('id_fields', [])
         end

         if anomaly.include?('model') and anomaly['model'].is_a?(Hash)
            super(anomaly['model']['fields'])

            if (anomaly['model'].include?('top_anomalies') and 
                anomaly['model']['top_anomalies'].is_a?(Array))

                @mean_depth = anomaly['model'].fetch('mean_depth')
                status = BigML::Util::get_status(anomaly)
                if status.include?('code') and status['code'] == FINISHED
                   @expected_mean_depth = nil
                   if @mean_depth.nil? or @sample_size.nil?
                       raise Exception, "The anomaly data is not complete. 
                                        Score will
                                        not be available"
                   else
 
                     default_depth = 2 * (DEPTH_FACTOR + Math.log(@sample_size - 1.0) - ((@sample_size -1.0).to_f/@sample_size)) 
                     @expected_mean_depth = [@mean_depth,default_depth].min
                   end
                   iforest = anomaly['model'].fetch('trees', [])

                   if !iforest.nil? and !iforest.empty?
                        @iforest = iforest.collect {|anomaly_tree|  
                                       AnomalyTree.new(anomaly_tree['root'], @fields)}
                   end

                   @top_anomalies = anomaly['model']['top_anomalies']

                else
                    raise Exception, "The anomaly isn't finished yet"
                end
            else
              raise Exception, "Cannot create the Anomaly instance. Could not
                               find the 'top_anomalies' key in the
                               resource:\n\n%s" % anomaly['model'].keys
            end

         end

      end

      def anomaly_score(input_data)
        # Returns the anomaly score given by the iforest

        #   To produce an anomaly score, we evaluate each tree in the iforest
        #   for its depth result (see the depth method in the AnomalyTree
        #   object for details). We find the average of these depths
        #   to produce an `observed_mean_depth`. We calculate an
        #   `expected_mean_depth` using the `sample_size` and `mean_depth`
        #   parameters which come as part of the forest message.
        #   We combine those values as seen below, which should result in a
        #   value between 0 and 1.
      
        # Checks and cleans input_data leaving the fields used in the model
        input_data = filter_input_data(input_data)

        # Strips affixes for numeric values and casts to the final field type
        BigML::Util::cast(input_data, @fields)

        depth_sum = 0
        if @iforest.nil?
            raise Exception, "We could not find the iforest information to 
                            compute the anomaly score. Please, rebuild your 
                            Anomaly object from a complete anomaly detector 
                            resource."
        end
     
        @iforest.each do |tree|
          depth_sum += tree.depth(input_data)[0]
        end

        observed_mean_depth = depth_sum.to_f / @iforest.size
        return 2 ** (- observed_mean_depth / @expected_mean_depth)

      end
 
      def anomalies_filter(_include=true)
        # Returns the LISP expression needed to filter the subset of
        #   top anomalies. When include is set to True, only the top
        #   anomalies are selected by the filter. If set to False, only the
        #   rest of the dataset is selected.
        #

        anomaly_filters = []
        @top_anomalies.each do |anomaly|
           filter_rules = []
           row = anomaly.fetch('row', [])
           row.each_with_index do |value,index|
              field_id = @input_fields[index]
              if @id_fields.include?(field_id)
                 next
              end 
              if value.nil? or value == ""
                 filter_rules << '(missing? "%s")' % field_id
              else
                 if ["categorical", "text"].include?(@fields[field_id]["optype"])
		    begin
                      value = JSON.generate(value)
		    rescue 
		      value = '"'+value.gsub('"','\"').to_s+'"'
		    end
                 end
                 filter_rules << '(= (f "%s") %s)' % [field_id, value]
              end
           end
     
           if !filter_rules.empty?
	      anomaly_filters << "(and %s)" % filter_rules.join(" ")
	   end


        end

        anomalies_filter = anomaly_filters.join(" ")

        if _include
            if anomaly_filters.size == 1
                return anomalies_filter
            end
            return "(or %s)" % anomalies_filter
        else
            return "(not (or %s))" % anomalies_filter
        end

      end
 

  end

end

