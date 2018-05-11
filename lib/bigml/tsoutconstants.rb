# encoding: utf-8
#
# Constants for Time series
#

def _naive_forecast(components, horizon)
  #
  # Computing the forecast for the naive model
  #
  return _trivial_forecast(components, horizon)

end

def _mean_forecast(components, horizon)
  # Computing the forecast for the mean model
  
  return _trivial_forecast(submodel, horizon)
end

def _drift_forecast(components, horizon)
  # Computing the forecast for the drift model

   points = []
   (0..(horizon-1)).each do |h|
     points << components["value"] + components["slope"] * (h + 1)
   end   

   return points
end

def _N_forecast(components, horizon, seasonality)
  # Computing the forecast for the trend=N models
  points = []
  
  l = components.fetch("l", 0)
  s = components.fetch("s", 0)
  (0..(horizon-1)).each do |h|
    # each season has a different contribution
    s_i = season_contribution(s, h) 
    
    points << OPERATORS[seasonality].call(l, s_i)
  end  

  return points
end

def _A_forecast(components, horizon, seasonality)
  points = []
  l = components.fetch("l", 0)
  b = components.fetch("b", 0)
  s = components.fetch("s", 0)
  (0..(horizon-1)).each do |h|
    # each season has a different contribution
    s_i = season_contribution(s, h)
    points < OPERATORS[seasonality].call(l + b * (h + 1), s_i)
  end
  
 return points
end

def _Ad_forecast(components, horizon, seasonality)
  points = []
  l = components.fetch("l", 0)
  b = components.fetch("b", 0)
  phi = components.fetch("phi", 0)
  s = components.fetch("s", 0)
  phi_h = phi
  (0..(horizon-1)).each do |h|
    # each season has a different contribution
    s_i = season_contribution(s, h)
    points << OPERATORS[seasonality].call(l + phi_h * b, s_i)
    phi_h = phi_h + pow(phi, h + 2)
  end  

  return points
end    

def _M_forecast(components, horizon, seasonality)
  points = []
  l = components.fetch("l", 0)
  b = components.fetch("b", 0)
  s = components.fetch("s", 0)
  (0..(horizon-1)).each do |h|
    s_i = season_contribution(s, h)
    points <<  OPERATORS[seasonality].call(l * pow(b, h + 1), s_i)
  end  

  return points
end

def _Md_forecast(components, horizon, seasonality)
  points = []
  l = components.fetch("l", 0)
  b = components.fetch("b", 0)
  s = components.fetch("s", 0)
  phi = components.fetch("phi", 0)
  phi_h = phi
  (0..(horizon-1)).each do |h|
   # each season has a different contribution
   s_i = season_contribution(s, h)
   points << OPERATORS[seasonality].call(l * pow(b, phi_h), s_i)
   phi_h = phi_h + pow(phi, h + 2)
  end   
  
  return points
end

def _trivial_forecast(components, horizon)
    points = []
    submodel_points = components["value"]
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


OPERATORS = {"A": lambda = -> (x,s) { x + s }, 
             "M":  lambda = -> (x,s) { x * s }, 
             "N": lambda = -> (x,s) { x }}

def season_contribution(s_list, step)
  
   if s_list.is_a?(Array)
     period = s_list.size
     index = (- period + 1 + step % period).abs
     return s_list[index]
   else
     return 0
   end
end

def forecast(field, model_name, horizon=50)
  components = COMPONENTS.fetch(field, {}).fetch(model_name)
  if model_name
    if model_name.include?(",")
      _, trend, seasonality = model_name.split(",")
      return MODELS[trend].call(components, horizon, seasonality)
    else
      return MODELS[model_name].call(components, horizon)
    end
  else
      return {}
  end
end        
