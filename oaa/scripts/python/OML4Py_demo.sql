--#####################################################
--##
--## Oracle Machine Learning for Python
--## Demo Script for Embedded Python Execution
--##
--## (c)2019 Oracle
--##
--#####################################################

--## Random Red Dots
BEGIN
   sys.pyqScriptCreate('pyqFun1',
'def pyqFun1 ():
    import numpy as np
    import pandas as pd
    import matplotlib.pyplot as plt  

    d = {''id'': range(1,10), ''val'': [x/100 for x in range(1,10)]}
    df = pd.DataFrame(data=d)
    fig = plt.figure(1)
    ax = fig.add_subplot(111)
    ax.scatter(range(0,100), np.random.rand(100),c=''r'')
    fig.suptitle("Random Red Dots")

    fig2 = plt.figure(2)
    ax2 = fig2.add_subplot(111)
    ax2.scatter(range(0,10), np.random.rand(10),c=''r'')
    fig2.suptitle("Random Red Dots")
    return df', NULL, TRUE);
END;
/

SELECT * FROM table(pyqEval(NULL,'PNG','pyqFun1'));
SELECT * FROM table(pyqEval(NULL,'select 1 id, 1 val from dual','pyqFun1'));
SELECT * FROM table(pyqEval(NULL,'XML','pyqFun1'));

SELECT * FROM table(pyqEval(NULL,'PNG','RandomRedDots2'));
SELECT * FROM table(pyqEval(NULL,'select 1 id, 1 val from dual','RandomRedDots2'));

--## pyqEval

BEGIN
   sys.pyqScriptCreate('pyqFun2', 'func = lambda: "Hello World from a lambda!"',
                        FALSE, TRUE); -- V_GLOBAL, V_OVERWRITE
END;
/

SELECT name, value FROM table(pyqEval(NULL,'XML','pyqFun2'));

BEGIN
  sys.pyqScriptDrop('pyqFun2');
END;
/ 

--## Returning an array

BEGIN
  sys.pyqScriptCreate('pyqFun3',
    'def return_frame():
       import numpy as np
       import pickle
       z = np.array([y for y in zip([str(x)+"demo" for x in range(10)],
                      [float(x)/10 for x in range(10)],
                      [x for x in range(10)],
                      [bool(x%2) for x in range(10)],
                      [pickle.dumps(x) for x in range(10)],
                      ["test"+str(x**2) for x in range(10)])],
                    dtype=[("a", "U10"), ("b", "f8"), ("c", "i4"), 
                           ("d", "?"), ("e", "S20"), ("f", "O")])
       return z', NULL, TRUE);
END;
/

SELECT * 
FROM table(pyqEval(NULL,
                   'select cast(''a'' as varchar2(10)) a, 1D b, 1 c,
                        1 d, cast(''01'' as raw(10)) e,
                        cast(''a'' as varchar2(10)) f from dual',
                   'pyqFun3'));

BEGIN
  sys.pyqScriptDrop('pyqFun3');
END;
/

--## Table Eval

BEGIN
  sys.pyqScriptCreate('create_iris_table',
    'def create_iris_table():
       from sklearn.datasets import load_iris
       import pandas as pd
       iris = load_iris()
       x = pd.DataFrame(iris.data, columns = ["SEPAL_LENGTH",\
             "SEPAL_WIDTH", "PETAL_LENGTH", "PETAL_WIDTH"])
       y = pd.DataFrame(list(map(lambda x: {0:"setosa", 1: "versicolor",\
                                 2: "virginica"}[x], iris.target)),\
                        columns = ["SPECIES"])
       return pd.concat([y, x], axis=1)', FALSE, TRUE);
END;
/


BEGIN
  sys.pyqScriptCreate('sample_iris_table',
    'def sample_iris_table(size):
       from sklearn.datasets import load_iris
       import pandas as pd
       iris = load_iris()
       x = pd.DataFrame(iris.data, columns = ["SEPAL_LENGTH",\
                        "SEPAL_WIDTH","PETAL_LENGTH","PETAL_WIDTH"])
       y = pd.DataFrame(list(map(lambda x: {0:"setosa", 1: "versicolor",\
                                 2: "virginica"}[x], iris.target)),\
                        columns = ["SPECIES"])
       return pd.concat([y, x], axis=1).sample(int(size))', FALSE, TRUE);
END;
/

DROP TABLE sample_iris;
CREATE TABLE sample_iris AS
SELECT *
  FROM TABLE(pyqEval(
               CURSOR(SELECT 20 AS "size" FROM dual),
               'select cast(''a'' as varchar2(10)) "SPECIES", 1 "SEPAL_LENGTH", 
                       1 "SEPAL_WIDTH", 1 "PETAL_LENGTH", 
                       1 "PETAL_WIDTH" from dual',
               'sample_iris_table'));
               
BEGIN
  sys.pyqScriptCreate('linregrPredict',
    'def predict_model(dat, modelName, datastoreName):
       import oml
       import pandas as pd
       objs = oml.ds.load(name=datastoreName, to_globals=False)
       pred = objs[modelName].predict(dat[["SEPAL_LENGTH","SEPAL_WIDTH",\
                                           "PETAL_LENGTH"]])
       return pd.concat([dat, pd.DataFrame(pred, \
                         columns=["PRED_PETAL_WIDTH"])], axis=1)', FALSE, TRUE);
END;
/

SELECT *
FROM table(pyqRowEval(
     CURSOR(select * FROM sample_iris),
     CURSOR(select 1 AS "oml_connect",
       'pandas.DataFrame' AS "oml_input_type",
       'linregr' AS "modelName",
       'pymodel' AS "datastoreName" FROM dual),
       'SELECT cast(''a'' as varchar2(10)) "SPECIES", 1 "SEPAL_LENGTH",
               1 "SEPAL_WIDTH", 1 "PETAL_LENGTH", 1 "PETAL_WIDTH",
               1 "PRED_PETAL_WIDTH" from dual',
     5,
     'linregrPredict'));

--## Script Create

BEGIN
  sys.pyqScriptCreate('tmpqfun2',
    'def return_frame():
       import numpy as np
       import pickle
       z = np.array([y for y in zip([str(x)+"demo" for x in range(10)],
       [float(x)/10 for x in range(10)],
       [x for x in range(10)],
       [bool(x%2) for x in range(10)],
       [pickle.dumps(x) for x in range(10)],
       ["test"+str(x**2) for x in range(10)])],
       dtype=[("a", "U10"), ("b", "f8"), ("c", "i4"), ("d", "?"), ("e", "S20"),
       ("f", "O")])
       return z', FALSE, TRUE);
END;
/

BEGIN
  sys.pyqScriptCreate('tmpqfun2',
    'def return_frame():
       import numpy as np
       import pickle
       z = np.array([y for y in zip([str(x)+"demo" for x in range(10)],
       [float(x)/10 for x in range(10)],
       [x for x in range(10)],
       [bool(x%2) for x in range(10)],
       [pickle.dumps(x) for x in range(10)],
       ["test"+str(x**2) for x in range(10)])],
       dtype=[("a", "U10"), ("b", "f8"), ("c", "i4"), ("d", "?"), ("e", "S20"),
       ("f", "O")])
       return z',
       TRUE,  -- Make the script global.
       TRUE); -- Overwrite any global script by the same name.
END;
/

SELECT * from USER_PYQ_SCRIPTS;
SELECT * from ALL_PYQ_SCRIPTS;

BEGIN
  pyqGrant('tmpqfun2',
    'pyqscript',
    'PYQUSER2');  
END;
/

BEGIN
  pyqRevoke('tmpqfun2',
    'pyqscript',
    'PYQUSER2');
END;
/

BEGIN
  sys.pyqScriptDrop('tmpqfun2');
END;
/

BEGIN
  sys.pyqScriptDrop('tmpqfun2', TRUE);
END;
/
--## Datastore-related tables

SELECT * FROM ALL_PYQ_DATASTORES;
SELECT DSNAME, GRANTABLE FROM ALL_PYQ_DATASTORES;
SELECT * FROM ALL_PYQ_DATASTORE_CONTENTS;
SELECT owner, name FROM ALL_PYQ_SCRIPTS;
SELECT name, script FROM ALL_PYQ_SCRIPTS WHERE name = 'create_iris_table';
SELECT * FROM USER_PYQ_DATASTORES;
SELECT DSNAME, GRANTABLE FROM USER_PYQ_DATASTORES;
SELECT * FROM USER_PYQ_SCRIPTS;




