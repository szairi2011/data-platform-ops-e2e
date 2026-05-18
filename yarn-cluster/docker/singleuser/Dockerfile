FROM quay.io/jupyter/pyspark-notebook:spark-3.5.3

RUN pip install --no-cache-dir sparkmagic==0.23.0 \
    && jupyter nbextension enable --py --sys-prefix widgetsnbextension \
    && jupyter serverextension enable --py sparkmagic
