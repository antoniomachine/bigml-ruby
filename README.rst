BigML Ruby Bindings          
===================== 

`BigML <https://bigml.com>`_ makes machine learning easy by taking care
of the details required to add data-driven decisions and predictive
power to your company. Unlike other machine learning services, BigML
creates
`beautiful predictive models <https://bigml.com/gallery/models>`_ that
can be easily understood and interacted with.
    
These BigML Ruby bindings allow you to interact with
`BigML.io <https://bigml.io/>`_, the API
for BigML. You can use it to easily create, retrieve, list, update, and
delete BigML resources (i.e., sources, datasets, models and,
predictions).

This module is licensed under the `Apache License, Version
2.0 <http://www.apache.org/licenses/LICENSE-2.0.html>`_. 

Support
-------

Please report problems and bugs to our `BigML.io issue
tracker <https://github.com/bigmlcom/io/issues>`_.

Discussions about the different bindings take place in the general
`BigML mailing list <http://groups.google.com/group/bigml>`_. Or join us
in our `Campfire chatroom <https://bigmlinc.campfirenow.com/f20a0>`_.

Supported Ruby Versions
-----------------------

Ruby 2.0.0
Ruby 2.1.x
Ruby 2.2.x
Ruby 2.3.x

Dependencies
------------

rest-client 

Installation
------------
.. code-block:: ruby

   gem "bigml", :git => "git://github.com/antoniomachine/bigml-ruby.git"

Inside of your Ruby program do:

.. code-block:: ruby
   
   require "bigml"

Running the Tests
-----------------
Download and run the test suit:

.. code-block:: bash

  git clone git@github.com:antoniomachine/bigml-ruby.git
  cd bigml
  rake test

Authentication
--------------

All the requests to BigML.io must be authenticated using your username
and `API key <https://bigml.com/account/apikey>`_ and are always
transmitted over HTTPS.

This module will look for your username and API key in the environment
variables ``BIGML_USERNAME`` and ``BIGML_API_KEY`` respectively. You can
add the following lines to your ``.bashrc`` or ``.bash_profile`` to set
those variables automatically when you log in:

.. code-block:: bash

    export BIGML_USERNAME=myusername
    export BIGML_API_KEY=ae579e7e53fb9abd646a6ff8aa99d4afe83ac291

With that environment set up, connecting to BigML is a breeze:

.. code-block:: ruby

    require 'bigml'
    api = BigML::Api.new

Otherwise, you can initialize directly when instantiating the BigML
class as follows:

.. code-block:: ruby

    api = BigML::Api.new('myusername', 'ae579e7e53fb9abd646a6ff8aa99d4afe83ac291')

Also, you can initialize the library to work in the Sandbox environment by
passing the parameter ``dev_mode``:

.. code-block:: ruby

    api = BigML::Api.new('myusername', 'ae579e7e53fb9abd646a6ff8aa99d4afe83ac291', true)

Quick Start
-----------

Imagine that you want to use `this csv
file <https://static.bigml.com/csv/iris.csv>`_ containing the `Iris
flower dataset <http://en.wikipedia.org/wiki/Iris_flower_data_set>`_ to
predict the species of a flower whose ``sepal length`` is ``5`` and
whose ``sepal width`` is ``2.5``. A preview of the dataset is shown
below. It has 4 numeric fields: ``sepal length``, ``sepal width``,
``petal length``, ``petal width`` and a categorical field: ``species``.
By default, BigML considers the last field in the dataset as the
objective field (i.e., the field that you want to generate predictions
for).

::

    sepal length,sepal width,petal length,petal width,species
    5.1,3.5,1.4,0.2,Iris-setosa
    4.9,3.0,1.4,0.2,Iris-setosa
    4.7,3.2,1.3,0.2,Iris-setosa
    ...
    5.8,2.7,3.9,1.2,Iris-versicolor
    6.0,2.7,5.1,1.6,Iris-versicolor
    5.4,3.0,4.5,1.5,Iris-versicolor
    ...
    6.8,3.0,5.5,2.1,Iris-virginica
    5.7,2.5,5.0,2.0,Iris-virginica
    5.8,2.8,5.1,2.4,Iris-virginica

You can easily generate a prediction following these steps:

.. code-block:: ruby

    require 'bigml'

    api = BigML::Api.new()

    source = api.create_source('./data/iris.csv')
    dataset = api.create_dataset(source)
    model = api.create_model(dataset)
    prediction = api.create_prediction(model, {'sepal length' => 5, 'sepal width' => 2.5})

You can then print the prediction using the ``pprint`` method:

.. code-block:: ruby

    api.pprint(prediction)
    species for {"sepal length"=>5, "sepal width"=>2.5} is Iris-setosa


Fields Structure
----------------

BigML automatically generates idenfiers for each field. To see the
fields and the ids and types that have been assigned to a source you can
use ``get_fields``:

.. code-block:: ruby 

     source = api.get_source(source)
     api.pprint(api.get_fields(source))

     {"000000"=>
         {"column_number"=>0,
          "name"=>"sepal length",
          "optype"=>"numeric",
          "order"=>0},
      "000001"=>
          {"column_number"=>1, 
           "name"=>"sepal width", 
           "optype"=>"numeric", 
           "order"=>1},
      "000002"=>
          {"column_number"=>2,
           "name"=>"petal length",
           "optype"=>"numeric",
           "order"=>2},
      "000003"=>
          {"column_number"=>3, 
           "name"=>"petal width", 
           "optype"=>"numeric", 
           "order"=>3},
      "000004"=>
          {"column_number"=>4,
           "name"=>"species",
           "optype"=>"categorical",
           "order"=>4,
           "term_analysis"=>{"enabled"=>true}}}

When the number of fields becomes very large, it can be useful to exclude or
filter them. This can be done using a query string expression, for instance:

.. code-block:: ruby

    source = api.get_source(source, "limit=10&order_by=name")

would include in the retrieved dictionary the first 10 fields sorted by name.

Dataset
-------

If you want to get some basic statistics for each field you can retrieve
the ``fields`` from the dataset as follows to get a dictionary keyed by
field id:

