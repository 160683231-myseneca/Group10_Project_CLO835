FROM ubuntu:20.04

RUN apt-get update -y && apt-get install -y \
    python3-pip \
    mysql-client \
    iputils-ping \
    curl \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --upgrade pip

ARG APP_COLOR
ARG VERSION

ENV APP_COLOR=${APP_COLOR} VERSION=${VERSION} GROUP_NAME=${GROUP_NAME} GROUP_SLOGAN=${GROUP_SLOGAN} GROUP_IMAGE=${GROUP_IMAGE}

WORKDIR /app

COPY . .

RUN pip install -r requirements.txt

EXPOSE 81

ENTRYPOINT [ "python3" ]
CMD [ "app.py" ]
