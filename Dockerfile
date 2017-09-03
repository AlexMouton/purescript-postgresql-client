FROM node:6

RUN apt-get update && apt-get install apt-transport-https
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
RUN apt-get update && apt-get install -y -q yarn

ENV PURESCRIPT_DOWNLOAD_SHA1 3eb742521db7d87359346143a47230b73110ccbe

RUN cd /opt \
    && wget https://github.com/purescript/purescript/releases/download/v0.11.6/linux64.tar.gz \
    && echo "$PURESCRIPT_DOWNLOAD_SHA1 linux64.tar.gz" | sha1sum -c - \
    && tar -xvf linux64.tar.gz \
    && rm /opt/linux64.tar.gz

ENV HOME=/app
WORKDIR $HOME

ENV PATH "$PATH:/opt/purescript:$HOME/node_modules/.bin"

COPY package.json .
RUN yarn install --verbose

COPY bower.json ./
RUN bower install --allow-root

COPY . .

EXPOSE 8080

CMD pulp run
