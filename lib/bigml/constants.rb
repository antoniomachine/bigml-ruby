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
# under the License

#"Common auxiliary constants for all resources
module BigML
 
  # Basic resources
  SOURCE_PATH = 'source'
  DATASET_PATH = 'dataset'
  MODEL_PATH = 'model'
  PREDICTION_PATH = 'prediction'
  EVALUATION_PATH = 'evaluation'
  ENSEMBLE_PATH = 'ensemble'
  BATCH_PREDICTION_PATH = 'batchprediction'
  CLUSTER_PATH = 'cluster'
  CENTROID_PATH = 'centroid'
  BATCH_CENTROID_PATH = 'batchcentroid'
  ANOMALY_PATH = 'anomaly'
  ANOMALY_SCORE_PATH = 'anomalyscore'
  BATCH_ANOMALY_SCORE_PATH = 'batchanomalyscore'
  PROJECT_PATH = 'project'
  SAMPLE_PATH = 'sample'
  CORRELATION_PATH = 'correlation'
  STATISTICAL_TEST_PATH = 'statisticaltest'
  LOGISTIC_REGRESSION_PATH = 'logisticregression'
  ASSOCIATION_PATH = 'association'
  ASSOCIATION_SET_PATH = 'associationset'
  SCRIPT_PATH = 'script'
  EXECUTION_PATH = 'execution'
  LIBRARY_PATH = 'library'

  # Resource Ids patterns
  ID_PATTERN = '[a-f0-9]{24}'
  SHARED_PATTERN = '[a-zA-Z0-9]{24,30}'
  SOURCE_RE = /^#{SOURCE_PATH}\/#{ID_PATTERN}$/
  DATASET_RE = /^(public\/)?#{DATASET_PATH}\/#{ID_PATTERN}$|^shared\/#{DATASET_PATH}\/#{SHARED_PATTERN}$/
  MODEL_RE = /^(public\/)?#{MODEL_PATH}\/#{ID_PATTERN}$|^shared\/#{MODEL_PATH}\/#{SHARED_PATTERN}$/
  PREDICTION_RE = /^#{PREDICTION_PATH}\/#{ID_PATTERN}$/ 
  EVALUATION_RE = /^#{EVALUATION_PATH}\/#{ID_PATTERN}$/
  ENSEMBLE_RE = /^#{ENSEMBLE_PATH}\/#{ID_PATTERN}$/
  BATCH_PREDICTION_RE = /^#{BATCH_PREDICTION_PATH}\/#{ID_PATTERN}$/
  CLUSTER_RE = /^(public\/)?#{CLUSTER_PATH}\/#{ID_PATTERN}$|^shared\/#{CLUSTER_PATH}\/#{SHARED_PATTERN}$/

  CENTROID_RE = /^#{CENTROID_PATH}\/#{ID_PATTERN}$/
  BATCH_CENTROID_RE = /^#{BATCH_CENTROID_PATH}\/#{ID_PATTERN}$/
  ANOMALY_RE = /^(public\/)?#{ANOMALY_PATH}\/#{ID_PATTERN}$|^shared\/#{ANOMALY_PATH}\/#{SHARED_PATTERN}$/
  ANOMALY_SCORE_RE = /^#{ANOMALY_SCORE_PATH}\/#{ID_PATTERN}$/
  BATCH_ANOMALY_SCORE_RE =  /^#{BATCH_ANOMALY_SCORE_PATH}\/#{ID_PATTERN}$/
  PROJECT_RE = /^#{PROJECT_PATH}\/#{ID_PATTERN}$/
  SAMPLE_RE = /^#{SAMPLE_PATH}\/#{ID_PATTERN}$|^shared\/#{SAMPLE_PATH}\/#{SHARED_PATTERN}$/ 
  CORRELATION_RE = /^#{CORRELATION_PATH}\/#{ID_PATTERN}$|^shared\/#{CORRELATION_PATH}\/#{SHARED_PATTERN}$/
  STATISTICAL_TEST_RE = /^#{STATISTICAL_TEST_PATH}\/#{ID_PATTERN}$|^shared\/#{STATISTICAL_TEST_PATH}\/#{SHARED_PATTERN}$/ 
  LOGISTIC_REGRESSION_RE = /^#{LOGISTIC_REGRESSION_PATH}\/#{ID_PATTERN}$|^shared\/#{LOGISTIC_REGRESSION_PATH}\/#{SHARED_PATTERN}$/ 
  ASSOCIATION_RE = /^#{ASSOCIATION_PATH}\/#{ID_PATTERN}$|^shared\/#{ASSOCIATION_PATH}\/#{SHARED_PATTERN}$/
  ASSOCIATION_SET_RE = /^#{ASSOCIATION_SET_PATH}\/#{ID_PATTERN}$/
  SCRIPT_RE = /^#{SCRIPT_PATH}\/#{ID_PATTERN}$|^shared\/#{SCRIPT_PATH}\/#{SHARED_PATTERN}$/
  EXECUTION_RE = /^#{EXECUTION_PATH}\/#{ID_PATTERN}$|^shared\/#{EXECUTION_PATH}\/#{SHARED_PATTERN}$/ 
  LIBRARY_RE = /^#{LIBRARY_PATH}\/#{ID_PATTERN}$|^shared\/#{LIBRARY_PATH}\/#{SHARED_PATTERN}$/

  RESOURCE_RE = {
    SOURCE_PATH => SOURCE_RE,
    DATASET_PATH =>  DATASET_RE,
    MODEL_PATH =>  MODEL_RE,
    PREDICTION_PATH =>  PREDICTION_RE,
    EVALUATION_PATH => EVALUATION_RE,
    ENSEMBLE_PATH => ENSEMBLE_RE,
    BATCH_PREDICTION_PATH => BATCH_PREDICTION_RE,
    CLUSTER_PATH => CLUSTER_RE,
    CENTROID_PATH => CENTROID_RE,
    BATCH_CENTROID_PATH => BATCH_CENTROID_RE,
    ANOMALY_PATH => ANOMALY_RE,
    ANOMALY_SCORE_PATH => ANOMALY_SCORE_RE,
    BATCH_ANOMALY_SCORE_PATH => BATCH_ANOMALY_SCORE_RE,
    PROJECT_PATH => PROJECT_RE,
    SAMPLE_PATH => SAMPLE_RE,
    CORRELATION_PATH => CORRELATION_RE,
    STATISTICAL_TEST_PATH => STATISTICAL_TEST_RE,
    LOGISTIC_REGRESSION_PATH => LOGISTIC_REGRESSION_RE,
    ASSOCIATION_PATH => ASSOCIATION_RE,
    ASSOCIATION_SET_PATH => ASSOCIATION_SET_RE,
    SCRIPT_PATH => SCRIPT_RE,
    EXECUTION_PATH => EXECUTION_RE,
    LIBRARY_PATH => LIBRARY_RE}

  RENAMED_RESOURCES = {
    BATCH_PREDICTION_PATH => 'batch_prediction',
    BATCH_CENTROID_PATH => 'batch_centroid',
    ANOMALY_SCORE_PATH => 'anomaly_score',
    BATCH_ANOMALY_SCORE_PATH => 'batch_anomaly_score',
    STATISTICAL_TEST_PATH => 'statistical_test',
    LOGISTIC_REGRESSION_PATH => 'logistic_regression',
    ASSOCIATION_SET_PATH => 'association_set'
  }

  # Resource status codes
  WAITING = 0
  QUEUED = 1
  STARTED = 2
  IN_PROGRESS = 3
  SUMMARIZED = 4
  FINISHED = 5
  UPLOADING = 6
  FAULTY = -1
  UNKNOWN = -2
  RUNNABLE = -3

  # Minimum query string to get model fields
  TINY_RESOURCE = "full=false"

  NO_QS = [EVALUATION_RE, PREDICTION_RE, BATCH_PREDICTION_RE,
           CENTROID_RE, BATCH_CENTROID_RE, ANOMALY_SCORE_RE,
	   BATCH_ANOMALY_SCORE_RE, PROJECT_RE, ASSOCIATION_SET_RE]

end
