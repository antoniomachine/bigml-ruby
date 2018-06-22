# encoding: utf-8

require_relative 'util'

module BigML
  class MultiVoteList
    # A multiple vote prediction in compact format
    # Uses a number of predictions to generate a combined prediction.
    # The input should be an ordered list of probability, counts or confidences
    # for each of the classes in the objective field.
    # 
    attr_accessor :predictions
    def initialize(predictions)
      # Init method, builds a MultiVoteList with a list of predictions
      # The constuctor expects a list of well formed predictions like:
      # [0.2, 0.34, 0.48] which might correspond to confidences of
      # three different classes in the objective field.
      #
      if predictions.is_a?(Array)
        @predictions = predictions
      else
        raise ArgumentError.new("Expected a list of values to create a
                             MultiVoteList. Found %s instead" % predictions)
      end
    end  
    
    def extend(predictions_list)
      #
      # Extending the extend method in lists
      #
      if predictions_list.is_a?(MultiVoteList)
        predictions_list = predictions_list.predictions
      end 
      
      @predictions+=predictions_list
    end
    
    def append(prediction)
      #
      #Extending the append method in lists
      #
      @predictions << prediction
    end  
    
    def combine_to_distribution(normalize=true)
      # Receives a list of lists. Each element is the list of probabilities
      # or confidences
      # associated to each class in the ensemble, as described in the
      # `class_names` attribute and ordered in the same sequence. Returns the
      # probability obtained by adding these predictions into a single one
      # by adding their probabilities and normalizing.
      # 
      
      total = 0.0
      output = [0.0] * @predictions[0].size
 
      @predictions.each do |distribution|
        distribution.each_with_index do |vote_value, i|
          output[i] += vote_value
          total += vote_value
        end 
      end

      if !normalize
        total = @predictions.size
      end  
        
      output.each_with_index do |value,i|
        output[i] = (value / total).round(BigML::Util::PRECISION)
      end

      return output
    end
  end 
end