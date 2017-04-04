FROM node:latest

ADD package.json /opt/pasha/
WORKDIR /opt/pasha
RUN npm install && npm install -g supervisor

RUN apt-get update && apt-get install strace
ADD . /opt/pasha
CMD ["./node_modules/.bin/coffee", "./node_modules/.bin/hubot", "--adapter", "slack"]
