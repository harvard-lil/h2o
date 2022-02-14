#!/bin/bash
set -e

if [[ ${1:0:4} = 'app.' ]]; then
  if [ -z "${AWS_LAMBDA_RUNTIME_API}" ]; then
    exec watchmedo auto-restart --directory=/function --recursive --patterns="*.py" -- /usr/local/bin/aws-lambda-rie python -m awslambdaric $@
  else
    exec python -m awslambdaric $@
  fi
else
  $@
fi
