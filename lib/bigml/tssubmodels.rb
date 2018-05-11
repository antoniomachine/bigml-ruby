# encoding: utf-8


# Auxiliary module to store the functions to compute time-series forecasts
# following the formulae in
# https://www.otexts.org/sites/default/files/fpp/images/Table7-8.png
# as explained in
# https://www.otexts.org/fpp/7/6
#

OPERATORS = {"A": lambda = -> (x,s) { x + s }, 
             "M":  lambda = -> (x,s) { x * s }, 
             "N": lambda = -> (x,s) { x }}

def season_contribution(s_list, step)
  #
  # Chooses the seasonal contribution from the list in the period
  #   s_list: The list of contributions per season
  #   step: The actual prediction step
  #    
  if s_list.is_a?(Array)
    period = s_list.size
    index = (- period + 1 + step % period).abs
    return s_list[index]
  else
    return 0
  end
end

def trivial_forecast(submodel, horizon)
  #
  # Computing the forecast for the trivial models
  #
  points = []
  submodel_points = submodel["value"]
  period = submodel_points.size
  if period > 1
      # when a period is used, the points in the model are repeated
    (0..(horizon-1)).each do |h|
      points << submodel_points[h % period]
    end  
      
  else
    (0..(horizon-1)).each do |h|
      points << submodel_points[0]
    end  
  end
  
  return points
end

def naive_forecast(submodel, horizon)
  #
  # Computing the forecast for the naive model
  #
  return trivial_forecast(submodel, horizon)

end

def mean_forecast(submodel, horizon)
  # Computing the forecast for the mean model
  
  return trivial_forecast(submodel, horizon)
end

def drift_forecast(submodel, horizon)
  # Computing the forecast for the drift model

   points = []
   (0..(horizon-1)).each do |h|
     points << submodel["value"] + submodel["slope"] * (h + 1)
   end   

   return points
end

def N_forecast(submodel, horizon, seasonality)
  # Computing the forecast for the trend=N models
  points = []
  
  final_state = submodel.fetch("final_state", {})
  l = final_state.fetch("l", 0)
  s = final_state.fetch("s", 0)
  (0..(horizon-1)).each do |h|
    # each season has a different contribution
    s_i = season_contribution(s, h)
    
    points << OPERATORS[seasonality.to_sym].call(l, s_i)
  end  

  return points
end

def A_forecast(submodel, horizon, seasonality)
  points = []
  final_state = submodel.fetch("final_state", {})
  l = final_state.fetch("l", 0)
  b = final_state.fetch("b", 0)
  s = final_state.fetch("s", 0)
  (0..(horizon-1)).each do |h|
    # each season has a different contribution
    s_i = season_contribution(s, h)
    points << OPERATORS[seasonality.to_sym].call(l + b * (h + 1), s_i)
  end
  
 return points
end

def Ad_forecast(submodel, horizon, seasonality)
  points = []
  final_state = submodel.fetch("final_state", {})
  l = final_state.fetch("l", 0)
  b = final_state.fetch("b", 0)
  phi = submodel.fetch("phi", 0)
  s = final_state.fetch("s", 0)
  phi_h = phi
  (0..(horizon-1)).each do |h|
    # each season has a different contribution
    s_i = season_contribution(s, h)
    points << OPERATORS[seasonality.to_sym].call(l + phi_h * b, s_i)
    phi_h = phi_h + (phi ** (h + 2))
  end  

  return points
end 

def M_forecast(submodel, horizon, seasonality)
  points = []
  final_state = submodel.fetch("final_state", {})
  l = final_state.fetch("l", 0)
  b = final_state.fetch("b", 0)
  s = final_state.fetch("s", 0)
  (0..(horizon-1)).each do |h|
    s_i = season_contribution(s, h)
    points <<  OPERATORS[seasonality.to_sym].call(l * (b ** (h + 1)), s_i)
  end  

  return points
end

def Md_forecast(submodel, horizon, seasonality)
  points = []
  final_state = submodel.fetch("final_state", {})
  l = final_state.fetch("l", 0)
  b = final_state.fetch("b", 0)
  s = final_state.fetch("s", 0)
  phi = submodel.fetch("phi", 0)
  phi_h = phi
  (0..(horizon-1)).each do |h|
   # each season has a different contribution
   s_i = season_contribution(s, h)
   points << OPERATORS[seasonality.to_sym].call(l * (b ** phi_h), s_i)
   phi_h = phi_h + (phi ** (h+2))
  end   
  
  return points
end

SUBMODELS = {"trivial" => "trivial_forecast",
             "naive" => "naive_forecast",
             "mean" => "mean_forecast",
             "drift" => "drift_forecast",
             "N" => "N_forecast",
             "A" => "A_forecast",
             "Ad" => "Ad_forecast",
             "M" => "M_forecast",
             "Md" => "Md_forecast"}
      