.. code-block:: ruby

    dataset = api.get_dataset(dataset)
    api.pprint(api.get_fields(dataset))

    {"000000"=>
            {"column_number"=>0,
             "datatype"=>"double",
             "name"=>"sepal length",
             "optype"=>"numeric",
             "order"=>0,
             "preferred"=>true,
             "summary"=>
             {"bins"=>
                     [[4.3, 1],
                      [4.425, 4],
                      [4.6, 4],
                      [4.77143, 7],
                      [4.9625, 16],
                      [5.1, 9],
                      ...
                      [6.3, 9]],
             "kurtosis"=>-0.57357,
             "maximum"=>7.9,
             "mean"=>5.84333,
             "median"=>5.8,
             "minimum"=>4.3,
             "missing_count"=>0,
             "population"=>150,
             "skewness"=>0.31175,
             "splits"=>
                    [4.51526,
                     4.67252,
                     4.81113,
                     4.89582,
                     4.96139,
                     ...
                     7.64746],
             "standard_deviation"=>0.82807,
             "sum"=>876.5,
             "sum_squares"=>5223.85,
             "variance"=>0.68569}},
      "000001"=>
             {"column_number"=>1,
              "datatype"=>"double",
              ...
      "000002"=>
             {"column_number"=>2,
             ...
      "000003"=> ...
      "000004"=>
             {"column_number"=>4,
              "datatype"=>"string",
              "name"=>"species",
              "optype"=>"categorical",
              "order"=>4,
              "preferred"=>true,
              "summary"=>
                  {"categories"=>
                     [["Iris-setosa", 50], ["Iris-versicolor", 50], ["Iris-virginica", 50]],
                      "missing_count"=>0},
              "term_analysis"=>{"enabled"=>true}}}


The field filtering options are also available using a query string expression,
for instance:

.. code-block:: ruby

    dataset = api.get_dataset(dataset, "limit=20")

limits the number of fields that will be included in ``dataset`` to 20.


Model
-----

One of the greatest things about BigML is that the models that it
generates for you are fully white-boxed. To get the explicit tree-like
predictive model for the example above:

.. code-block:: ruby

    model = api.get_model(model)
    api.pprint(model['object']['model']['root'])

    {"children"=>
      [{"children"=>
         [{"children"=>
            [{"confidence"=>0.91033,
              "count"=>39,
              "id"=>3,
              "objective_summary"=>{"categories"=>[["Iris-virginica", 39]]},
              "output"=>"Iris-virginica",
              "predicate"=>{"field"=>"000003", "operator"=>">", "value"=>1.75}},
          {"children"=>
             [{"children"=>
                [{"confidence"=>0.20654,
                  "count"=>1,
                  "id"=>6,
                  "objective_summary"=>{"categories"=>[["Iris-virginica", 1]]},
                  "output"=>"Iris-virginica",
                  "predicate"=>
                   {"field"=>"000002", "operator"=>">", "value"=>5.45}},
                  {"confidence"=>0.34237,
                   "count"=>2,
                   "id"=>7,
                   "objective_summary"=>{"categories"=>[["Iris-versicolor", 2]]},
                   "output"=>"Iris-versicolor",
                   "predicate"=>
                      {"field"=>"000002", "operator"=>"<=", "value"=>5.45}}],
                   "confidence"=>0.20765,
                   "count"=>3,
                   "id"=>5,
                   "objective_summary"=>
                   {"categories"=>[["Iris-versicolor", 2], ["Iris-virginica", 1]]},
                    "output"=>"Iris-versicolor",
                    "predicate"=>{"field"=>"000003", "operator"=>">", "value"=>1.55}},
                    {"confidence"=>0.5101,
                     "count"=>4,
                     "id"=>8,
                     "objective_summary"=>{"categories"=>[["Iris-virginica", 4]]},
                     "output"=>"Iris-virginica",
                     "predicate"=>
                     {"field"=>"000003", "operator"=>"<=", "value"=>1.55}}],
                     "confidence"=>0.35893,
                     "count"=>7,
                     "id"=>4,
                     "objective_summary"=>
       ...

(Note that we have abbreviated the output in the snippet above for
readability: the full predictive model you'll get is going to contain
much more details).

Again, filtering options are also available using a query string expression,
for instance:

.. code-block:: ruby

    model = api.get_model(model, "limit=5")

limits the number of fields that will be included in ``model`` to 5.

Evaluation
----------

The predictive performance of a model can be measured using many different
measures. In BigML these measures can be obtained by creating evaluations. To
create an evaluation you need the id of the model you are evaluating and the id
of the dataset that contains the data to be tested with. The result is shown
as:

.. code-block:: ruby 

    evaluation = api.get_evaluation(evaluation)
    api.pprint(evaluation['object']['result'])
  
    {"class_names"=>["Iris-setosa", "Iris-versicolor", "Iris-virginica"],
     "mode"=> {"accuracy"=>0.33333,
               "average_f_measure"=>0.16667,
               "average_one_point_auc"=>0.5,
               "average_phi"=>0,
               "average_precision"=>0.11111,
               "average_recall"=>0.33333,
               "confusion_matrix"=>[[50, 0, 0], [50, 0, 0], [50, 0, 0]],
               "per_class_statistics"=> 
                    [{"accuracy"=>0.3333333333333333,
                      "class_name"=>"Iris-setosa",
                      "f_measure"=>0.5,
                      "one_point_auc"=>0.5,
                      "phi_coefficient"=>0,
                      "precision"=>0.3333333333333333,
                      "present_in_test_data"=>true,
                      "recall"=>1.0},
                     {"accuracy"=>0.6666666666666667,
                      "class_name"=>"Iris-versicolor",
                       "f_measure"=>0,
                       "one_point_auc"=>0.5,
                       "phi_coefficient"=>0,
                       "precision"=>0,
                       "present_in_test_data"=>true,
                       "recall"=>0.0},
                     {"accuracy"=>0.6666666666666667,
                       "class_name"=>"Iris-virginica",
                       "f_measure"=>0,
                       "one_point_auc"=>0.5,
                       "phi_coefficient"=>0,
                       "precision"=>0,
                       "present_in_test_data"=>true,
                       "recall"=>0.0}]},
      "model"=> {"accuracy"=>1,
                 "average_f_measure"=>1,
                 "average_one_point_auc"=>1,
                 "average_phi"=>1,
                 "average_precision"=>1,
                 "average_recall"=>1,
                 "confusion_matrix"=>[[50, 0, 0], [0, 50, 0], [0, 0, 50]],
                 "per_class_statistics"=>
                 [{"accuracy"=>1.0,
                   ....
                   "recall"=>1.0}]},
      "random"=> {"accuracy"=>0.32,
                 "average_f_measure"=>0.31823,
                 "average_one_point_auc"=>0.49,
                 "average_phi"=>-0.02088,
                 "average_precision"=>0.31763,
                 "average_recall"=>0.32,
                 "confusion_matrix"=>[[20, 14, 16], [15, 16, 19], [21, 17, 12]],
                 "per_class_statistics"=>
                 [{"accuracy"=>0.56,
                   ....
                   "recall"=>0.24}]}}

where two levels of detail are easily identified. For classifications,
the first level shows these keys:

-  **class_names**: A list with the names of all the categories for the objective field (i.e., all the classes)
-  **mode**: A detailed result object. Measures of the performance of the classifier that predicts the mode class for all the instances in the dataset
-  **model**: A detailed result object.
-  **random**: A detailed result object.  Measures the performance of the classifier that predicts a random class for all the instances in the dataset.

and the detailed result objects include ``accuracy``, ``average_f_measure``, ``average_phi``,
``average_precision``, ``average_recall``, ``confusion_matrix``
and ``per_class_statistics``.

For regressions first level will contain these keys:

-  **mean**: A detailed result object. Measures the performance of the model that predicts the mean for all the instances in the dataset.
-  **model**: A detailed result object.
-  **random**: A detailed result object. Measures the performance of the model that predicts a random class for all the instances in the dataset.

where the detailed result objects include ``mean_absolute_error``,
``mean_squared_error`` and ``r_squared`` (refer to
`developers documentation <https://bigml.com/developers/evaluations>`_ for
more info on the meaning of these measures.


Cluster
-------

For unsupervised learning problems, the cluster is used to classify in a
limited number of groups your training data. The cluster structure is defined
by the centers of each group of data, named centroids, and the data enclosed
in the group. As for in the model's case, the cluster is a white-box resource
and can be retrieved as a JSON:

.. code-block:: ruby

    cluster = api.get_cluster(cluster)
    api.pprint(cluster['object'])

    {   'balance_fields' => true,
        'category' => 0,
        'cluster_datasets' => {   '000000' => '', '000001' => '', '000002' => ''},
        'cluster_datasets_ids' => {   '000000' => '53739b9ae4b0dad82b0a65e6',
                                    '000001' => '53739b9ae4b0dad82b0a65e7',
                                    '000002' => '53739b9ae4b0dad82b0a65e8'},
        'cluster_seed' => '2c249dda00fbf54ab4cdd850532a584f286af5b6',
        'clusters' => {   'clusters' => [   {   'center' => {   '000000' => 58.5,
                                                          '000001' => 26.8314,
                                                          '000002' => 44.27907,
                                                          '000003' => 14.37209},
                                            'count' => 56,
                                            'distance' => {   'bins' => [   [   0.69602,
                                                                            2],
                                                                        [ ... ]
                                                                        [   3.77052,
                                                                            1]],
                                                            'maximum' =>3.77052,
                                                            'mean' => 1.61711,
                                                            'median' => 1.52146,
                                                            'minimum' =>  0.69237,
                                                            'population' => 56,
                                                            'standard_deviation' => 0.6161,
                                                            'sum' => 90.55805,
                                                            'sum_squares' => 167.31926,
                                                            'variance' =>0.37958},
                                            'id' => '000000',
                                            'name' =>  'Cluster 0'},
                                        {   'center' => {   '000000' => 50.06,
                                                          '000001' => 34.28,
                                                          '000002' => 14.62,
                                                          '000003' => 2.46},
                                            'count' => 50,
                                            'distance' => {   'bins' => [   [   0.16917,
                                                                            1],
                                                                        [ ... ]
                                                                        [   4.94699,
                                                                            1]],
                                                            'maximum' => 4.94699,
                                                            'mean' => 1.50725,
                                                            'median' => 1.3393,
                                                            'minimum' => 0.16917,
                                                            'population' => 50,
                                                            'standard_deviation' => 1.00994,
                                                            'sum' => 75.36252,
                                                            'sum_squares' => 163.56918,
                                                            'variance' => 1.01998},
                                            'id' => '000001',
                                            'name' => 'Cluster 1'},
                                        {   'center' => { '000000' => 68.15625,
                                                          '000001' => 31.25781,
                                                          '000002' => 55.48438,
                                                          '000003' => 19.96875},
                                            'count' => 44,
                                            'distance' => {   'bins' => [   [   0.36825,
                                                                            1],
                                                                        [ ... ]
                                                                        [   3.87216,
                                                                            1]],
                                                            'maximum' => 3.87216,
                                                            'mean' => 1.67264,
                                                            'median' => 1.63705,
                                                            'minimum' => 0.36825,
                                                            'population' => 44,
                                                            'standard_deviation' => 0.78905,
                                                            'sum' => 73.59627,
                                                            'sum_squares' => 149.87194,
                                                            'variance' => 0.6226},
                                            'id' => '000002',
                                            'name' => 'Cluster 2'}],
                        'fields' => {   '000000' => { 'column_number' => 0,
                                                    'datatype'  =>'int8',
                                                    'name' => 'sepal length',
                                                    'optype' => 'numeric',
                                                    'order' => 0,
                                                    'preferred' => true,
                                                    'summary' => {   'bins' => [   [   43.75,
                                                                                   4],
                                                                               [ ... ]
                                                                               [   79,
                                                                                   1]],
                                                                   'maximum' => 79,
                                                                   'mean' => 58.43333,
                                                                   'median' => 57.7889,
                                                                   'minimum' => 43,
                                                                   'missing_count' => 0,
                                                                   'population' => 150,
                                                                   'splits' => [   45.15258,
                                                                                 46.72525,
                                                                              72.04226,
                                                                                 76.47461],
                                                                   'standard_deviation' => 8.28066,
                                                                   'sum' => 8765,
                                                                   'sum_squares' => 522385,
                                                                   'variance' => 68.56935}},
                                                                    [ ... ]
                                                                                 [   25,
                                                                                     3]],
                                                                   'maximum' => 25,
                                                                   'mean' => 11.99333,
                                                                   'median' => 13.28483,
                                                                   'minimum' => 1,
                                                                   'missing_count' => 0,
                                                                   'population' => 150,
                                                                   'standard_deviation' => 7.62238,
                                                                   'sum' => 1799,
                                                                   'sum_squares' => 30233,
                                                                   'variance' => 58.10063}}}},
        'code' => 202,
        'columns' => 4,
        'created' => '2014-05-14T16:36:40.993000',
        'credits' => 0.017578125,
        'credits_per_prediction' => 0.0,
        'dataset' => 'dataset/53739b88c8db63122b000411',
        'dataset_field_types' => { 'categorical' => 1,
                                   'datetime' => 0,
                                   'numeric' => 4,
                                   'preferred' => 5,
                                   'text' => 0,
                                   'total' => 5},
        'dataset_status' => true,
        'dataset_type' => 0,
        'description' => '',
        'excluded_fields' => ['000004'],
        'field_scales' => nil,
        'fields_meta' => { 'count' => 4,
                           'limit' => 1000,
                           'offset' => 0,
                           'query_total' => 4,
                           'total' => 4},
        'input_fields' => ['000000', '000001', '000002', '000003'],
        'k' => 3,
        'locale' => 'es-ES',
        'max_columns' => 5,
        'max_rows' => 150,
        'name' => 'my iris',
        'number_of_batchcentroids' => 0,
        'number_of_centroids' => 0,
        'number_of_public_centroids' => 0,
        'out_of_bag' => false,
        'price' => 0.0,
        'private' => true,
        'range' => [1, 150],
        'replacement' => false,
        'resource' => 'cluster/53739b98d994972da7001de8',
        'rows' => 150,
        'sample_rate' => 1.0,
        'scales' => { '000000' => 0.22445382597655375,
                      '000001' => 0.4264213814821549,
                      '000002' => 0.10528680248949522,
                      '000003' => 0.2438379900517961},
        'shared' => false,
        'size' => 4608,
        'source' => 'source/53739b24d994972da7001ddd',
        'source_status' =>  true,
        'status' => { 'code' => 5,
                      'elapsed' => 1009,
                      'message' => 'The cluster has been created',
                      'progress' => 1.0},
        'subscription' => true,
        'tags' => [],
        'updated' => '2014-05-14T16:40:26.234728',
        'white_box' => false}

(Note that we have abbreviated the output in the snippet above for
readability: the full predictive cluster you'll get is going to contain
much more details).


Anomaly detector
----------------

For anomaly detection problems, BigML anomaly detector uses iforest as an
unsupervised kind of model that detects anomalous data in a dataset. The
information it returns encloses a `top_anomalies` block
that contains a list of the most anomalous
points. For each, we capture a `score` from 0 to 1.  The closer to 1,
the more anomalous. We also capture the `row` which gives values for
each field in the order defined by `input_fields`.  Similarly we give
a list of `importances` which match the `row` values.  These
importances tell us which values contributed most to the anomaly
score. Thus, the structure of an anomaly detector is similar to:

.. code-block:: ruby

    {   'category' => 0,
        'code' => 200,
        'columns' => 14,
        'constraints' => false,
        'created' => '2014-09-08T18:51:11.893000',
        'credits' => 0.11653518676757812,
        'credits_per_prediction' => 0.0,
        'dataset' => 'dataset/540dfa9d9841fa5c88000765',
        'dataset_field_types' => { 'categorical' => 21,
                                   'datetime' => 0,
                                   'numeric' => 21,
                                   'preferred' => 14,
                                   'text' => 0,
                                   'total' =>42},
        'dataset_status' => true,
        'dataset_type' => 0,
        'description' => '',
        'excluded_fields' => [],
        'fields_meta' => { 'count' => 14,
                           'limit' => 1000,
                           'offset' => 0,
                           'query_total' => 14,
                           'total' => 14},
        'forest_size' => 128,
        'input_fields' => [ '000004',
                            '000005',
                            '000009',
                            '000016',
                            '000017',
                            '000018',
                            '000019',
                            '00001e',
                            '00001f',
                            '000020',
                            '000023',
                            '000024',
                            '000025',
                            '000026'],
        'locale' => 'en_US',
        'max_columns' => 42,
        'max_rows' => 200,
        'model' => {   'fields' =>: {   '000004' => {   'column_number' => 4,
                                                 'datatype' => 'int16',
                                                 'name' => 'src_bytes',
                                                 'optype' => 'numeric',
                                                 'order' => 0,
                                                 'preferred' => true,
                                                 'summary' => {   'bins' => [   [   143,
                                                                                2],
                                                                            ...
                                                                            [   370,
                                                                                2]],
                                                                'maximum' => 370,
                                                                'mean' => 248.235,
                                                                'median' => 234.57157,
                                                                'minimum' => 141,
                                                                'missing_count' => 0,
                                                                'population' => 200,
                                                                'splits' => [   159.92462,
                                                                              173.73312,
                                                                              188,
                                                                              ...
                                                                              339.55228],
                                                                'standard_deviation' => 49.39869,
                                                                'sum' => 49647,
                                                                'sum_squares' => 12809729,
                                                                'variance' => 2440.23093}},
                                   '000005' => {   'column_number' => 5,
                                                 'datatype' => 'int32',
                                                 'name' => 'dst_bytes',
                                                 'optype' => 'numeric',
                                                 'order' => 1,
                                                 'preferred' => true,
                                                  ...
                                                                'sum' => 1030851,
                                                                'sum_squares' => 22764504759,
                                                                'variance' => 87694652.45224}},
                                   '000009' => {   'column_number' => 9,
                                                 'datatype' => 'string',
                                                 'name' => 'hot',
                                                 'optype' => 'categorical',
                                                 'order' => 2,
                                                 'preferred' => true,
                                                 'summary' => {   'categories' => [   [   '0',
                                                                                      199],
                                                                                  [   '1',
                                                                                      1]],
                                                                'missing_count' => 0},
                                                 'term_analysis' => {   'enabled' => true}},
                                   '000016' => {   'column_number' => 22,
                                                 'datatype' => 'int8',
                                                 'name' => 'count',
                                                 'optype' => 'numeric',
                                                 'order' => 3,
                                                 'preferred' => true,
                                                                ...
                                                                'population' => 200,
                                                                'standard_deviation' => 5.42421,
                                                                'sum' => 1351,
                                                                'sum_squares' => 14981,
                                                                'variance' => 29.42209}},
                                   '000017' => { ... }}},
                     'kind' => 'iforest',
                     'mean_depthu => 12.314174107142858,
                     'top_anomalies' => [   {   'importance' => [ 0.06768,
                                                                0.01667,
                                                                0.00081,
                                                                0.02437,
                                                                0.04773,
                                                                0.22197,
                                                                0.18208,
                                                                0.01868,
                                                                0.11855,
                                                                0.01983,
                                                                0.01898,
                                                                0.05306,
                                                                0.20398,
                                                                0.00562],
                                              'row' => [ 183.0,
                                                         8654.0,
                                                         '0',
                                                         4.0,
                                                         4.0,
                                                         0.25,
                                                         0.25,
                                                         0.0,
                                                         123.0,
                                                         255.0,
                                                         0.01,
                                                         0.04,
                                                         0.01,
                                                         0.0],
                                              'score' => 0.68782},
                                          {   'importance' => [   0.05645,
                                                                0.02285,
                                                                0.0015,
                                                                0.05196,
                                                                0.04435,
                                                                0.0005,
                                                                0.00056,
                                                                0.18979,
                                                                0.12402,
                                                                0.23671,
                                                                0.20723,
                                                                0.05651,
                                                                0.00144,
                                                                0.00612],
                                              'row' => [   212.0,
                                                         1940.0,
                                                         '0',
                                                         1.0,
                                                         2.0,
                                                         0.0,
                                                         0.0,
                                                         1.0,
                                                         1.0,
                                                         69.0,
                                                         1.0,
                                                         0.04,
                                                         0.0,
                                                         0.0],
                                              'score' => 0.6239},
                                              ...],
                     'trees' => [   {   'root' => {   'children' => [   {   'children' => [   {   'children' => [   {   'children' => [   {   'children =>'
     [   {   'population' => 1,
                                                                                                                                  'predicates' => [   {   'field' => '00001f',
                                                                                                                                                        'op' => '>',
                                                                                                                                                        'value' => 35.54357}]},

    ...
                                                                                                                              {   'population' => 1,
                                                                                                                                  'predicates' => [   {   'field' => '00001f',
                                                                                                                                                        'op' => '<=',
                                                                                                                                                        'value' => 35.54357}]}],
                                                                                                              'population' => 2,
                                                                                                              'predicates' => [   {   'field' => '000005',
                                                                                                                                    'op' => '<=',
                                                                                                                                    'value' => 1385.5166}]}],
                                                                                          'population'=> 3,
                                                                                          'predicates' => [   {   'field' =>'000020',
                                                                                                                'op' => '<=',
                                                                                                                'value' => 65.14308},
                                                                                                            {   'field' => '000019',
                                                                                                                'op' => '=',
                                                                                                                'value' => 0}]}],
                                                                      'population' => 105,
                                                                      'predicates' => [   {   'field' => '000017',
                                                                                            'op' =>  '<=',
                                                                                            'value' => 13.21754},
                                                                                        {   'field' => '000009',
                                                                                            'op' => 'in',
                                                                                            'value' => [   '0']}]}],
                                                  'population' => 126,
                                                  'predicates' => [   true,
                                                                    {   'field' =>  '000018',
                                                                        'op' => '=',
                                                                        'value' => 0}]},
                                      'training_mean_depth' => 11.071428571428571}]},
        'name' => "tiny_kdd's dataset anomaly detector",
        'number_of_batchscores' =>  0,
        'number_of_public_predictions' => 0,
        'number_of_scores' => 0,
        'out_of_bag' => false,
        'price' => 0.0,
        'private' => true,
        'project' => nil,
        'range' => [1, 200],
        'replacement' => false,
        'resource' => 'anomaly/540dfa9f9841fa5c8800076a',
        'rows' => 200,
        'sample_rate' =>: 1.0,
        'sample_size' => 126,
        'seed' => 'BigML',
        'shared' =>  false,
        'size' => 30549,
        'source' => 'source/540dfa979841fa5c7f000363',
        'source_status' => true,
        'status' => {   'code' =>  5,
                      'elapsed' => 32397,
                      'message' => 'The anomaly detector has been created',
                      'progress' => 1.0},
        'subscription' => false,
        'tags' => [],
       'updated' => '2014-09-08T23:54:28.647000',
        'white_box' => false}

Note that we have abbreviated the output in the snippet above for
readability: the full anomaly detector you'll get is going to contain
much more details).

The `trees` list contains the actual isolation forest, and it can be quite
large usually. That's why, this part of the resource should only be included
in downloads when needed. If you are only interested in other properties, such
as `top_anomalies`, you'll improve performance by excluding it, using the
`excluded=trees` query string in the API call:

.. code-block:: ruby

    anomaly = api.get_anomaly('anomaly/540dfa9f9841fa5c8800076a', 
                              query_string='excluded=trees')

Each node in an isolation tree can have multiple predicates.
For the node to be a valid branch when evaluated with a data point, all of its
predicates must be true.

Samples
-------

To provide quick access to your row data you can create a ``sample``. Samples
are in-memory objects that can be queried for subsets of data by limiting
their size, the fields or the rows returned. The structure of a sample would
be::

Samples are not permanent objects. Once they are created, they will be
available as long as GETs are requested within periods smaller than
a pre-established TTL (Time to Live). The expiration timer of a sample is
reset every time a new GET is received.

If requested, a sample can also perform linear regression and compute
Pearson's and Spearman's correlations for either one numeric field
against all other numeric fields or between two specific numeric fields.

Correlations
------------

A ``correlation`` resource contains a series of computations that reflect the
degree of dependence between the field set as objective for your predictions
and the rest of fields in your dataset. The dependence degree is obtained by
comparing the distributions in every objective and non-objective field pair,
as independent fields should have probabilistic
independent distributions. Depending on the types of the fields to compare,
the metrics used to compute the correlation degree will be:

- for numeric to numeric pairs:
  `Pearson's <https://en.wikipedia.org/wiki/Pearson_product-moment_correlation_coefficient>`_
  and `Spearman's correlation <https://en.wikipedia.org/wiki/Spearman%27s_rank_correlation_coefficient>`_
  coefficients.
- for numeric to categorical pairs:
  `One-way Analysis of Variance <https://en.wikipedia.org/wiki/One-way_analysis_of_variance>`_, with the
  categorical field as the predictor variable.
- for categorical to categorical pairs:
  `contingency table (or two-way table) <https://en.wikipedia.org/wiki/Contingency_table>`,
  `Chi-square test of independence <https://en.wikipedia.org/wiki/Pearson%27s_chi-squared_test>`_
  , and `Cramer's V <https://en.wikipedia.org/wiki/Cram%C3%A9r%27s_V>`_
  and `Tschuprow's T <https://en.wikipedia.org/wiki/Tschuprow%27s_T>`_ coefficients.

An example of the correlation resource JSON structure is:

.. code-block:: ruby

    require 'bigml'
    api = BigML.Api.new
    correlation = api.create_correlation('dataset/55b7a6749841fa2500000d41')
    api.ok(correlation)
    api.pprint(correlation['object'])

    {   'category' => 0,
        'clones' => 0,
        'code' => 200,
        'columns' => 5,
        'correlations' => {   'correlations' => [   {   'name' => 'one_way_anova',
                                                      'result' => {   '000000' => {   'eta_square' => 0.61871,
                                                                                    'f_ratio' => 119.2645,
                                                                                    'p_value' => 0,
                                                                                    'significant' => [   true,
                                                                                                        true,
                                                                                                        true]},
                                                                     '000001' => {   'eta_square' => 0.40078,
                                                                                    'f_ratio' => 49.16004,
                                                                                    'p_value' => 0,
                                                                                    'significant' => [   true,
                                                                                                        true,
                                                                                                        true]},
                                                                     '000002' => {   'eta_square' => 0.94137,
                                                                                    'f_ratio' => 1180.16118,
                                                                                    'p_value' => 0,
                                                                                    'significant' => [   true,
                                                                                                        true,
                                                                                                        true]},
                                                                     '000003' => {   'eta_square' => 0.92888,
                                                                                    'f_ratio' => 960.00715,
                                                                                    'p_value' => 0,
                                                                                    'significant' => [ true,
                                                                                                        true,
                                                                                                        true]}}}],
                             'fields' => {   '000000' => {   'column_number' => 0,
                                                           'datatype' => 'double',
                                                           'idx' => 0,
                                                           'name' => 'sepal length',
                                                           'optype' => 'numeric',
                                                           'order' => 0,
                                                           'preferred' => true,
                                                           'summary' => {   'bins' => [   [   4.3,
                                                                                            1],
                                                                                        [   4.425,
                                                                                            4],
    ...
                                                                                        [   7.9,
                                                                                            1]],
                                                                           'kurtosis' => -0.57357,
                                                                           'maximum' => 7.9,
                                                                           'mean' => 5.84333,
                                                                           'median' => 5.8,
                                                                           'minimum' => 4.3,
                                                                           'missing_count' => 0,
                                                                           'population' => 150,
                                                                           'skewness' => 0.31175,
                                                                           'splits' => [   4.51526,
                                                                                          4.67252,
                                                                                          4.81113,
                                                                                          4.89582,
                                                                                          4.96139,
                                                                                          5.01131,
    ...
                                                                                          6.92597,
                                                                                          7.20423,
                                                                                          7.64746],
                                                                           'standard_deviation' => 0.82807,
                                                                           'sum' => 876.5,
                                                                           'sum_squares' => 5223.85,
                                                                           'variance' => 0.68569}},
                                            '000001' => { 'column_number' => 1,
                                                           'datatype' => 'double',
                                                           'idx' => 1,
                                                           'name' => 'sepal width',
                                                           'optype' => 'numeric',
                                                           'order' => 1,
                                                           'preferred' => true,
                                                           'summary' => {   'counts' => [   [   2,
                                                                                              1],
                                                                                          [   2.2,
    ...
                                            '000004' => { 'column_number' => 4,
                                                           'datatype' => 'string',
                                                           'idx' => 4,
                                                           'name' => 'species',
                                                           'optype' => 'categorical',
                                                           'order' => 4,
                                                           'preferred' => true,
                                                           'summary' >= {   'categories' => [   [   'Iris-setosa',
                                                                                                  50],
                                                                                              [   'Iris-versicolor',
                                                                                                  50],
                                                                                              [   'Iris-virginica',
                                                                                                  50]],
                                                                           'missing_count'=> 0},
                                                           'term_analysis' => {   'enabled' => true}}},
                             'significance_levels' => [0.01, 0.05, 0.1]},
        'created' => '2015-07-28T18:07:37.010000',
        'credits' => 0.017581939697265625,
        'dataset' => 'dataset/55b7a6749841fa2500000d41',
        'dataset_status' => true,
        'dataset_type' => 0,
        'description' => '',
        'excluded_fields' => [],
        'fields_meta'=> {  'count' => 5,
                            'limit' => 1000,
                            'offset' => 0,
                            'query_total' => 5,
                            'total' => 5},
        'input_fields' => ['000000', '000001', '000002', '000003'],
        'locale' => 'en_US',
        'max_columns' => 5,
        'max_rows' => 150,
        'name' => "iris' dataset correlation",
        'objective_field_details' => {   'column_number' => 4,
                                        'datatype' => 'string',
                                        'name' => 'species',
                                        'optype' => 'categorical',
                                        'order' => 4},
        'out_of_bag' => false,
        'price' => 0.0,
        'private' => true,
        'project'=>  nil,
        'range' => [1, 150],
        'replacement' => false,
        'resource' => 'correlation/55b7c4e99841fa24f20009bf',
        'rows' => 150,
        'sample_rate' => 1.0,
        'shared' => false,
        'size' => 4609,
        'source' => 'source/55b7a6729841fa24f100036a',
        'source_status' =>  true,
        'status' => {   'code' => 5,
                       'elapsed' => 274,
                       'message' =>  'The correlation has been created',
                       'progress' => 1.0},
        'subscription' => true,
        'tags' => [],
        'updated' => '2015-07-28T18:07:49.057000',
        'white_box' => false}

Note that the output in the snippet above has been abbreviated. As you see, the
``correlations`` attribute contains the information about each field
correlation to the objective field.

Statistical Tests
-----------------

A ``statisticaltest`` resource contains a series of tests
that compare the
distribution of data in each numeric field of a dataset
to certain canonical distributions,
such as the
`normal distribution <https://en.wikipedia.org/wiki/Normal_distribution>`_
or `Benford's law <https://en.wikipedia.org/wiki/Benford%27s_law>`_
distribution. Statistical test are useful in tasks such as fraud, normality,
or outlier detection.

- Fraud Detection Tests:
Benford: This statistical test performs a comparison of the distribution of
first significant digits (FSDs) of each value of the field to the Benford's
law distribution. Benford's law applies to numerical distributions spanning
several orders of magnitude, such as the values found on financial balance
sheets. It states that the frequency distribution of leading, or first
significant digits (FSD) in such distributions is not uniform.
On the contrary, lower digits like 1 and 2 occur disproportionately
often as leading significant digits. The test compares the distribution
in the field to Bendford's distribution using a Chi-square goodness-of-fit
test, and Cho-Gaines d test. If a field has a dissimilar distribution,
it may contain anomalous or fraudulent values.

- Normality tests:
These tests can be used to confirm the assumption that the data in each field
of a dataset is distributed according to a normal distribution. The results
are relevant because many statistical and machine learning techniques rely on
this assumption.
Anderson-Darling: The Anderson-Darling test computes a test statistic based on
the difference between the observed cumulative distribution function (CDF) to
that of a normal distribution. A significant result indicates that the
assumption of normality is rejected.
Jarque-Bera: The Jarque-Bera test computes a test statistic based on the third
and fourth central moments (skewness and kurtosis) of the data. Again, a
significant result indicates that the normality assumption is rejected.
Z-score: For a given sample size, the maximum deviation from the mean that
would expected in a sampling of a normal distribution can be computed based
on the 68-95-99.7 rule. This test simply reports this expected deviation and
the actual deviation observed in the data, as a sort of sanity check.

- Outlier tests:
Grubbs: When the values of a field are normally distributed, a few values may
still deviate from the mean distribution. The outlier tests reports whether
at least one value in each numeric field differs significantly from the mean
using Grubb's test for outliers. If an outlier is found, then its value will
be returned.

The JSON structure for ``statisticaltest`` resources is similar to this one:

.. code-block:: ruby

    statistical_test = api.create_statistical_test('dataset/55b7a6749841fa2500000d41')
    api.ok(statistical_test)
    api.pprint(statistical_test['object'])

    api.pprint(statistical_test['object'])
    {   'category' => 0,
        'clones' => 0,
        'code' => 200,
        'columns' => 5,
        'created' => '2015-07-28T18:16:40.582000',
        'credits' => 0.017581939697265625,
        'dataset' => 'dataset/55b7a6749841fa2500000d41',
        'dataset_status' => true,
        'dataset_type' => 0,
        'description' => '',
        'excluded_fields' => [],
        'fields_meta' => {   'count' => 5,
                            'limit' => 1000,
                            'offset' => 0,
                            'query_total' => 5,
                            'total' => 5},
        'input_fields' => ['000000', '000001', '000002', '000003'],
        'locale' => 'en_US',
        'max_columns' => 5,
        'max_rows' => 150,
        'name' => u"iris' dataset test",
        'out_of_bag' => false,
        'price' => 0.0,
        'private' => true,
        'project' => nil,
        'range' => [1, 150],
        'replacement' => false,
        'resource' => 'statisticaltest/55b7c7089841fa25000010ad',
        'rows' => 150,
        'sample_rate' => 1.0,
        'shared' => false,
        'size' => 4609,
        'source' => 'source/55b7a6729841fa24f100036a',
        'source_status' => true,
        'status' => {   'code' => 5,
                       'elapsed' => 302,
                       'message' => 'The test has been created',
                       'progress' => 1.0},
        'subscription' => true,
        'tags' => [],
        'statistical_tests' => {   'ad_sample_size' => 1024,
                      'fields' => {   '000000' => {   'column_number' => 0,
                                                    'datatype' => 'double',
                                                    'idx' => 0,
                                                    'name' => 'sepal length',
                                                    'optype' => 'numeric',
                                                    'order' => 0,
                                                    'preferred' => true,
                                                    'summary' => {   'bins' => [   [   4.3,
                                                                                     1],
                                                                                 [   4.425,
                                                                                     4],
    ...
                                                                                 [   7.9,
                                                                                     1]],
                                                                    'kurtosis' => -0.57357,
                                                                    'maximum' => 7.9,
                                                                    'mean' => 5.84333,
                                                                    'median' => 5.8,
                                                                    'minimum' => 4.3,
                                                                    'missing_count' => 0,
                                                                    'population' => 150,
                                                                    'skewness' => 0.31175,
                                                                    'splits' => [   4.51526,
                                                                                   4.67252,
                                                                                   4.81113,
                                                                                   4.89582,
    ...
                                                                                   7.20423,
                                                                                   7.64746],
                                                                    'standard_deviation' => 0.82807,
                                                                    'sum' => 876.5,
                                                                    'sum_squares' => 5223.85,
                                                                    'variance' => 0.68569}},
    ...
                                     '000004' => {   'column_number' => 4,
                                                    'datatype' => 'string',
                                                    'idx' => 4,
                                                    'name' => 'species',
                                                    'optype' => 'categorical',
                                                    'order' => 4,
                                                    'preferred' => true,
                                                    'summary' => {   'categories' => [   [   'Iris-setosa',
                                                                                           50],
                                                                                       [   'Iris-versicolor',
                                                                                           50],
                                                                                       [   'Iris-virginica',
                                                                                           50]],
                                                                    'missing_count' => 0},
                                                    'term_analysis' => {   'enabled' => true}}},
                      'fraud' => [   {   'name' => 'benford',
                                        'result' => {   '000000' => {   'chi_square' => {   'chi_square_value' => 506.39302,
                                                                                         'p_value' => 0,
                                                                                         'significant' => [   true,
                                                                                                             true,
                                                                                                             true]},
                                                                      'cho_gaines' => {   'd_statistic' => 7.124311073683573,
                                                                                         'significant' => [   true,
                                                                                                             true,
                                                                                                             true]},
                                                                      'distribution' => [   0,
                                                                                           0,
                                                                                           0,
                                                                                           22,
                                                                                           61,
                                                                                           54,
                                                                                           13,
                                                                                           0,
                                                                                           0],
                                                                      'negatives' => 0,
                                                                      'zeros' => 0},
                                                       '000001' => {   'chi_square' => {   'chi_square_value' => 396.76556,
                                                                                         'p_value' => 0,
                                                                                         'significant' => [   true,
                                                                                                             true,
                                                                                                             true]},
                                                                      'cho_gaines' => {   'd_statistic' => 7.503503138331123,
                                                                                         'significant' => [   true,
                                                                                                             true,
                                                                                                             true]},
                                                                      'distribution' => [   0,
                                                                                           57,
                                                                                           89,
                                                                                           4,
                                                                                           0,
                                                                                           0,
                                                                                           0,
                                                                                           0,
                                                                                           0],
                                                                      'negatives' => 0,
                                                                      'zeros' => 0},
                                                       '000002' => {   'chi_square' => {   'chi_square_value' => 154.20728,
                                                                                         'p_value' => 0,
                                                                                         'significant' => [   true,
                                                                                                             true,
                                                                                                             true]},
                                                                      'cho_gaines' => {   'd_statistic' => 3.9229974017266054,
                                                                                         'significant' => [   true,
                                                                                                             true,
                                                                                                             true]},
                                                                      'distribution' => [   50,
                                                                                           0,
                                                                                           11,
                                                                                           43,
                                                                                           35,
                                                                                           11,
                                                                                           0,
                                                                                           0,
                                                                                           0],
                                                                      'negatives' => 0,
                                                                      'zeros' => 0},
                                                       '000003' => {   'chi_square' => {   'chi_square_value' => 111.4438,
                                                                                         'p_value' => 0,
                                                                                         'significant' => [   true,
                                                                                                             true,
                                                                                                             true]},
                                                                      'cho_gaines' => {   'd_statistic' => 4.103257341299901,
                                                                                         'significant' => [   true,
                                                                                                             true,
                                                                                                             true]},
                                                                      'distribution' => [   76,
                                                                                           58,
                                                                                           7,
                                                                                           7,
                                                                                           1,
                                                                                           1,
                                                                                           0,
                                                                                           0,
                                                                                           0],
                                                                      'negatives' => 0,
                                                                      'zeros' => 0}}}],
                      'normality' => [   {   'name' => 'anderson_darling',
                                            'result' => {   '000000' => {   'p_value' => 0.02252,
                                                                          'significant' => [   false,
                                                                                              true,
                                                                                              true]},
                                                           '000001' => {   'p_value' => 0.02023,
                                                                          'significant' => [   false,
                                                                                              true,
                                                                                              true]},
                                                           '000002' => {   'p_value' => 0,
                                                                          'significant' => [   true,
                                                                                              true,
                                                                                              true]},
                                                           '000003' => {   'p_value' => 0,
                                                                          'significant' => [   true,
                                                                                              true,
                                                                                              true]}}},
                                        {   'name' => 'jarque_bera',
                                            'result' => {   '000000' => {   'p_value' => 0.10615,
                                                                          'significant' => [   false,
                                                                                              false,
                                                                                              false]},
                                                           '000001' => {   'p_value' => 0.25957,
                                                                          'significant' => [   false,
                                                                                              false,
                                                                                              false]},
                                                           '000002' => {   'p_value' => 0.0009,
                                                                          'significant' => [   true,
                                                                                              true,
                                                                                              true]},
                                                           '000003' => {   'p_value' => 0.00332,
                                                                          'significant' => [   true,
                                                                                              true,
                                                                                              true]}}},
                                        {   'name' => 'z_score',
                                            'result' => {   '000000' => {   'expected_max_z' => 2.71305,
                                                                          'max_z' => 2.48369},
                                                           '000001' => {   'expected_max_z' => 2.71305,
                                                                          'max_z' => 3.08044},
                                                           '000002' => {   'expected_max_z' => 2.71305,
                                                                          'max_z' => 1.77987},
                                                           '000003' => {   'expected_max_z' => 2.71305,
                                                                          'max_z' => 1.70638}}}],
                      'outliers' => [   {   'name' => 'grubbs',
                                           'result' => {   '000000' => {   'p_value' => 1,
                                                                         'significant' => [   false,
                                                                                             false,
                                                                                             false]},
                                                          '000001' => {   'p_value' => 0.26555,
                                                                         'significant' => [   false,
                                                                                             false,
                                                                                             false]},
                                                          '000002' => {   'p_value' => 1,
                                                                         'significant' => [   false,
                                                                                             false,
                                                                                             false]},
                                                          '000003' => {   'p_value' => 1,
                                                                         'significant' => [   false,
                                                                                             false,
                                                                                             false]}}}],
                      'significance_levels' => [0.01, 0.05, 0.1]},
        'updated' => '2015-07-28T18:17:11.829000',
        'white_box' => false}

Note that the output in the snippet above has been abbreviated. As you see, the
``statistical_tests`` attribute contains the ``fraud`, ``normality``
and ``outliers``
sections where the information for each field's distribution is stored.

Logistic Regressions
--------------------

A logistic regression is a supervised machine learning method for
solving classification problems. Each of the classes in the field
you want to predict, the objective field, is assigned a probability depending
on the values of the input fields. The probability is computed
as the value of a logistic function,
whose argument is a linear combination of the predictors' values.
You can create a logistic regression selecting which fields from your
dataset you want to use as input fields (or predictors) and which
categorical field you want to predict, the objective field. Then the
created logistic regression is defined by the set of coefficients in the
linear combination of the values. Categorical
and text fields need some prior work to be modelled using this method. They
are expanded as a set of new fields, one per category or term (respectively)
where the number of occurrences of the category or term is store. Thus,
the linear combination is made on the frequency of the categories or terms.

The JSON structure for a logistic regression is:

.. code-block:: ruby

     api.pprint(logistic_regression['object'])
     {  'balance_objective' =>  false,
        'category' =>  0,
        'code' =>  200,
        'columns' =>  5,
        'created' =>  '2015-10-09T16:11:08.444000',
        'credits' =>  0.017581939697265625,
        'credits_per_prediction' =>  0.0,
        'dataset' =>  'dataset/561304f537203f4c930001ca',
        'dataset_field_types' =>  {   'categorical' =>  1,
                                    'datetime' =>  0,
                                    'effective_fields' =>  5,
                                    'numeric' =>  4,
                                    'preferred' =>  5,
                                    'text' =>  0,
                                    'total' =>  5},
        'dataset_status' =>  true,
        'description' =>  '',
        'excluded_fields' =>  [],
        'fields_meta' =>  {   'count' =>  5,
                            'limit' =>  1000,
                            'offset' =>  0,
                            'query_total' =>  5,
                            'total' =>  5},
        'input_fields' =>  ['000000', '000001', '000002', '000003'],
        'locale' =>  'en_US',
        'logistic_regression' =>  {   'bias' =>  1,
                                    'c' =>  1,
                                    'coefficients' =>  [   [   'Iris-virginica',
                                                             [   -1.7074433493289376,
                                                                 -1.533662474502423,
                                                                 2.47026986670851,
                                                                 2.5567582221085563,
                                                                 -1.2158200612711925]],
                                                         [   'Iris-setosa',
                                                             [   0.41021712519841674,
                                                                 1.464162165246765,
                                                                 -2.26003266131107,
                                                                 -1.0210350909174153,
                                                                 0.26421852991732514]],
                                                         [   'Iris-versicolor',
                                                             [   0.42702327817072505,
                                                                 -1.611817241669904,
                                                                 0.5763832839459982,
                                                                 -1.4069842681625884,
                                                                 1.0946877732663143]]],
                                    'eps' =>  1e-05,
                                    'fields' =>  {   '000000' =>  {   'column_number' =>  0,
                                                                  'datatype' =>  'double',
                                                                  'name' =>  'sepal length',
                                                                  'optype' =>  'numeric', 
                                                                  'order' =>  0,
                                                                  'preferred' =>  true,
                                                                  'summary' =>  {   'bins' =>  [   [   4.3,
                                                                                                   1],
                                                                                               [   4.425,
                                                                                                   4],
                                                                                               [   4.6,
                                                                                                   4],
    ...
                                                                                               [   7.9,
                                                                                                   1]],
                                                                                  'kurtosis' =>  -0.57357,
                                                                                  'maximum' =>  7.9,
                                                                                  'mean' =>  5.84333,
                                                                                  'median' =>  5.8,
                                                                                  'minimum' =>  4.3,
                                                                                  'missing_count' =>  0,
                                                                                  'population' =>  150,
                                                                                  'skewness' =>  0.31175,
                                                                                  'splits' =>  [   4.51526,
                                                                                                 4.67252,
                                                                                                 4.81113,
    ...
                                                                                                 6.92597,
                                                                                                 7.20423,
                                                                                                 7.64746],
                                                                                  'standard_deviation' =>  0.82807,
                                                                                  'sum' =>  876.5,
                                                                                  'sum_squares' =>  5223.85,
                                                                                  'variance' =>  0.68569}},
                                                   '000001' =>  {   'column_number' =>  1,
                                                                  'datatype' =>  'double',
                                                                  'name' =>  'sepal width',
                                                                  'optype' =>  'numeric',
                                                                  'order' =>  1,
                                                                  'preferred' =>  true,
                                                                  'summary' =>  {   'counts' =>  [   [   2,
                                                                                                     1],
                                                                                                 [   2.2,
                                                                                                     3],
    ...
                                                                                                 [   4.2,
                                                                                                     1],
                                                                                                 [   4.4,
                                                                                                     1]],
                                                                                  'kurtosis' =>  0.18098,
                                                                                  'maximum' =>  4.4,
                                                                                  'mean' =>  3.05733,
                                                                                  'median' =>  3,
                                                                                  'minimum' =>  2,
                                                                                  'missing_count' =>  0,
                                                                                  'population' =>  150,
                                                                                  'skewness' =>  0.31577,
                                                                                  'standard_deviation' =>  0.43587,
                                                                                  'sum' =>  458.6,
                                                                                  'sum_squares' =>  1430.4,
                                                                                  'variance' =>  0.18998}},
                                                   '000002' =>  {   'column_number' =>  2,
                                                                  'datatype' =>  'double',
                                                                  'name' =>  'petal length',
                                                                  'optype' =>  'numeric',
                                                                  'order' =>  2,
                                                                  'preferred' =>  true,
                                                                  'summary' =>  {   'bins' =>  [   [   1,
                                                                                                   1],
                                                                                               [   1.16667,
                                                                                                   3],
    ...
                                                                                               [   6.6,
                                                                                                   1],
                                                                                               [   6.7,
                                                                                                   2],
                                                                                               [   6.9,
                                                                                                   1]],
                                                                                  'kurtosis' =>  -1.39554,
                                                                                  'maximum' =>  6.9,
                                                                                  'mean' =>  3.758,
                                                                                  'median' =>  4.35,
                                                                                  'minimum' =>  1,
                                                                                  'missing_count' =>  0,
                                                                                  'population' =>  150,
                                                                                  'skewness' =>  -0.27213,
                                                                                  'splits' =>  [   1.25138,
                                                                                                 1.32426,
                                                                                                 1.37171,
    ...
                                                                                                 6.02913,
                                                                                                 6.38125],
                                                                                  'standard_deviation' =>  1.7653,
                                                                                  'sum' =>  563.7,
                                                                                  'sum_squares' =>  2582.71,
                                                                                  'variance' =>  3.11628}},
                                                   '000003' =>  {   'column_number' =>  3,
                                                                  'datatype' =>  'double',
                                                                  'name' =>  'petal width',
                                                                  'optype' =>  'numeric',
                                                                  'order' =>  3,
                                                                  'preferred' =>  true,
                                                                  'summary' =>  {   'counts' =>  [   [   0.1,
                                                                                                     5],
                                                                                                 [   0.2,
                                                                                                     29],
    ...
                                                                                                 [   2.4,
                                                                                                     3],
                                                                                                 [   2.5,
                                                                                                     3]],
                                                                                  'kurtosis' =>  -1.33607,
                                                                                  'maximum' =>  2.5,
                                                                                  'mean' =>  1.19933,
                                                                                  'median' =>  1.3,
                                                                                  'minimum' =>  0.1,
                                                                                  'missing_count' =>  0,
                                                                                  'population' =>  150,
                                                                                  'skewness' =>  -0.10193,
                                                                                  'standard_deviation' =>  0.76224,
                                                                                  'sum' =>  179.9,
                                                                                  'sum_squares' =>  302.33,
                                                                                  'variance' =>  0.58101}},
                                                   '000004' =>  {   'column_number' =>  4,
                                                                  'datatype' =>  'string',
                                                                  'name' =>  'species',
                                                                  'optype' =>  'categorical',
                                                                  'order' =>  4,
                                                                  'preferred' =>  true,
                                                                  'summary' =>  {   'categories' =>  [   [   'Iris-setosa',
                                                                                                         50],
                                                                                                     [   'Iris-versicolor',
                                                                                                         50],
                                                                                                     [   'Iris-virginica',
                                                                                                         50]],
                                                                                  'missing_count' =>  0},
                                                                  'term_analysis' =>  {   'enabled' =>  true}}},
                                    'normalize' =>  false,
                                    'regularization' =>  'l2'},
        'max_columns' =>  5,
        'max_rows' =>  150,
        'name' =>  u"iris' dataset's logistic regression",
        'number_of_batchpredictions' =>  0,
        'number_of_evaluations' =>  0,
        'number_of_predictions' =>  1,
        'objective_field' =>  '000004',
        'objective_field_name' =>  'species',
        'objective_field_type' =>  'categorical',
        'objective_fields' =>  ['000004'],
        'out_of_bag' =>  false,
        'private' =>  true,
        'project' =>  'project/561304c137203f4c9300016c',
        'range' =>  [1, 150],
        'replacement' =>  false,
        'resource' =>  'logisticregression/5617e71c37203f506a000001',
        'rows' =>  150,
        'sample_rate' =>  1.0,
        'shared' =>  false,
        'size' =>  4609,
        'source' =>  'source/561304f437203f4c930001c3',
        'source_status' =>  true,
        'status' =>  {   'code' =>  5,
                       'elapsed' =>  86,
                       'message' =>  'The logistic regression has been created',
                       'progress' =>  1.0},
        'subscription' =>  false,
        'tags' =>  ['species'],
        'updated' =>  '2015-10-09T16:14:02.336000',
        'white_box' =>  false}

Note that the output in the snippet above has been abbreviated. As you see,
the ``logistic_regression`` attribute stores the coefficients used in the
logistic function as well as the configuration parameters described in
the `developers section <https://bigml.com/developers/logisticregressions>`_ .


Associations
------------

Association Discovery is a popular method to find out relations among values
in high-dimensional datasets.

A common case where association discovery is often used is
market basket analysis. This analysis seeks for customer shopping
patterns across large transactional
datasets. For instance, do customers who buy hamburgers and ketchup also
consume bread?

Businesses use those insights to make decisions on promotions and product
placements.
Association Discovery can also be used for other purposes such as early
incident detection, web usage analysis, or software intrusion detection.

In BigML, the Association resource object can be built from any dataset, and
its results are a list of association rules between the items in the dataset.
In the example case, the corresponding
association rule would have hamburguers and ketchup as the items at the
left hand side of the association rule and bread would be the item at the
right hand side. Both sides in this association rule are related,
in the sense that observing
the items in the left hand side implies observing the items in the right hand
side. There are some metrics to ponder the quality of these association rules:

- Support: the proportion of instances which contain an itemset.

For an association rule, it means the number of instances in the dataset which
contain the rule's antecedent and rule's consequent together
over the total number of instances (N) in the dataset.

It gives a measure of the importance of the rule. Association rules have
to satisfy a minimum support constraint (i.e., min_support).

- Coverage: the support of the antedecent of an association rule.
It measures how often a rule can be applied.

- Confidence or (strength): The probability of seeing the rule's consequent
under the condition that the instances also contain the rule's antecedent.
Confidence is computed using the support of the association rule over the
coverage. That is, the percentage of instances which contain the consequent
and antecedent together over the number of instances which only contain
the antecedent.

Confidence is directed and gives different values for the association
rules Antecedent → Consequent and Consequent → Antecedent. Association
rules also need to satisfy a minimum confidence constraint
(i.e., min_confidence).

- Leverage: the difference of the support of the association
rule (i.e., the antecedent and consequent appearing together) and what would
be expected if antecedent and consequent where statistically independent.
This is a value between -1 and 1. A positive value suggests a positive
relationship and a negative value suggests a negative relationship.
0 indicates independence.

Lift: how many times more often antecedent and consequent occur together
than expected if they where statistically independent.
A value of 1 suggests that there is no relationship between the antecedent
and the consequent. Higher values suggest stronger positive relationships.
Lower values suggest stronger negative relationships (the presence of the
antecedent reduces the likelihood of the consequent)

As to the items used in association rules, each type of field is parsed to
extract items for the rules as follows:

- Categorical: each different value (class) will be considered a separate item.
- Text: each unique term will be considered a separate item.
- Items: each different item in the items summary will be considered.
- Numeric: Values will be converted into categorical by making a
segmentation of the values.
For example, a numeric field with values ranging from 0 to 600 split
into 3 segments:
segment 1 → [0, 200), segment 2 → [200, 400), segment 3 → [400, 600].
You can refine the behavior of the transformation using
`discretization <https://bigml.com/developers/associations#ad_create_discretization>`_
and `field_discretizations <https://bigml.com/developers/associations#ad_create_field_discretizations>`_.

The JSON structure for an association resource is:

.. code-block:: ruby

    api.pprint(association['object'])
    {
        "associations" => {
            "complement" => false,
            "discretization" => {
                "pretty" => true,
                "size" => 5,
                "trim" => 0,
                "type" => "width"
            },
            "items" => [
                {
                    "complement" => false,
                    "count" => 32,
                    "field_id" => "000000",
                    "name" => "Segment 1",
                    "bin_end" => 5,
                    "bin_start" => null
                },
                {
                    "complement" => false,
                    "count" => 49,
                    "field_id" => "000000",
                    "name" => "Segment 3",
                    "bin_end" => 7,
                    "bin_start" => 6
                },
                {
                    "complement" => false,
                    "count" => 12,
                    "field_id" => "000000",
                    "name" => "Segment 4",
                    "bin_end" => null,
                    "bin_start" => 7
                },
                {
                    "complement" => false,
                    "count" => 19,
                    "field_id" => "000001",
                    "name" => "Segment 1",
                    "bin_end" => 2.5,
                    "bin_start" => null
                },
                ...
                {
                    "complement" => false,
                    "count" => 50,
                    "field_id" => "000004",
                    "name" => "Iris-versicolor"
                },
               {
                    "complement" => false,
                    "count" => 50,
                    "field_id" => "000004",
                    "name" => "Iris-virginica"
                }
            ],
            "max_k" =>  100,
            "min_confidence" => 0,
            "min_leverage" => 0,
            "min_lift" => 1,
            "min_support" => 0,
            "rules" => [
                {
                    "confidence" => 1,
                    "id" => "000000",
                    "leverage" => 0.22222,
                    "lhs" => [
                        13
                    ],
                    "lhs_cover" => [
                        0.33333,
                        50
                    ],
                    "lift" => 3,
                    "p_value" => 0.000000000,
                    "rhs" => [
                        6
                    ],
                    "rhs_cover" => [
                        0.33333,
                        50
                    ],
                    "support" => [
                        0.33333,
                        50
                    ]
                },
                {
                    "confidence" => 1,
                    "id" => "000001",
                    "leverage" => 0.22222,
                    "lhs" => [
                        6
                    ],
                    "lhs_cover" => [
                        0.33333,
                        50
                    ],
                    "lift" => 3,
                    "p_value" => 0.000000000,
                    "rhs" => [
                        13
                    ],
                    "rhs_cover" => [
                        0.33333,
                        50
                    ],
                    "support" => [
                        0.33333,
                        50
                    ]
                },
                ...
                {
                    "confidence" => 0.26,
                    "id" => "000029",
                    "leverage" => 0.05111,
                    "lhs" => [
                        13
                    ],
                    "lhs_cover" => [
                        0.33333,
                        50
                    ],
                    "lift" => 2.4375,
                    "p_value" => 0.0000454342,
                    "rhs" => [
                        5
                    ],
                    "rhs_cover" => [
                        0.10667,
                        16
                    ],
                    "support" => [
                        0.08667,
                        13
                    ]
                },
                {
                    "confidence" => 0.18,
                    "id" => "00002a",
                    "leverage" => 0.04,
                    "lhs" => [
                        15
                    ],
                    "lhs_cover" => [
                        0.33333,
                        50
                    ],
                    "lift" => 3,
                    "p_value" => 0.0000302052,
                    "rhs" => [
                        9
                    ],
                    "rhs_cover" => [
                        0.06,
                        9
                    ],
                    "support" => [
                        0.06,
                        9
                    ]
                },
                {
                    "confidence" => 1,
                    "id" => "00002b",
                    "leverage" => 0.04,
                    "lhs" => [
                        9
                    ],
                    "lhs_cover" => [
                        0.06,
                        9
                    ],
                    "lift" => 3,
                    "p_value" => 0.0000302052,
                    "rhs" => [
                        15
                    ],
                    "rhs_cover" => [
                        0.33333,
                        50
                    ],
                    "support" => [
                        0.06,
                        9
                    ]
                }
            ],
            "rules_summary" => {
                "confidence" => {
                    "counts" => [
                        [
                            0.18,
                            1
                        ],
                        [
                            0.24,
                            1
                        ],
                        [
                            0.26,
                            2
                        ],
                        ...
                        [
                            0.97959,
                            1
                        ],
                        [
                            1,
                            9
                        ]
                    ],
                    "maximum" => 1,
                    "mean" => 0.70986,
                    "median" => 0.72864,
                    "minimum" => 0.18,
                    "population" => 44,
                    "standard_deviation" => 0.24324,
                    "sum" => 31.23367,
                    "sum_squares" => 24.71548,
                    "variance" => 0.05916
                },
                "k" => 44,
                "leverage" => {
                    "counts" => [
                        [
                            0.04,
                            2
                        ],
                        [
                            0.05111,
                            4
                        ],
                        [
                            0.05316,
                            2
                        ],
                        ...
                        [
                            0.22222,
                            2
                        ]
                    ],
                    "maximum" => 0.22222,
                    "mean" => 0.10603,
                    "median" => 0.10156,
                    "minimum" => 0.04,
                    "population" => 44,
                    "standard_deviation" => 0.0536,
                    "sum" => 4.6651,
                    "sum_squares" => 0.61815,
                    "variance" => 0.00287
                },
                "lhs_cover" => {
                    "counts" => [
                        [
                            0.06,
                            2
                        ],
                        [
                            0.08,
                            2
                        ],
                        [
                            0.10667,
                            4
                        ],
                        [
                            0.12667,
                            1
                        ],
                        ...
                        [
                            0.5,
                            4
                        ]
                    ],
                    "maximum" => 0.5,
                    "mean" => 0.29894,
                    "median" => 0.33213,
                    "minimum" => 0.06,
                    "population" => 44,
                    "standard_deviation" => 0.13386,
                    "sum" => 13.15331,
                    "sum_squares" => 4.70252,
                    "variance" => 0.01792
                },
                "lift" => {
                    "counts" => [
                        [
                            1.40625,
                            2
                        ],
                        [
                            1.5067,
                            2
                        ],
                        ...
                        [
                            2.63158,
                            4
                        ],
                        [
                            3,
                            10
                        ],
                        [
                            4.93421,
                            2
                        ],
                        [
                            12.5,
                            2
                        ]
                    ],
                    "maximum" => 12.5,
                    "mean" => 2.91963,
                    "median" => 2.58068,
                    "minimum" => 1.40625,
                    "population" => 44,
                    "standard_deviation" => 2.24641,
                    "sum" => 128.46352,
                    "sum_squares" => 592.05855,
                    "variance" => 5.04635
                },
                "p_value" => {
                    "counts" => [
                        [
                            0.000000000,
                            2
                        ],
                        [
                            0.000000000,
                            4
                        ],
                        [
                            0.000000000,
                            2
                        ],
                        ...
                        [
                            0.0000910873,
                            2
                        ]
                    ],
                    "maximum" => 0.0000910873,
                    "mean" => 0.0000106114,
                    "median" => 0.00000000,
                    "minimum" => 0.000000000,
                    "population" => 44,
                    "standard_deviation" => 0.0000227364,
                    "sum" => 0.000466903,
                    "sum_squares" => 0.0000000,
                    "variance" => 0.000000001
                },
                "rhs_cover" => {
                    "counts" => [
                        [
                            0.06,
                            2
                        ],
                        [
                            0.08,
                            2
                        ],
                        ...
                        [
                            0.42667,
                            2
                        ],
                        [
                            0.46667,
                            3
                        ],
                        [
                            0.5,
                            4
                        ]
                    ],
                    "maximum" => 0.5,
                    "mean" => 0.29894,
                    "median" => 0.33213,
                    "minimum" => 0.06,
                    "population" => 44,
                    "standard_deviation" => 0.13386,
                    "sum" => 13.15331,
                    "sum_squares" => 4.70252,
                    "variance" => 0.01792
                },
                "support" => {
                    "counts" => [
                        [
                            0.06,
                            4
                        ],
                        [
                            0.06667,
                            2
                        ],
                        [
                            0.08,
                            2
                        ],
                        [
                            0.08667,
                            4
                        ],
                        [
                            0.10667,
                            4
                        ],
                        [
                            0.15333,
                            2
                        ],
                        [
                            0.18667,
                            4
                        ],
                        [
                            0.19333,
                            2
                        ],
                        [
                            0.20667,
                            2
                        ],
                        [
                            0.27333,
                            2
                        ],
                        [
                            0.28667,
                            2
                        ],
                        [
                            0.3,
                            4
                        ],
                        [
                            0.32,
                            2
                        ],
                        [
                            0.33333,
                            6
                        ],
                        [
                            0.37333,
                            2
                        ]
                    ],
                    "maximum" => 0.37333,
                    "mean" => 0.20152,
                    "median" => 0.19057,
                    "minimum" => 0.06,
                    "population" => 44,
                    "standard_deviation" => 0.10734,
                    "sum" => 8.86668,
                    "sum_squares" => 2.28221,
                    "variance" => 0.01152
                }
            },
            "search_strategy" => "leverage",
            "significance_level" => 0.05
        },
        "category" => 0,
        "clones" => 0,
        "code" => 200,
        "columns" => 5,
        "created" => "2015-11-05T08:06:08.184000",
        "credits" => 0.017581939697265625,
        "dataset" => "dataset/562fae3f4e1727141d00004e",
        "dataset_status" => true,
        "dataset_type" => 0,
        "description" => "",
        "excluded_fields" => [ ],
        "fields_meta" => {
            "count" => 5,
            "limit" => 1000,
            "offset" => 0,
            "query_total" => 5,
            "total" => 5
        },
        "input_fields" => [
            "000000",
            "000001",
            "000002",
            "000003",
            "000004"
        ],
        "locale" => "en_US",
        "max_columns" => 5,
        "max_rows" => 150,
        "name" => "iris' dataset's association",
        "out_of_bag" => false,
        "price" => 0,
        "private" => true,
        "project" => null,
        "range" => [
            1,
            150
        ],
        "replacement" => false,
        "resource" => "association/5621b70910cb86ae4c000000",
        "rows" => 150,
        "sample_rate" => 1,
        "shared" => false,
        "size" => 4609,
        "source" => "source/562fae3a4e1727141d000048",
        "source_status" => true,
        "status" => {
            "code" => 5,
            "elapsed" => 1072,
            "message" => "The association has been created",
            "progress" => 1
        },
        "subscription" => false,
        "tags" => [ ],
        "updated" => "2015-11-05T08:06:20.403000",
        "white_box" => false
    }

Note that the output in the snippet above has been abbreviated. As you see,
the ``associations`` attribute stores items, rules and metrics extracted
from the datasets as well as the configuration parameters described in
the `developers section <https://bigml.com/developers/associations>`_ .

Whizzml Resources
-----------------

Whizzml is a Domain Specific Language that allows the definition and
execution of ML-centric workflows. Its objective is allowing BigML
users to define their own composite tasks, using as building blocks
the basic resources provided by BigML itself. Using Whizzml they can be
glued together using a higher order, functional, Turing-complete language.
The Whizzml code can be stored and executed in BigML using three kinds of
resources: ``Scripts``, ``Libraries`` and ``Executions``.

Whizzml ``Scripts`` can be executed in BigML's servers, that is,
in a controlled, fully-scalable environment which takes care of their
parallelization and fail-safe operation. Each execution uses an ``Execution``
resource to store the arguments and results of the process. Whizzml
``Libraries`` store generic code to be shared of reused in other Whizzml
``Scripts``.

Scripts
-------

In BigML a ``Script`` resource stores Whizzml source code, and the results of
its compilation. Once a Whizzml script is created, it's automatically compiled;
if compilation succeeds, the script can be run, that is,
used as the input for a Whizzml execution resource.

An example of a ``script`` that would create a ``source`` in BigML using the
contents of a remote file is:

.. code-block:: ruby

    require 'bigml'
    api = BigML.Api.new

    # creating a script directly from the source code. This script creates
    # a source uploading data from an s3 repo. You could also create a
    # a script by using as first argument the path to a .whizzml file which
    # contains your source code.

    script = api.create_script("(create-source {\"remote\" \"s3://bigml-public/csv/iris.csv\"})")
    api.ok(script) # waiting for the script compilation to finish
    api.pprint(script['object'])
   
    {"approval_status"=>0,
     "category"=>0,
     "code"=>201,
     "created"=>"2016-06-14T22:16:23.733963",
     "description"=>"",
     "imports"=>[],
     "inputs"=>nil,
     "line_count"=>1,
     "locale"=>"en-US",
     "name"=>"Script",
     "number_of_executions"=>0,
     "outputs"=>nil,
     "price"=>0.0,
     "private"=>true,
     "project"=>nil,
     "provider"=>nil,
     "resource"=>"script/576082377e0a8d0b96004ad3",
     "shared"=>false,
     "size"=>59,
     "source_code"=>
     "(create-source {\"remote\" \"s3://bigml-public/csv/iris.csv\"})",
     "status"=>
      {"code"=>1,
       "message"=>"The script is being processed and will be created soon"},
       "subscription"=>true,
       "tags"=>[],
       "updated"=>"2016-06-14T22:16:23.733982",
       "white_box"=>false}

A ``script`` allows to define some variables as ``inputs``. In the previous
example, no input has been defined, but we could modify our code to
allow the user to set the remote file name as input:

.. code-block:: ruby 

    require 'bigml'
    api = BigML.Api.new
    script = api.create_script("(create-source {\"remote\" my_remote_data})",
                               {"inputs" => [{"name" => "my_remote_data",
                                            "type" => "string",
                                            "default" => "s3://bigml-public/csv/iris.csv",
                                            "description" => "Location of the remote data"}]})

The ``script`` can also use a ``library`` resource (please, see the
``Libraries`` section below for more details) by including its id in the
``imports`` attribute. Other attributes can be checked at the
`API Developers documentation for Scripts<https://bigml.com/developers/scripts#ws_script_arguments>`_.


Executions
----------

To execute in BigML a compiled Whizzml ``script`` you need to create an
``execution`` resource. It's also possible to execute a pipeline of
many compiled scripts in one request.

Each ``execution`` is run under its associated user credentials and its
particular environment constaints. As ``scripts`` can be shared,
you can execute the same ``script``
several times under different
usernames by creating different ``executions``.

As an example of ``execution`` resource, let's create one for the script
in the previous section:

.. code-block:: ruby

    require 'bigml'
    api = BigML.Api.new()
    execution = api.create_execution('script/573c9e2db85eee23cd000489')
    api.ok(execution) # waiting for the execution to finish
    api.pprint(execution['object'])
    {   'category' => 0,
        'code' => 200,
        'created' => '2016-05-18T16:58:01.613000',
        'creation_defaults' => {   },
        'description' => '',
        'execution' => {   'output_resources' => [   {   'code'=> 1,
                                                       'id'=> 'source/573c9f19b85eee23c600024a',
                                                       'last_update' => 1463590681854,
                                                       'progress' => 0.0,
                                                       'state' => 'queued',
                                                       'task' => 'Queuing job',
                                                       'variable' => ''}],
                          'outputs' => [],
                          'result' => 'source/573c9f19b85eee23c600024a',
                          'results' => ['source/573c9f19b85eee23c600024a'],
                          'sources' => [[   'script/573c9e2db85eee23cd000489',
                                              '']],
                          'steps' => 16},
        'inputs' => nil,
        'locale' => 'en-US',
        'name' => "Script's Execution",
        'project' => nil,
        'resource' => 'execution/573c9f19b85eee23bd000125',
        'script' => 'script/573c9e2db85eee23cd000489',
        'script_status' => true,
        'shared' => false,
        'status' => {   'code' => 5,
                       'elapsed' => 249,
                       'elapsed_times' => {   'in-progress' => 247,
                                             'queued' => 62,
                                             'started' => 2},
                       'message' => 'The execution has been created',
                       'progress' => 1.0},
        'subscription' => true,
        'tags' => [],
        'updated' => '2016-05-18T16:58:02.035000'}


An ``execution`` receives inputs, the ones defined in the ``script`` chosen
to be executed, and generates a result. It can also generate outputs.
As you can see, the execution resource contains information about the result
of the execution, the resources that have been generated while executing and
users can define some variables in the code to be exported as outputs. Please
refer to the
`Developers documentation for Executions<https://bigml.com/developers/executions#we_execution_arguments>`_
for details on how to define execution outputs.

Libraries
---------

The ``library`` resource in BigML stores a special kind of compiled Whizzml
source code that only defines functions and constants. The ``library`` is
intended as an import for executable scripts.
Thus, a compiled library cannot be executed, just used as an
import in other ``libraries`` and ``scripts`` (which then have access
to all identifiers defined in the ``library``).

As an example, we build a ``library`` to store the definition of two functions:
``mu`` and ``g``. The first one adds one to the value set as argument and
the second one adds two variables and increments the result by one.

.. code-block:: ruby

    require 'bigml'
    api = BigML::Api.new

    library = api.create_library("(define (mu x) (+ x 1)) (define (g z y) (mu (+ y z)))")
    api.ok(library) 

    api.pprint(library['object'])

    {"approval_status"=>0,
     "category"=>0,
     "code"=>200,
     "created"=>"2016-06-15T10:02:26.001000",
     "description"=>"",
     "exports"=>
        [{"name"=>"mu", "signature"=>["x"]}, {"name"=>"g", "signature"=>["z", "y"]}],
     "imports"=>[],
     "line_count"=>1,
     "name"=>"Library",
     "price"=>0.0,
     "private"=>true,
     "project"=>nil,
     "provider"=>nil,
     "resource"=>"library/576127b2b42eb01edc009ffd",
     "shared"=>false,
     "size"=>53,
     "source_code"=>"(define (mu x) (+ x 1)) (define (g z y) (mu (+ y z)))",
     "status"=>
     {"code"=>5,
      "elapsed"=>2,
      "message"=>"The library has been created",
      "progress"=>1.0},
      "subscription"=>true,
      "tags"=>[],
      "updated"=>"2016-06-15T10:02:26.319000",
      "white_box"=>false}

Libraries can be imported in scripts. The ``imports`` attribute of a ``script``
can contain a list of ``library`` IDs whose defined functions
and constants will be ready to be used throughout the ``script``. Please,
refer to the `API Developers documentation for Libraries<https://bigml.com/developers/libraries#wl_library_arguments>`_
for more details.


Creating Resources
------------------

Newly-created resources are returned in a dictionary with the following
keys:

-  **code**: If the request is successful you will get a
   ``BigML::HTTP_CREATED`` (201) status code. In asynchronous file uploading
   ``api.create_source`` calls, it will contain ``BigML::HTTP_ACCEPTED`` (202)
   status code. Otherwise, it will be
   one of the standard HTTP error codes `detailed in the
   documentation <https://bigml.com/developers/status_codes>`_.
-  **resource**: The identifier of the new resource.
-  **location**: The location of the new resource.
-  **object**: The resource itself, as computed by BigML.
-  **error**: If an error occurs and the resource cannot be created, it
   will contain an additional code and a description of the error. In
   this case, **location**, and **resource** will be ``nil``.


Statuses
~~~~~~~~

Please, bear in mind that resource creation is almost always
asynchronous (**predictions** are the only exception). Therefore, when
you create a new source, a new dataset or a new model, even if you
receive an immediate response from the BigML servers, the full creation
of the resource can take from a few seconds to a few days, depending on
the size of the resource and BigML's load. A resource is not fully
created until its status is ``BigML::FINISHED``. See the
`documentation on status
codes <https://bigml.com/developers/status_codes>`_ for the listing of
potential states and their semantics. So depending on your application
you might need to import the following constants:

You can query the status of any resource with the ``status`` method:

.. code-block:: ruby

    api.status(source)
    api.status(dataset)
    api.status(model)
    api.status(prediction)
    api.status(evaluation)
    api.status(ensemble)
    api.status(batch_prediction)
    api.status(cluster)
    api.status(centroid)
    api.status(batch_centroid)
    api.status(anomaly)
    api.status(anomaly_score)
    api.status(batch_anomaly_score)
    api.status(sample)
    api.status(correlation)
    api.status(statistical_test)
    api.status(logistic_regression)
    api.status(association)
    api.status(association_set)
    api.status(script)
    api.status(execution)
    api.status(library)

Before invoking the creation of a new resource, the library checks that
the status of the resource that is passed as a parameter is
``FINISHED``. You can change how often the status will be checked with
the ``wait_time`` argument. By default, it is set to 3 seconds.

You can also use the ``check_resource`` function:

.. code-block:: ruby

    BigML::check_resource(resource, api.method("get_source"))

that will constantly query the API until the resource gets to a FINISHED or
FAULTY state, or can also be used with ``wait_time`` and ``retries``
arguments to control the pulling:

.. code-block:: ruby

    BigML::check_resource(resource, api.method("get_source"), '', 2, 20)

The ``wait_time`` value is used as seed to a wait
interval that grows exponentially with the number of retries up to the given
``retries`` limit.

Projects
~~~~~~~~

A special kind of resource is ``project``. Projects are repositories
for resources, intended to fulfill organizational purposes. Each project can
contain any other kind of resource, but the project that a certain resource
belongs to is determined by the one used in the ``source``
they are generated from. Thus, when a source is created
and assigned a certain ``project_id``, the rest of resources generated from
this source will remain in this project.

The REST calls to manage the ``project`` resemble the ones used to manage the
rest of resources. When you create a ``project``:

.. code-block:: ruby

    require 'bigml'
    api = BigML::Api.new

    project = api.create_project({'name' => 'my first project'})

the resulting resource is similar to the rest of resources, although shorter:

.. code-block:: ruby

    {'code' => 201,
     'resource' => u'project/54a1bd0958a27e3c4c0002f0',
     'location' => 'http://bigml.io/andromeda/project/54a1bd0958a27e3c4c0002f0',
     'object' => {u'category' => 0,
                'updated' => u'2014-12-29T20:43:53.060045',
                'resource' => u'project/54a1bd0958a27e3c4c0002f0',
                'name' => u'my first project',
                'created' => u'2014-12-29T20:43:53.060013',
                'tags' => [],
                'private' => true,
                'dev' => nil,
                'description' => u''},
     'error' => nil}

and you can use its project id to get, update or delete it:

.. code-block:: ruby

    project = api.get_project('project/54a1bd0958a27e3c4c0002f0')
    api.update_project(project['resource'],
                       {'description' => 'This is my first project'})

    api.delete_project(project['resource'])

**Important**: Deleting a non-empty project will also delete **all resources**
assigned to it, so please be extra-careful when using
the ``api.delete_project`` call.

Creating sources
~~~~~~~~~~~~~~~~

To create a source from a local data file, you can use the
``create_source`` method. The only required parameter is the path to the
data file (or file-like object). You can use a second optional parameter
to specify any of the
options for source creation described in the `BigML API
documentation <https://bigml.com/developers/sources>`_.

Here's a sample invocation:

.. code-block:: ruby 

    require 'bigml'
    api = BigML::Api.new

    source = api.create_source('./data/iris.csv',
        {'name' => 'my source', 'source_parser' => {'missing_tokens' => ['?']}})

or you may want to create a source from a file in a remote location:

.. code-block:: ruby 

    source = api.create_source('s3://bigml-public/csv/iris.csv',
        {'name' => 'my remote source', 'source_parser' => {'missing_tokens' => ['?']}})

You can retrieve the updated status at any time using the corresponding get
method. For example, to get the status of our source we would use:

.. code-block:: ruby

    api.status(source)


Creating datasets
~~~~~~~~~~~~~~~~~

Once you have created a source, you can create a dataset. The only
required argument to create a dataset is a source id. You can add all
the additional arguments accepted by BigML and documented in the
`Datasets section of the Developer's
documentation <https://bigml.com/developers/datasets>`_.

For example, to create a dataset named "my dataset" with the first 1024
bytes of a source, you can submit the following request:

.. code-block:: ruby

    dataset = api.create_dataset(source, {"name" => "my dataset", "size" => 1024})

Upon success, the dataset creation job will be queued for execution, and
you can follow its evolution using ``api.status(dataset)``.

As for the rest of resources, the create method will return an incomplete
object, that can be updated by issuing the corresponding
``api.get_dataset`` call until it reaches a ``FINISHED`` status.
Then you can export the dataset data to a CSV file using:

.. code-block:: ruby 

    api.download_dataset('dataset/526fc344035d071ea3031d75',
        filename='my_dir/my_dataset.csv')

You can also extract samples from an existing dataset and generate a new one
with them using the ``api.create_dataset`` method. The first argument should
be the origin dataset and the rest of arguments that set the range or the
sampling rate should be passed as a dictionary. For instance, to create a new
dataset extracting the 80% of instances from an existing one, you could use:

.. code-block:: ruby

    dataset = api.create_dataset(origin_dataset, {"sample_rate" => 0.8})

Similarly, if you want to split your source into training and test datasets,
you can set the `sample_rate` as before to create the training dataset and
use the `out_of_bag` option to assign the complementary subset of data to the
test dataset. If you set the `seed` argument to a value of your choice, you
will ensure a determinist sampling, so that each time you execute this call
you will get the same datasets as a result and they will be complementary:

.. code-block:: ruby

    origin_dataset = api.create_dataset(source)
    train_dataset = api.create_dataset(
        origin_dataset, {"name" => "Dataset Name | Training",
                         "sample_rate" => 0.8, "seed" => "my seed"})
    test_dataset = api.create_dataset(
        origin_dataset, {"name" => "Dataset Name | Test",
                         "sample_rate" => 0.8, "seed" => "my seed",
                         "out_of_bag" => True})

It is also possible to generate a dataset from a list of datasets
(multidataset):

.. code-block:: ruby

    dataset1 = api.create_dataset(source1)
    dataset2 = api.create_dataset(source2)
    multidataset = api.create_dataset([dataset1, dataset2])

Clusters can also be used to generate datasets containing the instances
grouped around each centroid. You will need the cluster id and the centroid id
to reference the dataset to be created. For instance,

.. code-block:: ruby

    cluster = api.create_cluster(dataset)
    cluster_dataset_1 = api.create_dataset(cluster,
                                           args={'centroid' => '000000'})

would generate a new dataset containing the subset of instances in the cluster
associated to the centroid id ``000000``.

Creating models
~~~~~~~~~~~~~~~

Once you have created a dataset you can create a model from it. If you don't
select one, the model will use the last field of the dataset as objective
field. The only required argument to create a model is a dataset id.
You can also
include in the request all the additional arguments accepted by BigML
and documented in the `Models section of the Developer's
documentation <https://bigml.com/developers/models>`_.

For example, to create a model only including the first two fields and
the first 10 instances in the dataset, you can use the following
invocation:

.. code-block:: ruby

    model = api.create_model(dataset, {
        "name" => "my model", "input_fields" => ["000000", "000001"], "range" => [1, 10]})

Again, the model is scheduled for creation, and you can retrieve its
status at any time by means of ``api.status(model)``.

Models can also be created from lists of datasets. Just use the list of ids
as the first argument in the api call

.. code-block:: ruby 

    model = api.create_model([dataset1, dataset2], {
        "name" => "my model", "input_fields" => ["000000", "000001"], "range" => [1, 10]})

And they can also be generated as the result of a clustering procedure. When
a cluster is created, a model that predicts if a certain instance belongs to
a concrete centroid can be built by providing the cluster and centroid ids:

.. code-block:: ruby

    model = api.create_model(cluster, {
        "name" => "model for centroid 000001", "centroid" => "000001"})

if no centroid id is provided, the first one appearing in the cluster is used.


Creating clusters
~~~~~~~~~~~~~~~~~

If your dataset has no fields showing the objective information to
predict for the training data, you can still build a cluster
that will group similar data around
some automatically chosen points (centroids). Again, the only required
argument to create a cluster is the dataset id. You can also
include in the request all the additional arguments accepted by BigML
and documented in the `Clusters section of the Developer's
documentation <https://bigml.com/developers/clusters>`_.

Let's create a cluster from a given dataset:

.. code-block:: ruby

    cluster = api.create_cluster(dataset, {"name" => "my cluster",
                                           "k" => 5})

that will create a cluster with 5 centroids.

Creating anomaly detectors
~~~~~~~~~~~~~~~~~~~~~~~~~~

If your problem is finding the anomalous data in your dataset, you can
build an anomaly detector, that will use iforest to single out the
anomalous records. Again, the only required
argument to create an anomaly detector is the dataset id. You can also
include in the request all the additional arguments accepted by BigML
and documented in the `Anomaly detectors section of the Developer's
documentation <https://bigml.com/developers/anomalies>`_.

Let's create an anomaly detector from a given dataset:

.. code-block:: ruby

    anomaly = api.create_anomaly(dataset, {"name" => "my anomaly"})

that will create an anomaly resource with a `top_anomalies` block of the
most anomalous points.

Creating associations
~~~~~~~~~~~~~~~~~~~~~

To find relations between the field values you can create an association
discovery resource. The only required argument to create an association
is a dataset id.
You can also
include in the request all the additional arguments accepted by BigML
and documented in the `Association section of the Developer's
documentation <https://bigml.com/developers/associations>`_.

For example, to create an association only including the first two fields and
the first 10 instances in the dataset, you can use the following
invocation:

.. code-block:: ruby

    model = api.create_association(dataset, {
        "name" => "my association", "input_fields" => ["000000", "000001"],
        "range" => [1, 10]})

Again, the association is scheduled for creation, and you can retrieve its
status at any time by means of ``api.status(association)``.

Associations can also be created from lists of datasets. Just use the
list of ids as the first argument in the api call

.. code-block:: bigml 

    model = api.create_association([dataset1, dataset2], {
        "name" => "my association", "input_fields" => ["000000", "000001"],
        "range" => [1, 10]})

Creating predictions
~~~~~~~~~~~~~~~~~~~~

You can now use the model resource identifier together with some input
parameters to ask for predictions, using the ``create_prediction``
method. You can also give the prediction a name:

.. code-block:: ruby

    prediction = api.create_prediction(model,
                                       {"sepal length" => 5,
                                       "sepal width" => 2.5},
                                       {"name" => "my prediction"})

To see the prediction you can use ``pprint``:

.. code-block:: ruby

    api.pprint(prediction)


Creating centroids
~~~~~~~~~~~~~~~~~~

To obtain the centroid associated to new input data, you
can now use the ``create_centroid`` method. Give the method a cluster
identifier and the input data to obtain the centroid.
You can also give the centroid predicition a name:

.. code-block:: ruby

    centroid = api.create_centroid(cluster,
                                   {"pregnancies" => 0,
                                    "plasma glucose" => 118,
                                    "blood pressure" => 84,
                                    "triceps skin thickness" => 47,
                                    "insulin" => 230,
                                    "bmi" => 45.8,
                                    "diabetes pedigree" => 0.551,
                                    "age" => 31,
                                    "diabetes" => "true"},
                                    {"name" => "my centroid"})


Creating anomaly scores
~~~~~~~~~~~~~~~~~~~~~~~

To obtain the anomaly score associated to new input data, you
can now use the ``create_anomaly_score`` method. Give the method an anomaly
detector identifier and the input data to obtain the score:

.. code-block:: ruby

    anomaly_score = api.create_anomaly_score(anomaly, {"src_bytes" => 350},
                                             args={"name" => "my score"})

Creating association sets
~~~~~~~~~~~~~~~~~~~~~~~~~

Using the association resource, you can obtain the consequent items associated
by its rules to your input data. These association sets can be obtained calling
the ``create_association_set`` method. The first argument is the association
ID or object and the next one is the input data.

.. code-block:: ruby 

    association_set = api.create_association_set(association, {"genres" => "Action$Adventure"}, 
                                                        args={"name" => "my association set"})

Creating evaluations
~~~~~~~~~~~~~~~~~~~~

Once you have created a model, you can measure its perfomance by running a
dataset of test data through it and comparing its predictions to the objective
field real values. Thus, the required arguments to create an evaluation are
model id and a dataset id. You can also
include in the request all the additional arguments accepted by BigML
and documented in the `Evaluations section of the Developer's
documentation <https://bigml.com/developers/evaluations>`_.

For instance, to evaluate a previously created model using an existing dataset
you can use the following call:

.. code-block:: ruby

    evaluation = api.create_evaluation(model, dataset, {
        "name" => "my model"})

Again, the evaluation is scheduled for creation and ``api.status(evaluation)``
will show its state.

Evaluations can also check the ensembles' performance. To evaluate an ensemble
you can do exactly what we just did for the model case, using the ensemble
object instead of the model as first argument:

.. code-block:: ruby

    evaluation = api.create_evaluation(ensemble, dataset)


Creating ensembles
~~~~~~~~~~~~~~~~~~

To improve the performance of your predictions, you can create an ensemble
of models and combine their individual predictions.
The only required argument to create an ensemble is the dataset id:

.. code-block:: ruby

    ensemble = api.create_ensemble('dataset/5143a51a37203f2cf7000972')

but you can also specify the number of models to be built and the
parallelism level for the task:

.. code-block:: ruby 

    args = {'number_of_models' => 20, 'tlp' => 3}
    ensemble = api.create_ensemble('dataset/5143a51a37203f2cf7000972', args)

``tlp`` (task-level parallelism) should be an integer between 1 and 5 (the
number of models to be built in parallel). A higher ``tlp`` results in faster
ensemble creation, but it will consume more credits. The default value for
``number_of_models`` is 10 and for ``tlp`` is 1.


Creating batch predictions
~~~~~~~~~~~~~~~~~~~~~~~~~~

We have shown how to create predictions individually, but when the amount
of predictions to make increases, this procedure is far from optimal. In this
case, the more efficient way of predicting remotely is to create a dataset
containing the input data you want your model to predict from and to give its
id and the one of the model to the ``create_batch_prediction`` api call:

.. code-block:: ruby

    batch_prediction = api.create_batch_prediction(model, dataset, {
        "name" => "my batch prediction", "all_fields" => true,
        "header" => true,
        "confidence" => true})

In this example, setting ``all_fields`` to true causes the input
data to be included in the prediction output, ``header`` controls whether a
headers line is included in the file or not and ``confidence`` set to true
causes the confidence of the prediction to be appended. If none of these
arguments is given, the resulting file will contain the name of the
objective field as a header row followed by the predictions.

As for the rest of resources, the create method will return an incomplete
object, that can be updated by issuing the corresponding
``api.get_batch_prediction`` call until it reaches a ``FINISHED`` status.
Then you can download the created predictions file using:

.. code-block:: ruby

    api.download_batch_prediction('batchprediction/526fc344035d071ea3031d70',
        'my_dir/my_predictions.csv')

Creating batch centroids
~~~~~~~~~~~~~~~~~~~~~~~~

As described in the previous section, it is also possible to make centroids'
predictions in batch. First you create a dataset
containing the input data you want your cluster to relate to a centroid.
The ``create_batch_centroid`` call will need the id of the input
data dataset and the
cluster used to assign a centroid to each instance:

.. code-block:: ruby

    batch_centroid = api.create_batch_centroid(cluster, dataset, {
        "name" => "my batch centroid", "all_fields" => true,
        "header" => true})

Creating batch anomaly scores
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Input data can also be assigned an anomaly score in batch. You train an
anomaly detector with your training data and then build a dataset from your
input data. The ``create_batch_anomaly_score`` call will need the id
of the dataset and of the
anomaly detector to assign an anomaly score to each input data instance:

.. code-block:: ruby 

    batch_anomaly_score = api.create_batch_anomaly_score(anomaly, dataset, {
        "name" => "my batch anomaly score", "all_fields" => true,
        "header" => true})

Reading Resources
-----------------

When retrieved individually, resources are returned as a dictionary
identical to the one you get when you create a new resource. However,
the status code will be ``BigML::HTTP_OK`` if the resource can be
retrieved without problems, or one of the HTTP standard error codes
otherwise.

Listing Resources
-----------------

You can list resources with the appropriate api method:

.. code-block:: ruby 

    api.list_sources()
    api.list_datasets()
    api.list_models()
    api.list_predictions()
    api.list_evaluations()
    api.list_ensembles()
    api.list_batch_predictions()
    api.list_clusters()
    api.list_centroids()
    api.list_batch_centroids()
    api.list_anomalies()
    api.list_anomaly_scores()
    api.list_batch_anomaly_scores()
    api.list_projects()
    api.list_samples()
    api.list_correlations()
    api.list_statistical_tests()
    api.list_logistic_regressions()
    api.list_associations()
    api.list_association_sets()
    api.list_scripts()
    api.list_libraries()
    api.list_executions()


you will receive a dictionary with the following keys:

-  **code**: If the request is successful you will get a
   ``BigML::HTTP_OK`` (200) status code. Otherwise, it will be one of
   the standard HTTP error codes. See `BigML documentation on status
   codes <https://bigml.com/developers/status_codes>`_ for more info.
-  **meta**: A dictionary including the following keys that can help you
   paginate listings:

   -  **previous**: Path to get the previous page or ``nil`` if there
      is no previous page.
   -  **next**: Path to get the next page or ``nil`` if there is no
      next page.
   -  **offset**: How far off from the first entry in the resources is
      the first one listed in the resources key.
   -  **limit**: Maximum number of resources that you will get listed in
      the resources key.
   -  **total\_count**: The total number of resources in BigML.

-  **objects**: A list of resources as returned by BigML.
-  **error**: If an error occurs and the resource cannot be created, it
   will contain an additional code and a description of the error. In
   this case, **meta**, and **resources** will be ``nil``.

Filtering Resources
~~~~~~~~~~~~~~~~~~~

You can filter resources in listings using the syntax and fields labeled
as *filterable* in the `BigML
documentation <https://bigml.com/developers>`_ for each resource.

A few examples:

Ids of the first 5 sources created before April 1st, 2012
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

::
    api.list_sources("limit=5;created__lt=2012-04-1")['objects'].collect { |it| it["resource"] }

Name of the first 10 datasets bigger than 1MB
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

::
    api.list_datasets("limit=10;size__gt=1048576")['objects'].collect { |it| it["name"] }

Name of models with more than 5 fields (columns)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

::
    api.list_models("columns__gt=5")['objects'].collect { |it| it["name"] }

Ids of predictions whose model has not been deleted
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

::

    api.list_predictions("model_status=true")['objects'].collect { |it| it["resource"] } 

Ordering Resources
~~~~~~~~~~~~~~~~~~

You can order resources in listings using the syntax and fields labeled
as *sortable* in the `BigML
documentation <https://bigml.com/developers>`_ for each resource.

A few examples:

Name of sources ordered by size
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

::
    api.list_sources("order_by=size")['objects'].collect { |it| it["name] }

Number of instances in datasets created before April 1st, 2012 ordered by size
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

::
    api.list_datasets("created__lt=2012-04-1;order_by=size")['objects'].collect { |it| it["rows"] }


Model ids ordered by number of predictions (in descending order).
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

::
    api.list_models("order_by=-number_of_predictions")['objects'].collect { |it| it["resource"] }

Name of predictions ordered by name.
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

::
    api.list_predictions("order_by=name")['objects'].collect { |it| it["name"] }


Updating Resources
------------------

When you update a resource, it is returned in a dictionary exactly like
the one you get when you create a new one. However the status code will
be ``BigML::HTTP_ACCEPTED`` if the resource can be updated without
problems or one of the HTTP standard error codes otherwise.

.. code-block:: ruby

    api.update_source(source, {"name" => "new name"})
    api.update_dataset(dataset, {"name" => "new name"})
    api.update_model(model, {"name" => "new name"})
    api.update_prediction(prediction, {"name" => "new name"})
    api.update_evaluation(evaluation, {"name" => "new name"})
    api.update_ensemble(ensemble, {"name" => "new name"})
    api.update_batch_prediction(batch_prediction, {"name" => "new name"})
    api.update_cluster(cluster, {"name" => "new name"})
    api.update_centroid(centroid, {"name" => "new name"})
    api.update_batch_centroid(batch_centroid, {"name" => "new name"})
    api.update_anomaly(anomaly, {"name" => "new name"})
    api.update_anomaly_score(anomaly_score, {"name" => "new name"})
    api.update_batch_anomaly_score(batch_anomaly_score, {"name" => "new name"})
    api.update_project(project, {"name" => "new name"})
    api.update_correlation(correlation, {"name" => "new name"})
    api.update_statistical_test(statistical_test, {"name" => "new name"})
    api.update_logistic_regression(logistic_regression, {"name" => "new name"})
    api.update_association(association, {"name" => "new name"})
    api.update_association_set(association_set, {"name" => "new name"})
    api.update_script(script, {"name" => "new name"})
    api.update_library(library, {"name" => "new name"})
    api.update_execution(execution, {"name" => "new name"})

Updates can change resource general properties, such as the ``name`` or
``description`` attributes of a dataset, or specific properties. As an example,
let's say that your source has a certain field whose contents are
numeric integers. BigML will assign a numeric type to the field, but you
might want it to be used as a categorical field. You could change
its type to ``categorical`` by calling:

.. code-block:: ruby

    api.update_source(source, {"fields" => {"000001" => {"optype" => "categorical"}}})


where ``000001`` is the field id that corresponds to the updated field.
You will find detailed information about
the updatable attributes of each resource in
`BigML developer's documentation <https://bigml.com/developers>`_.

Deleting Resources
------------------

Resources can be deleted individually using the corresponding method for
each type of resource.

.. code-block:: ruby

    api.delete_source(source)
    api.delete_dataset(dataset)
    api.delete_model(model)
    api.delete_prediction(prediction)
    api.delete_evaluation(evaluation)
    api.delete_ensemble(ensemble)
    api.delete_batch_prediction(batch_prediction)
    api.delete_cluster(cluster)
    api.delete_centroid(centroid)
    api.delete_batch_centroid(batch_centroid)
    api.delete_anomaly(anomaly)
    api.delete_anomaly_score(anomaly_score)
    api.delete_batch_anomaly_score(batch_anomaly_score)
    api.delete_sample(sample)
    api.delete_correlation(correlation)
    api.delete_statistical_test(statistical_test)
    api.delete_logistic_regression(logistic_regression)
    api.delete_association(association)
    api.delete_association_set(association_set)
    api.delete_project(project)
    api.delete_script(script)
    api.delete_library(library)
    api.delete_execution(execution)

Each of the calls above will return a dictionary with the following
keys:

-  **code** If the request is successful, the code will be a
   ``BigML::HTTP_NO_CONTENT`` (204) status code. Otherwise, it wil be
   one of the standard HTTP error codes. See the `documentation on
   status codes <https://bigml.com/developers/status_codes>`_ for more
   info.
-  **error** If the request does not succeed, it will contain a
   dictionary with an error code and a message. It will be ``nil``
   otherwise.


Public and shared resources
---------------------------

The previous examples use resources that were created by the same user
that asks for their retrieval or modification. If a user wants to share one
of her resources, she can make them public or share them. Declaring a resource
public means that anyone can see the resource. This can be applied to datasets
and models. To turn a dataset public, just update its ``private`` property:

.. code-block:: ruby

    api.update_dataset('dataset/5143a51a37203f2cf7000972', {'private' => false})

and any user will be able to download it using its id prepended by ``public``:

.. code-block:: ruby

    api.get_dataset('public/dataset/5143a51a37203f2cf7000972')

In the models' case, you can also choose if you want the model to be fully
downloadable or just accesible to make predictions. This is controlled with the
``white_box`` property. If you want to publish your model completely, just
use:

.. code-block:: ruby 

    api.update_model('model/5143a51a37203f2cf7000956', {'private' => false,
                     'white_box' => true})

Both public models and datasets, will be openly accessible for anyone,
registered or not, from the web
gallery.


Still, you may want to share your models with other users, but without making
them public for everyone. This can be achieved by setting the ``shared``
property:

.. code-block:: ruby

    api.update_model('model/5143a51a37203f2cf7000956', {'shared' => true})

Shared models can be accessed using their share hash (propery ``shared_hash``
in the original model):

.. code-block:: ruby

    api.get_model('shared/model/d53iw39euTdjsgesj7382ufhwnD')

or by using their original id with the creator user as username and a specific
sharing api_key you will find as property ``sharing_api_key`` in the updated
model:

.. code-block:: ruby

    api.get_model('model/5143a51a37203f2cf7000956', '', 'creator',
                  'c972018dc5f2789e65c74ba3170fda31d02e00c3')


Only users with the share link or credentials information will be able to
access your shared models.

Local Models
------------
Coming Soon

Local Predictions
-----------------
Coming Soon

Local Clusters
--------------
Coming Soon

Local Centroids
---------------
Coming Soon

Local Anomaly Detector
----------------------
Coming Soon

Local Anomaly Scores
--------------------
Coming Soon

Local Logistic Regression
-------------------------
Coming Soon

Local Logistic Regression Predictions
-------------------------------------
Coming Soon

Local Association
-----------------
Coming Soon

Local Association Sets
----------------------
Coming Soon

Multi Models
------------
Coming Soon

Local Ensembles
---------------
Coming Soon

Local Ensemble's Predictions
----------------------------
Coming Soon

Fields
------
Coming Soon

Rule Generation
---------------
Coming Soon

Summary generation
------------------
Coming Soon

Additional Information
----------------------
Coming Soon

For additional information about the API, see the
`BigML developer's documentation <https://bigml.com/developers>`_.


