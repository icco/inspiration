From ruby:2.4.0

WORKDIR /opt
COPY . .

ENV PORT 8080
ENV RACK_ENV production

# https://github.com/docker-library/docs/blob/master/ruby/content.md#encoding
ENV LANG C.UTF-8

RUN bundle install --system --without=test development

CMD bundle exec thin -R config.ru start -p $PORT
