FROM node

RUN apt-get update && apt-get install -y mongodb-clients

COPY package.json /opt/initdb/
WORKDIR /opt/initdb
RUN npm install

ADD rocketchat-default-db.tar.gz /opt/initdb/
COPY initdb.js /opt/initdb/
CMD ["/usr/local/bin/node", "./initdb"]
