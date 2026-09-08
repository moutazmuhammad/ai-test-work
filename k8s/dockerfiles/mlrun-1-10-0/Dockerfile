# manifest, so a 2-arch build mislabels amd64 content as arm64.
#   docker buildx build --platform linux/amd64 \
#     -t europe-west1-docker.pkg.dev/vf-grp-aib-dev-mirror/aib-plus-images/mlrun/mlrun:1.10.0-harden --push .

FROM mlrun/mlrun:1.10.0

USER root

# Clears all fixable OS findings incl. gnutls28 (2 CRITICAL).
RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && \
    apt-get -y --no-install-recommends \
        -o Dpkg::Options::=--force-confold \
        -o Dpkg::Options::=--force-confdef \
        dist-upgrade && \
    apt-get -y autoremove && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN python -m pip uninstall -y dask-expr && \
    python -m pip install --no-cache-dir --upgrade \
        "dask[array,dataframe]>=2026.1,<2026.2" \
        "dask-glm>=0.4,<1" \
        "distributed>=2026.1,<2026.2" \
        "aiohttp>=3.14.1,<4" \
        "aiosmtplib>=5.1.2,<6" \
        "azure-core>=1.38" \
        "bleach>=6.4" \
        "bokeh>=3.8.2" \
        "deepdiff>=8.6.2,<9" \
        "fastapi>=0.141.1" \
        "filelock>=3.20.3" \
        "flask>=3.1.3" \
        "fonttools>=4.60.2" \
        "GitPython>=3.1.50,<4" \
        "idna>=3.15" \
        "jupyter-server>=2.20" \
        "mako>=1.3.12" \
        "mistune>=3.2.1" \
        "mlflow>=3.15.1" \
        "msal>=1.37,<2" \
        "msgpack>=1.2.1" \
        "nbconvert>=7.17.1" \
        "orjson>=3.11.6,<4" \
        "pillow>=12.2" \
        "pip>=26.1.2" \
        "protobuf>=6.33.5,<7" \
        "pyarrow>=23.0.1,<24" \
        "pyasn1>=0.6.3" \
        "pygments>=2.20" \
        "pyjwt>=2.13,<3" \
        "pyOpenSSL>=26.4,<27" \
        "python-dotenv>=1.2.2,<2" \
        "requests>=2.33,<3" \
        "setuptools>=83,<84" \
        "soupsieve>=2.8.4,<3" \
        "sqlparse>=0.6,<1" \
        "starlette>=1.3.1" \
        "tornado>=6.5.7" \
        "urllib3>=2.7,<3" \
        "werkzeug>=3.1.6" \
        "wheel>=0.46.2" && \
    find /opt/conda -name '__pycache__' -type d -prune -exec rm -rf {} + && \
    rm -rf /root/.cache

RUN python -m pip install --no-cache-dir --upgrade "cryptography>=50,<51" && \
    rm -rf /root/.cache

# Image ships a 2nd interpreter; `python` is conda, so it misses this root.
RUN /usr/local/bin/python3.11 -m pip install --no-cache-dir --upgrade \
        "setuptools>=83,<84" "wheel>=0.46.2" "pip>=26.1.2" && \
    rm -rf /root/.cache

# mlflow 3.x raises on the default ./mlruns file store; this restores 2.x
# behaviour. Drop once MLFLOW_TRACKING_URI points at a real backend.
ENV MLFLOW_ALLOW_FILE_STORE=true

# No upstream fix: perl

RUN python -c "\
import mlrun, mlflow, pyarrow, urllib3, cryptography, OpenSSL, tornado, requests;\
import setuptools, wrapt, pytz, werkzeug, jedi, grpc_tools, dask_glm;\
import mlflow.utils.crypto, mlflow.store.model_registry.dbmodels.models;\
from mlrun.track.trackers.mlflow_tracker import MLFlowTracker;\
from mlrun.frameworks.auto_mlrun import AutoMLRun;\
import mlrun.artifacts, mlrun.feature_store, mlrun.serving, mlrun.datastore;\
import pandas, numpy, sklearn, dask, distributed, matplotlib, bokeh, aiosmtplib;\
import bs4, soupsieve, storey, sqlparse, dask.dataframe as dd;\
from mlrun.utils.notifications.notification.mail import MailNotification;\
bs4.BeautifulSoup('<a class=x>h</a>', 'html.parser').select('a.x');\
assert dd.from_pandas(pandas.DataFrame({'a': [1, 2, 3]}), npartitions=2).a.sum().compute() == 6;\
assert sqlparse.format('select a from t', reindent=True, keyword_case='upper').startswith('SELECT');\
print('mlrun', mlrun.__version__, '| mlflow', mlflow.__version__, '| pyarrow', pyarrow.__version__,\
      '| dask', dask.__version__, '| cryptography', cryptography.__version__,\
      '| sqlparse', sqlparse.__version__)"

# Informational: flags the intended mlflow/fastapi deviations. Never gates.
RUN pip check || true

USER root
WORKDIR /mlrun
