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

   CSV_STATISTICS =  ['minimum', 'mean', 'median', 'maximum', 'standard_deviation',
                      'sum', 'sum_squares', 'variance']
                            
   GLOBAL_CLUSTER_LABEL = 'Global'
   NUMERIC_DEFAULTS = ["mean", "median", "minimum", "maximum", "zero"]

   def self.get_unique_terms_data_cluster(terms, term_forms, tag_cloud)
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
      
      terms_set = []
      terms.each do|term|
        if tag_cloud.include?(term)
          terms_set << term
        elsif extend_forms.key?(term)
          terms_set <<  extend_forms[term]
        end    
      end  
      
      return terms_set.uniq

   end
   
   def intercentroid_measures(distances)
     results = []
     results << ["Minimum", distances.min] 
     results << ["Mean", distances.sum/distances.size.to_f]
     results << ["Maximum", distances.max]
     return results
   end                           

   class Cluster < ModelFields
      # A lightweight wrapper around a cluster model.
      # Uses a BigML remote cluster model to build a local version that can be used
      # to generate centroid predictions locally.
      
      def initialize(cluster, api=nil)
        @resource_id = nil 
        @centroids = nil
        @cluster_global = nil
        @total_ss = nil
        @within_ss = nil
        @between_ss = nil
        @ratio_ss = nil
        @critical_value = nil
        @default_numeric_value = nil 
        @k = nil
        @summary_fields = []
        @scales = {}
        @term_forms = {}
        @tag_clouds = {}
        @term_analysis = {}
        @item_analysis = {}
        @items = {}
        @datasets = {}
        @api = api
        
        if @api.nil?
          @api = BigML::Api.new(nil, nil, false, false, false, STORAGE)
        end
        
        @resource_id, cluster = BigML::get_resource_dict(cluster, "cluster", @api)
        
        if cluster.include?('object') and cluster['object'].is_a?(Hash)
            cluster = cluster['object']
        end

        if cluster.include?('clusters') and cluster['clusters'].is_a?(Hash)
            status = BigML::Util::get_status(cluster)
            if status.include?('code') and status['code'] == FINISHED
               @default_numeric_value = cluster.fetch("default_numeric_value", nil)
               @summary_fields = cluster.fetch("summary_fields", [])
               @datasets = cluster.fetch("cluster_datasets", {})
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
                    raise Exception, "Some fields are missing
                                      to generate a local cluster.
                                      Please, provide a cluster with
                                      the complete list of fields."
               end
 
            else
                raise Exception, "The cluster isn't finished yet"
            end
        else
            raise Exception, "Cannot create the Cluster instance. Could not
                             find the 'clusters' key in the resource:\n\n%s" %
                              cluster
        end

      end

   
      def centroid(input_data)
        # Returns the id of the nearest centroid
        #
        #
        # Checks and cleans input_data leaving the fields used in the model

        clean_input_data, unique_terms = self._prepare_for_distance(input_data)

        nearest = {'centroid_id' => nil, 'centroid_name' => nil,
                   'distance' => Float::INFINITY}

        @centroids.each do |centroid|
           distance2 = centroid.distance2(clean_input_data, unique_terms,@scales, nearest['distance'])
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

      def fill_numeric_defaults(input_data, average="mean")
         # Checks whether input data is missing a numeric field and
         # fills it with the average quantity provided in the
         # ``average`` parameter 
         @fields.each do |field_id, field|
           if !@summary_fields.include?(field_id) and 
              field['optype'] == BigML::Util::NUMERIC and
              !input_data.key?(field_id)
              unless NUMERIC_DEFAULTS.include?(average)
                  raise Exception, "The available defaults are %s" % NUMERIC_DEFAULTS.join(", ") 
              end

              default_value = average == "zero" ? 0 : field['summary'].fetch(average)
              input_data[field_id] = default_value
           end
         end
 
         return input_data
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
                unique_terms[field_id] = BigML::get_unique_terms_data_cluster(terms, value, @tag_clouds.fetch(field_id, []))
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
                unique_terms[field_id] = BigML::get_unique_terms_data_cluster(terms, {}, @items.fetch(field_id, []))
              else
                 unique_terms[field_id] = input_data_field
              end
              input_data.delete(field_id)
           end
        end
         
        return unique_terms

      end
      
      def centroids_distance(to_centroid)
        #
        # Statistic distance information from the given centroid
        # to the rest of centroids in the cluster
        #
        unique_terms = self.get_unique_terms(to_centroid.center)
        distances = []
        
        self.centroids.each do |centroid|
          if centroid.centroid_id != to_centroid.centroid_id
            distances << Math.sqrt(centroid.distance2(to_centroid.center,
                                                      unique_terms,
                                                      @scales))
          end  
        end  

        return intercentroid_measures(distances)
              
      end
      
      def cluster_global_distance
        #
        # Used to populate the intercentroid distances columns in the CSV
        # report. For now we don't want to compute real distance and jsut
        # display "N/A"
        #
        
        return [['Minimum', 'N/A'], 
                ['Mean', 'N/A'],
                ['Maximum', 'N/A']]
      end
      
      def _prepare_for_distance(input_data)
        # Prepares the fields to be able to compute the distance2
        
        # Checks and cleans input_data leaving the fields used in the model
         clean_input_data = filter_input_data(input_data)
         # Checks that all numeric fields are present in input data and
         # fills them with the default average (if given) when otherwise
         begin
           fill_numeric_defaults(clean_input_data, @default_numeric_value)
         rescue
           raise Exception, "Missing values in input data. 
                             Input data must contain values for all
                             numeric fields to compute a distance."
         end
         
         # Strips affixes for numeric values and casts to the final field type
         BigML::Util::cast(clean_input_data, @fields)
         
         unique_terms = self.get_unique_terms(clean_input_data)
         
         return [clean_input_data, unique_terms]         
      end
      
      def distances2_to_point(reference_point,
                              list_of_points)
        # Computes the cluster square of the distance to an arbitrary
        # reference point for a list of points.
        # reference_point: (dict) The field values for the point used as
        #                        reference
        # list_of_points: (dict|Centroid) The field values or a Centroid object
        #                                which contains these values
        # Checks and cleans input_data leaving the fields used in the model
        
        reference_point = self._prepare_for_distance(reference_point)[0]
        # mimic centroid structure to use it in distance computation
        point_info = {"center" => reference_point}
        reference = BigML::Centroid.new(point_info)
        distances = []
        
        list_of_points.each do |point|
          centroid_id=nil
          if point.is_a?(BigML::Centroid)
            centroid_id = point.centroid_id
            point = point.center
          end

          clean_point, unique_terms = self._prepare_for_distance(point)
          
          if clean_point != reference_point
            
            result = {"data" => point, 
                      "distance" => reference.distance2(clean_point, 
                                                        unique_terms, 
                                                        @scales)}

             if !centroid_id.nil?
               result.merge!({"centroid_id" => centroid_id})
             end 
             distances << result 
          end 
             
        end  
        
        return distances
      end
      
      def points_in_cluster(centroid_id)
        # Returns the list of data points that fall in one cluster.
        cluster_datasets = @datasets
        centroid_dataset = cluster_datasets.fetch(centroid_id, nil)
        
        if centroid_dataset.nil? or centroid_dataset.empty?
          centroid_dataset = @api.create_dataset(@resource_id, {"centroid" => centroid_id})
          @api.ok(centroid_dataset)
        else
          centroid_dataset = @api.check_resource("dataset/%s" % centroid_dataset)
        end
        
         # download dataset to compute local predictions
         downloaded_data = @api.download_dataset(centroid_dataset["resource"])
         
         cont=downloaded_data.split("\n")
         keys = cont[0].split(",")
         
         result = []
         cont[1..-1].each do |a|
           k = {}
           a.split(",").each_with_index do |v,i|
             k[keys[i]]=v
           end   
           result << k
         end  
         return result  
      end  
      
      def closests_in_cluster(reference_point,
                             number_of_points=nil,
                             centroid_id=nil)
        # Computes the list of data points closer to a reference point.
        # If no centroid_id information is provided, the points are chosen
        # from the same cluster as the reference point.
        # The points are returned in a list, sorted according
        # to their distance to the reference point. The number_of_points
        # parameter can be set to truncate the list to a maximum number of
        # results. The response is a dictionary that contains the
        #centroid id of the cluster plus the list of points
        #

        if !centroid_id.nil? and 
           !@centroids.collect {|centroid| centroid.centroid_id}.include?(centroid_id)
            raise ArgumentError.new("Failed to find the provided centroid_id: %s" % centroid_id)
        end
        
        if centroid_id.nil?
          # finding the reference point cluster's centroid
          centroid_info = self.centroid(reference_point)
          centroid_id = centroid_info["centroid_id"]
        end
        
        # reading the points that fall in the same cluster
        points = self.points_in_cluster(centroid_id)

        # computing distance to reference point
        points = self.distances2_to_point(reference_point, points)
        
        points = points.sort_by {|x| x["distance"]}

        if !number_of_points.nil?
          points = points[0..(number_of_points-1)]
        end

        points.each do |point|
          point["distance"] = Math.sqrt(point["distance"])
        end
            
        return {"centroid_id" => centroid_id, "reference" => reference_point,
                "closest" => points}    
      end
      
      def sorted_centroids(reference_point)
        # Gives the list of centroids sorted according to its distance to
        # an arbitrary reference point.
        #
        close_centroids = self.distances2_to_point(reference_point, self.centroids)
        
        close_centroids.each do|centroid|
          centroid["distance"] = Math.sqrt(centroid["distance"])
          centroid["center"] = centroid["data"]
          centroid.delete("data")
          
        end
            
        return {"reference" => reference_point,
                "centroids" => close_centroids.sort_by {|x| x["distance"]}}
      end
      
      def centroid_features(centroid, field_ids, encode=true)
        # Returns features defining the centroid according to the list
        # of common field ids that define the centroids.
        #
        features = []
        
        field_ids.each do |field_id|
          value = centroid.center[field_id]
          if value.is_a?(String) and encode
            value = value.encode('utf-8')
          end  
          features << value
        end  
            
        return features
      end
      
      def get_data_distribution()
        # Returns training data distribution
        #
        distribution = self.centroids.collect {|centroid| [centroid.name, centroid.count]}
    
        return distribution.sort_by {|x| x[0]}
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

