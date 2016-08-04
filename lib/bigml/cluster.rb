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


# A local Predictive Cluster.

# This module defines a Cluster to make predictions (centroids) locally or
# embedded into your application without needing to send requests to
# BigML.io.

# This module cannot only save you a few credits, but also enormously
# reduce the latency for each prediction and let you use your clusters
# offline.

# Example usage (assuming that you have previously set up the BIGML_USERNAME
# and BIGML_API_KEY environment variables and that you own the cluster/id
# below):

# require 'bigml'
# api = api = BigML::Api.new 

# cluster = Cluster.new('cluster/5026965515526876630001b2')
# cluster.centroid({"petal length" => 3, "petal width" => 1,
#                  "sepal length" => 1, "sepal width" => 0.5})
#
#

require_relative 'basemodel'
require_relative 'resourcehandler'
require_relative 'predicate'
require_relative 'centroid'
require_relative 'model'

module BigML
   OPTIONAL_FIELDS = ['categorical', 'text', 'items', 'datetime']
   CSV_STATISTICS =  ['minimum', 'mean', 'median', 'maximum', 'standard_deviation',
                      'sum', 'sum_squares', 'variance']
   GLOBAL_CLUSTER_LABEL = 'Global'

   def self.parse_terms(text, case_sensitive=true)
      #
      # Returns the list of parsed terms
      #
      if text.nil?
          return []
      end
      expression = '(\b|_)([^\b_\s]+?)(\b|_)'
      pattern = /#{expression}/

      result = text.scan(pattern).collect {|i| i.join('') }.join(' ')
      if !case_sensitive
         result.downcase!
      end
      return result.split(' ')

   end

   def self.parse_items(text, regexp)
     #
     # Returns the list of parsed items
     #
     if text.nil?
        return []
     end

     return text.split(/#{regexp}/)
   end

   def self.get_unique_terms_data(terms, term_forms, tag_cloud)
     #
     # Extracts the unique terms that occur in one of the alternative forms in term_forms or in the tag cloud.
     #
     #
     extend_forms = {}
     if tag_cloud.is_a?(Array)
        tag_cloud = Hash[*tag_cloud.flatten]
     end

     tag_cloud = tag_cloud.keys
     term_forms.each do |term, forms|
        forms.each do |form|
          extend_forms[form] = term
        end
        extend_forms[term] = term
     end  

     terms_set=[]
     terms.each do |term|
       if tag_cloud.include?(term)
          terms_set << term
       elsif extend_forms.include?(term)
          terms_set << extend_forms[term] 
       end
     end

     return terms_set.uniq

   end

   class Cluster < ModelFields
      # A lightweight wrapper around a cluster model.
      # Uses a BigML remote cluster model to build a local version that can be used
      # to generate centroid predictions locally. 
   
      def initialize(cluster, api=nil)
        @resource_id = nil 
        @centroids = nil
        @cluster_global = nil
        @total_ss = nil
        @within_ss = nil
        @between_ss = nil
        @ratio_ss = nil
        @critical_value = nil
        @k = nil
        @scales = {}
        @term_forms = {}
        @tag_clouds = {}
        @term_analysis = {}
        @item_analysis = {}
        @items = {}
        
        if !(cluster.is_a?(Hash) and cluster.include?("resource") and
           !cluster["resource"].nil?)
            if api.nil?
               api = BigML::Api.new(nil, nil, false, false, false, STORAGE)
            end

            @resource_id = BigML::get_cluster_id(cluster)

            if @resource_id.nil?
                raise Exception api.error_message(cluster, 'cluster', 'get')
            end
            query_string = BigML::ONLY_MODEL
            cluster = BigML::retrieve_resource(api, @resource_id, query_string)
        else
            @resource_id = BigML::get_cluster_id(cluster)
        end

        if cluster.include?('object') and cluster['object'].is_a?(Hash)
            cluster = cluster['object']
        end

        if cluster.include?('clusters') and cluster['clusters'].is_a?(Hash)
            status = BigML::get_status(cluster)
            if status.include?('code') and status['code'] == FINISHED
               the_clusters = cluster['clusters']
               cluster_global = the_clusters.fetch('global')
               clusters = the_clusters['clusters']
               @centroids =  clusters.collect {|centroid| BigML::Centroid.new(centroid) } 
               @cluster_global = cluster_global
               if !cluster_global.nil?
                    @cluster_global = Centroid.new(cluster_global)
                    # "global" has no "name" and "count" then we set them
                    @cluster_global.name = GLOBAL_CLUSTER_LABEL
                    @cluster_global.count = @cluster_global.distance['population']               
               end
  
               @otal_ss = the_clusters.fetch('total_ss')
               @within_ss = the_clusters.fetch('within_ss')
               if @within_ss.nil?
                  @within_ss = @centroids.collect {|centroid| centroid.distance['sum_squares'] }.sum
               end
               @between_ss = the_clusters.fetch('between_ss')
               @ratio_ss = the_clusters.fetch('ratio_ss')
               @critical_value = cluster.fetch('critical_value', nil)
               @k = cluster.fetch('k')
               @scales = cluster['scales'].clone
               @term_forms = {}
               @tag_clouds = {}
               @term_analysis = {}
               fields = cluster['clusters']['fields']
               summary_fields = cluster['summary_fields']

               summary_fields.each do |field_id|
                  fields.delete(field_id)
               end
         
               fields.each do |field_id, field|
                   if field['optype'] == 'text'
                     @term_forms.merge!({field_id => field["summary"].fetch("term_forms", nil)})
                     @tag_clouds.merge!({field_id =>  field["summary"].fetch("tag_cloud", nil)})
                     @term_analysis.merge!({field_id => field.fetch("term_analysis", nil)})
                   elsif field['optype'] == 'items'
                     @items.merge!({field_id => field["summary"]["items"]})
                     @item_analysis.merge!({field_id => field['item_analysis']})
                   end
               end

               super(fields)

               if !(@scales.collect {|field_id, value| @fields.key?(field_id) }.all?)
                    raise "Some fields are missing
                          to generate a local cluster.
                          Please, provide a cluster with
                          the complete list of fields."
               end
 
            else
                raise Exception "The cluster isn't finished yet"
            end
        else
            raise "Cannot create the Cluster instance. Could not
                   find the 'clusters' key in the resource:\n\n%s" %
                    cluster
        end

      end

   
      def centroid(input_data, by_name=true)
        # Returns the id of the nearest centroid
        #
        #
        # Checks and cleans input_data leaving the fields used in the model

        input_data = filter_input_data(input_data, by_name)

        # Checks that all numeric fields are present in input data
        @fields.each do|field_id, field| 
           if !OPTIONAL_FIELDS.include?(field['optype']) and !input_data.include?(field_id)
              raise Exception "Failed to predict a centroid. 
                               Input  data must contain values 
                               for all numeric fields to find a centroid." 
           end      
        end
        # Strips affixes for numeric values and casts to the final field type
        BigML::Util::cast(input_data, @fields)

        unique_terms = get_unique_terms(input_data)

        nearest = {'centroid_id' => nil, 'centroid_name' => nil,
                   'distance' => Float::INFINITY}

        @centroids.each do |centroid|
           distance2 = centroid.distance2(input_data, unique_terms,@scales, nearest['distance'])
           if !distance2.nil?
              nearest = {'centroid_id' => centroid.centroid_id,
                         'centroid_name' => centroid.name,
                         'distance' => distance2}
           end
        end

        nearest['distance'] = Math.sqrt(nearest['distance'])
        return nearest
      end
 
      def is_g_means()
        #Checks whether the cluster has been created using g-means
        return !@critical_value.nil?
      end

      def get_unique_terms(input_data)
        #
        # Parses the input data to find the list of unique terms in the
        #  tag cloud
        unique_terms = {}
        @term_forms.each do |field_id,value|
          if input_data.key?(field_id)
             input_data_field = input_data.fetch(field_id, '')
             if input_data_field.is_a?(String) 
                case_sensitive = @term_analysis[field_id].fetch('case_sensitive', true)
                token_mode = @term_analysis[field_id].fetch('token_mode', 'all')
                if token_mode != BigML::TM_FULL_TERM
                   terms = BigML::parse_terms(input_data_field, case_sensitive)
                else
                   terms = []
                end

                if token_mode != BigML::TM_TOKENS
                    if case_sensitive
                      terms << input_data_field
                    else
                      terms << input_data_field.downcase
                    end
                end
		unique_terms[field_id] = BigML::get_unique_terms_data(terms, value, @tag_clouds.fetch(field_id, {}))
             else
                unique_terms[field_id] = input_data_field
             end
             input_data.delete(field_id)
          end
        end

        # the same for items fields
        @item_analysis.each do |field_id, value|
           if input_data.key?(field_id)
              input_data_field = input_data.fetch(field_id, '')
              if input_data_field.is_a?(String)
                # parsing the items in input_data
                separator = value.fetch('separator',' ')
                regexp = value.fetch('separator_regexp', nil)
                if regexp.nil?
                  regexp = '%s' % Regexp.quote(separator)
                end
                terms = BigML::parse_items(input_data_field, regexp)
                unique_terms[field_id] = BigML::get_unique_terms_data(terms, {}, @items.fetch(field_id, []))
              else
                 unique_terms[field_id] = input_data_field
              end
              input_data.delete(field_id)
           end
        end
         
        return unique_terms

      end

      def print_global_distribution(out=$STDOUT)
        #
        # Prints the line Global: 100% (<total> instances)
        #
        output = ""
        if !@cluster_global.nil?
            output += "    %s: 100%% (%d instances)\n" % [ 
                @cluster_global.name,
                @cluster_global.count]
        end
        out.puts(output)
        out.flush()
      end

      def print_ss_metrics(out=$STDOUT)
        #
        # Prints the block of *_ss metrics from the cluster
        #
        ss_metrics = [["total_ss (Total sum of squares)", @total_ss],
                      ["within_ss (Total within-cluster sum of the sum of squares)", @within_ss],
                      ["between_ss (Between sum of squares)", @between_ss],
                      ["ratio_ss (Ratio of sum of squares)", @ratio_ss]]
        output = ""

        ss_metrics.each do |metric|
           if !metric[1].nil?
              output += u"%s%s: %5f\n" % [BigML::INDENT, metric[0], metric[1]]
           end

        end
        out.puts output
        out.flush
      end

      def summarize(out=$STDOUT)
         #
	 # Prints a summary of the cluster info
	 #
         report_header = ''
         if @is_g_means
            report_header = 'G-means Cluster (critical_value=%d)' % @critical_value 
         else
            report_header = 'K-means Cluster (k=%d)' % @k
         end
         
         out.puts(report_header + ' with %d centroids\n' % @centroids.size)
         out.puts
         out.puts "Data distribution:"

         # "Global" is set as first entry
         print_global_distribution(out)

         BigML::print_distribution(get_data_distribution(), out)

         out.puts
         centroids_list = !@cluster_global.nil? ? [@cluster_global] : []
         centroids_list.concat(@centroids.sort_by {|x| x.name} )

         out.puts "Cluster metrics:"
         print_ss_metrics(out)
         out.puts

         out.puts "Centroids:"
         centroids_list.each do |centroid|
           out.puts
           out.puts "%s%s: " % [BigML::INDENT, centroid.name]
           connector=""
           centroid.center.each do |field_id, value|
              if value.is_a?(String)
                 value = "\"%s\"" % value
              end
              out.puts "%s%s: %s" % [connector, @fields[field_id]["name"], value]
              connector = ", "
           end

         end
         out.puts
         out.puts

         out.puts "Distance distribution:"
         out.puts
  
         centroids_list.each do |centroid|
           centroid.print_statistics(out)
         end
         out.puts
  
         if @centroids.size > 1
            out.puts "Intercentroid distance:"
            out.puts
            centroids_list = !@cluster_global.nil? ? centroids_list[1...1] :
                                 centroids_list

            centroids_list.each do |centroid|
               out.puts "%sTo centroid: %s" [INDENT, centroid.name]
               centroids_distance(centroid).each do |measure, result|
                  out.puts "%s%s: %s" % [BigML::INDENT * 2, measure, result]
               end
               out.puts
            end 

         end

      end

   end

end

