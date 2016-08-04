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
 
   STATISTIC_MEASURES = ['Minimum', 'Mean', 'Median', 'Maximum', 'Standard deviation', 
                         'Sum', 'Sum squares', 'Variance']


   def self.cosine_distance2(terms, centroid_terms, scale)
      # Returns the distance defined by cosine similariti

      # Centroid values for the field can be an empty list.
      # Then the distance for an empty input is 1
      # (before applying the scale factor).
      if (terms.nil? or terms.empty?) and (centroid_terms.nil? or centroid_terms.empty?)
        return 0
      end
      
      if (terms.nil? or terms.empty?) or (centroid_terms.nil? or centroid_terms.empty?)
        return scale ** 2
      end

      input_count = 0
      centroid_terms.each do |term|
         if terms.include?(term)
            input_count += 1 
         end
      end

      cosine_similarity = (input_count / (Math.sqrt(terms.size * centroid_terms.size)))

      similarity_distance = scale * (1 - cosine_similarity)

      return similarity_distance ** 2

   end
 
   class Centroid
      attr_accessor :name, :count, :center, :centroid_id, :distance
      # A Centroid
      def initialize(centroid_info)
         @center = centroid_info.fetch('center', {})
         @count = centroid_info.fetch('count', 0)
         @centroid_id = centroid_info.fetch('id', nil)
         @name = centroid_info.fetch('name', nil)
         @distance = centroid_info.fetch('distance', {})
      end

      def distance2(input_data, term_sets, scales, stop_distance2=nil)
        #
        # Squared Distance from the given input data to the centroid
        #
        distance2 = 0.0
        @center.each do |field_id, value|
            if value.is_a?(Array)
              # text field
              terms = !term_sets.key?(field_id) ? [] : term_sets[field_id]
              distance2 += BigML::cosine_distance2(terms, value, scales[field_id]) 
            elsif value.is_a?(String) 
              if !input_data.key?(field_id) or input_data[field_id] != value
                 distance2 += 1 * scales[field_id] ** 2
              end
            else
              distance2 += ((input_data[field_id] - value) *scales[field_id]) ** 2
            end
            if !stop_distance2.nil? and distance2 >= stop_distance2
               return nil
            end
        end
        return distance2
 
      end

      def print_statistics(out=$STDOUT)
        #
        # Print the statistics for the training data clustered around the
        #   centroid
        #
        indent = " " * 4
        out.puts "%s%s:" % [indent, @name]
        literal = "%s%s: %s"
        STATISTIC_MEASURES.each do|measure_title|
           measure = measure_title.downcase.gsub(" ", "_")
           out.puts "%s%s: %s" % [indent* 2, measure_title, @distance[measure]]
        end
        out.puts
      end
 
   end

   

end

