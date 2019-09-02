From ruby:2.6.3-alpine

RUN apk add --update build-base libffi-dev libcurl libcurl curl-dev

WORKDIR /opt

EXPOSE 8080
ENV PORT 8080
ENV RACK_ENV production

# https://github.com/docker-library/docs/blob/master/ruby/content.md#encoding
ENV LANG C.UTF-8

COPY . .
RUN bundle install --system --without=test development

CMD bundle exec thin -R config.ru start -p $PORT
