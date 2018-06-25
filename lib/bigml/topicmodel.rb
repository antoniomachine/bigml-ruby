# -*- coding: utf-8 -*-
#!/usr/bin/env python
#
# Copyright 2016 BigML
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

# A local Predictive Topic Model.
# This module allows you to download and use Topic models for local
# predicitons.  Specifically, the function topic_model.distribution allows you
# to pass in input text and infers a generative distribution over the
# topics in the learned topic model.
# Example usage (assuming that you have previously set up the BIGML_USERNAME
# and BIGML_API_KEY environment variables and that you own the topicmodel/id
# below):
# api = BigML::Api.new()
# topic_model = TopicModel('topicmodel/5026965515526876630001b2')
# topic_distribution = topic_model.distribution({"text" => "A sample string"}))

require_relative 'modelfields' 
require_relative 'api' 
require 'rubygems'
require 'lingua/stemmer'
# Note: Random numbers in ruby is diffente implementation from mersenne twister. 
# we used python to generate random numbers with pycall
require 'pycall/import'
include PyCall::Import

# gem install ruby-stemmer
module BigML

  MAXIMUM_TERM_LENGTH = 30
  MIN_UPDATES = 16
  MAX_UPDATES = 512
  SAMPLES_PER_TOPIC = 128

  CODE_TO_NAME = {
    "da" => 'danish',
    "nl" => 'dutch',
    "en" => 'english',
    "fi" => 'finnish',
    "fr" => 'french',
    "de" => 'german',
    "hu" => 'hungarian',
    "it" => 'italian',
    "nn" => 'norwegian',
    "pt" => 'portuguese',
    "ro" => 'romanian',
    "ru" => 'russian',
    "es" => 'spanish',
    "sv" => 'swedish',
    "tr" => 'turkish'
  }

  class TopicModel < ModelFields
 
    # A lightweight wrapper around a Topic Model.
    # Uses a BigML remote Topic Model to build a local version that can be used
    # to generate topic distributions for input documents locally.
    def initialize(topic_model, api=nil)
       @resource_id = nil 
       @stemmer = nil 
       @seed = nil
       @case_sensitive = false
       @bigrams = false
       @ntopics = nil
       @temp = nil 
       @phi = nil 
       @term_to_index = nil
       @topics = []

       @resource_id, topic_model = BigML::get_resource_dict(topic_model, "topicmodel", api)

       if topic_model.key?('object') and topic_model['object'].is_a?(Hash)
          topic_model = topic_model['object']
       end

       if topic_model.key?("topic_model") and topic_model['topic_model'].is_a?(Hash)
         status = BigML::Util::get_status(topic_model) 
         if status.key?('code') and status['code'] == FINISHED
           model = topic_model['topic_model']
           @topics = model['topics']
           
           if model.key?('language') and !model['language'].nil?
             lang=model["language"]
             if CODE_TO_NAME.key?(lang)
               @stemmer = Lingua::Stemmer.new(:language => lang)
             end 
           end
           @term_to_index = {}
           
           model['termset'].each_with_index do|term, index|
             term_key = self.stem(term)
             @term_to_index[term_key] = index
           end
           
           @seed = model['hashed_seed'].abs
           @case_sensitive = model['case_sensitive']
           @bigrams = model['bigrams']
           
           @ntopics = model['term_topic_assignments'][0].size
           
           @alpha = model['alpha']
           
           @ktimesalpha = @ntopics * @alpha

           @temp = [0] * @ntopics
           
           assignments = model['term_topic_assignments']
           beta = model['beta']
           nterms = @term_to_index.size
          
           sums = (0..(@ntopics-1)).map {|index|  assignments.map{|n| n[index] }.sum }
           
           @phi = []
           (0..(@ntopics-1)).each do |i|
             b=[]
             (0..(nterms-1)).each do |j|
               b << 0
             end
             @phi << b
           end
           
           (0..(@ntopics-1)).each do |k|
             norm = sums[k] + nterms * beta
             (0..(nterms-1)).each do |w|
               @phi[k][w] = (assignments[w][k] + beta) / norm 
             end 
           end

           super(model['fields'])
           
         else 
           raise Exception.new("The topic model isn't finished yet")
         end
       else
          raise Exception.new("Cannot create the topic model instance. 
                          Could not find the 'topic_model' 
                          key in the resource:\n\n%s" % topic_model)
       end
    end 
     
    def distribution(input_data)
       # Returns the distribution of topics given the input text.
       #
       # Checks and cleans input_data leaving the fields used in the model
       input_data = self.filter_input_data(input_data)
       return self.distribution_for_text(input_data.values().join("\n\n"))
    end
       
    def distribution_for_text(text)
     
     # Returns the topic distribution of the given `text`, which can
     # either be a string or a list of strings
     #
     
     if text.is_a?(String)
       astr = text
     else
       # List of strings
       astr = text.join("\n\n")
     end    
     
     doc = self.tokenize(astr)
     topics_probability = self.infer(doc)
     result = []
     topics_probability.each_with_index do |probability,index|
       result << {"name" => @topics[index]["name"], "probability" => probability}
     end
     
     return result
    end
       
    def stem(term)
       # Returns the stem of the given term, if the stemmer is defined
       # 
       if @stemmer.nil?
         return term
       else
         return @stemmer.stem(term) 
       end

    end
       
    def append_bigram(out_terms, first, second)
     # Takes two terms and appends the index of their concatenation to the
     # provided list of output terms
     # 
     if @bigrams and !first.nil? and !second.nil?
       bigram = self.stem(first + " " + second)
       if @term_to_index.key?(bigram)
          out_terms <<  @term_to_index[bigram]
       end 
     end 
     
     return out_terms
    end
       
    def tokenize(astr)
      # Tokenizes the input string `astr` into a list of integers, one for
      # each term term present in the `self.term_to_index`
      #dictionary.  Uses word stemming if applicable.
      #
      out_terms = []

      last_term = nil
      term_before = nil

      space_was_sep = false
      saw_char = false
   
      text = astr
      index = 0
      length = text.size
      
      def next_char(text, index, length)
         # Auxiliary function to get next char and index with end check
         #
        index += 1
        
        if index < length
          char = text[index]
        else
          char = ''
        end
        
        return char, index
        
      end

      while index < length
        out_terms = self.append_bigram(out_terms, term_before, last_term)
        char = text[index]
        buf = [] 
        saw_char = false
        
        if (char =~ /\A\p{Alnum}+\z/).nil?
          saw_char = true
        end  

        while (char =~ /\A\p{Alnum}+\z/).nil? and index < length
          char, index = next_char(text, index, length)
        end  
        
        while (index < length and
              (char =~ /\A\p{Alnum}+\z/ or char == "'") and
               buf.size < MAXIMUM_TERM_LENGTH)
            buf << char
            char, index = next_char(text, index, length)
        end 
        
        if buf.size > 0
          term_out = buf.join("")

          if !@case_sensitive
            term_out = term_out.downcase
          end    

          if space_was_sep and !saw_char
              term_before = last_term
          else
              term_before = nil
          end
            
          last_term = term_out

          if char == " " or char == "\n"
              space_was_sep = true
          end
          
          tstem = self.stem(term_out)
          if @term_to_index.key?(tstem)
            out_terms << @term_to_index[tstem]
          end
          
          index += 1
        end
        
      end
      
      out_terms = self.append_bigram(out_terms, term_before, last_term) 
       
      return out_terms
    end
       
    def sample_topics(document, assignments, normalizer, updates, rng)
     # Samples topics for the terms in the given `document` for `updates`
     # iterations, using the given set of topic `assigments` for
     # the current document and a `normalizer` term derived from
     # the dirichlet hyperparameters
     #
     #rng = Random.rand(@seed.to_f)
     counts = [0] * @ntopics

     (0..(updates-1)).each do |i|
       document.each do|term|
         (0..(@ntopics-1)).each do |k|
           topic_term = @phi[k][term]
           topic_document = (assignments[k] + @alpha) / normalizer
           @temp[k] = topic_term * topic_document
         end
         
         (1..(@ntopics-1)).each do |k|
           @temp[k] += @temp[k - 1]
         end
        
         random_value = rng.random() * @temp[-1]
         topic = 0
         
         while @temp[topic] < random_value and topic < @ntopics
           topic += 1
         end   
          
         counts[topic] += 1
       end   
     end

     return counts
     
    end
       
    def sample_uniform(document, updates, rng)
     # Samples topics for the terms in the given `document` assuming
     # uniform topic assignments for `updates` iterations.  Used
     # to initialize the gibbs sampler.
     #rng = 0.844421851525 #
     #rng = Random.rand(@seed.to_f)
     #rng = Random.new(@seed.to_f)
     
     counts = [0] * @ntopics
     (0..(updates-1)).each do |i|
       document.each do|term|
         (0..(@ntopics-1)).each do |k|
           @temp[k] = @phi[k][term]
         end 
         
         (1..(@ntopics-1)).each do |k|
           @temp[k] += @temp[k - 1]
         end
         
         random_value = rng.random() * @temp[-1]
         topic = 0
          
         while @temp[topic] < random_value and topic < @ntopics
           topic += 1
         end
         
         counts[topic] += 1   
       end 
     end
     
     return counts
       
    end
       
    def infer(list_of_indices)
       # Infer a topic distribution for a document, presented as a list of
       #term indices.
       #
       doc = list_of_indices.sort
       updates = 0

       if (doc.size > 0)
           updates = (SAMPLES_PER_TOPIC * @ntopics) / doc.size
           updates = ([MAX_UPDATES, [MIN_UPDATES, updates].max].min).to_i
       end
       
       pyimport :random
       rng = random.Random.new(@seed)
       
       normalizer = (doc.size * updates) + @ktimesalpha
       # Initialization
       uniform_counts = self.sample_uniform(doc, updates, rng)
       
       # Burn-in
       burn_counts = self.sample_topics(doc,
                                        uniform_counts,
                                        normalizer,
                                        updates, rng)
       # Sampling
       sample_counts = self.sample_topics(doc,
                                          burn_counts,
                                          normalizer,
                                          updates, rng)

       return (0..(@ntopics-1)).map{|k| (sample_counts[k] + @alpha) / normalizer }
     end
     
  end 
end
