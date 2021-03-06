.. :changelog:

History
-------
0.0.10 (2018-07-18)
~~~~~~~~~~~~~~~~~~
 - Fixing local logistic regression predictions with weight field missing in
   input data

0.0.9 (2018-06-30)
 - Modifying local fusion object to adapt to logistic regressions with
   no missing numerics allowed.

0.0.8 (2018-06-28)
~~~~~~~~~~~~~~~~~~
- Refactoring the local classes that manage models information to create  
  predictions. Now all of them allow a path, an ID or a dictionary to be 
  the first argument in the constructor

0.0.7 (2018-06-25)
~~~~~~~~~~~~~~~~~~
- Adding local fusion object and predict methods.
- Fixing error handling in local objects.
- Fixing bug in local logistic regressions when using a local stored file.

0.0.6 (2018-06-13)
~~~~~~~~~~~~~~~~~~
- Adding batch predictions for fusion resources.
- Adding predictions and evaluations for fusion resources.

0.0.5 (2018-05-23)
~~~~~~~~~~~~~~~~~~
- Fixing bug when unused field IDs are used in local prediction inputs.
- Adding methods for the REST calls to OptiMLs and Fusions
- Adding the option to `export PMML models when available.

0.0.3 (2016-08-31)
~~~~~~~~~~~~~~~~~~

- Adding REST methods to manage LDA
- Adding optional information to local predictions.
- Improving casting for booleans in local predictions
- Prediction arguments methods to array

0.0.2 (2016-08-05)
~~~~~~~~~~~~~~~~~~

- Local Models
- Local Prediction
- Local Cluster
- Local Centroid
- Local Ensemble
- Local MultiModel
- Local Anomaly Detector
- Local Anomaly Score
- Local Association
- Local Logistic Regression
- Local Logistic Regression Predictions
- Local Association Sets
- Fields
- Rule Generation
- Summary Generation

0.0.1 (2016-06-15)
~~~~~~~~~~~~~~~~~~

- Initial release for the "andromeda" version of BigML.io
- Adds REST API methods

- 
